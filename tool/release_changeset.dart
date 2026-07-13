// Release changeset CLI: init, check, plan, version-pr, validate-release.
//
// Usage:
//   dart run tool/release_changeset.dart init --package=<name> --bump=<level> --summary="<text>"
//   dart run tool/release_changeset.dart check --changed-files=<files> [--base=<sha> --head=<sha>]
//   dart run tool/release_changeset.dart plan --base=<sha> --head=<sha> [--format=markdown|json]
//   dart run tool/release_changeset.dart version-pr --base=<sha> --head=<sha>
//   dart run tool/release_changeset.dart validate-release --tag=<tag>
//
// This CLI is the release intent boundary. Candidates come ONLY from
// changesets — validation expansion does not imply publication.

import 'dart:convert';
import 'dart:io';

import 'src/release_planner.dart';
import 'src/version_editor.dart';

const _defaultChangesetsDir = '.changesets';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exit(64); // EX_USAGE
  }

  final subcommand = args.first;

  switch (subcommand) {
    case 'init':
      await _handleInit(args.skip(1).toList());
    case 'check':
      await _handleCheck(args.skip(1).toList());
    case 'plan':
      await _handlePlan(args.skip(1).toList());
    case 'version-pr':
      await _handleVersionPr(args.skip(1).toList());
    case 'validate-release':
      await _handleValidateRelease(args.skip(1).toList());
    default:
      stderr.writeln('Unknown subcommand: $subcommand');
      _printUsage();
      exit(64);
  }
}

void _printUsage() {
  stderr
    ..writeln(
      'Usage: dart run tool/release_changeset.dart <subcommand> [options]',
    )
    ..writeln()
    ..writeln('Subcommands:')
    ..writeln('  init       Create a new changeset boilerplate')
    ..writeln(
      '  check      Verify publishable changes have matching changesets',
    )
    ..writeln('  plan       Render the release plan from existing changesets')
    ..writeln('  version-pr Apply version/changelog edits')
    ..writeln(
      '  validate-release Validate a release tag against '
      'pubspec/changelog/provenance',
    )
    ..writeln()
    ..writeln('Options for init:')
    ..writeln('  --package=<name>     Package name (required)')
    ..writeln('  --bump=<level>       Bump level: patch|minor|major (required)')
    ..writeln('  --summary="<text>"   Changelog summary (required)')
    ..writeln(
      '  --changesets-dir=<path>  Changesets directory (default: .changesets)',
    )
    ..writeln()
    ..writeln('Options for check:')
    ..writeln('  --changed-files=<files>  Comma-separated changed file paths')
    ..writeln('  --base=<sha> --head=<sha>  Git diff range (alternative)')
    ..writeln(
      '  --changesets-dir=<path>  Changesets directory (default: .changesets)',
    )
    ..writeln()
    ..writeln('Options for plan:')
    ..writeln('  --format=markdown|json   Output format (default: markdown)')
    ..writeln('  --changed-files=<files>  Comma-separated changed file paths')
    ..writeln('  --base=<sha> --head=<sha>  Git diff range for impact analysis')
    ..writeln(
      '  --changesets-dir=<path>  Changesets directory (default: .changesets)',
    )
    ..writeln()
    ..writeln('Options for version-pr:')
    ..writeln(
      '  --changesets-dir=<path>  Changesets directory '
      '(default: .changesets)',
    )
    ..writeln(
      '  --workspace-root=<path>  Workspace root (default: current directory)',
    )
    ..writeln('  --changed-files=<files>  Comma-separated changed file paths')
    ..writeln('  --base=<sha> --head=<sha>  Git diff range for impact analysis')
    ..writeln()
    ..writeln('Options for validate-release:')
    ..writeln('  --tag=<tag>              Release tag to validate (required)')
    ..writeln(
      '  --workspace-root=<path>  Workspace root (default: current directory)',
    );
}

String _extractArg(List<String> args, String name) {
  for (final arg in args) {
    if (arg.startsWith('--$name=')) {
      return arg.substring('--$name='.length);
    }
  }
  return '';
}

Future<void> _handleInit(List<String> args) async {
  final package = _extractArg(args, 'package');
  final bump = _extractArg(args, 'bump');
  final summary = _extractArg(args, 'summary');
  final changesetsDir = _extractArg(args, 'changesets-dir').isEmpty
      ? _defaultChangesetsDir
      : _extractArg(args, 'changesets-dir');

  if (package.isEmpty) {
    stderr.writeln('ERROR: --package is required for init.');
    _printUsage();
    exit(64);
  }
  if (bump.isEmpty) {
    stderr.writeln('ERROR: --bump is required for init.');
    _printUsage();
    exit(64);
  }
  if (summary.isEmpty) {
    stderr.writeln('ERROR: --summary is required for init.');
    _printUsage();
    exit(64);
  }

  // Validate bump level
  try {
    BumpLevel.parse(bump);
  } on FormatException catch (e) {
    stderr
      ..writeln('ERROR: ${e.message}')
      ..writeln('Valid bump levels: patch, minor, major');
    exit(64);
  }

  // Ensure changesets directory exists
  final dir = Directory(changesetsDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Generate slug from summary
  final slug = summary
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final filename = '$changesetsDir/$slug.md';

  // Write boilerplate
  final content =
      '''
---
$package: $bump
---

$summary
''';

  File(filename).writeAsStringSync(content);
  stdout
    ..writeln('✅ Created changeset: $filename')
    ..writeln()
    ..writeln('Content:')
    ..writeln(content);
}

Future<void> _handleCheck(List<String> args) async {
  final changedFilesArg = _extractArg(args, 'changed-files');
  final base = _extractArg(args, 'base');
  final head = _extractArg(args, 'head');
  final changesetsDir = _extractArg(args, 'changesets-dir').isEmpty
      ? _defaultChangesetsDir
      : _extractArg(args, 'changesets-dir');

  // Get changed files with diff content for content-aware analysis.
  List<ChangedFile> changedFiles;
  if (changedFilesArg.isNotEmpty) {
    changedFiles = changedFilesArg
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .map((f) => ChangedFile(path: f))
        .toList();
  } else if (base.isNotEmpty && head.isNotEmpty) {
    changedFiles = await _getGitDiffChangedFiles(base, head);
  } else {
    stderr.writeln(
      'ERROR: provide --changed-files=<files> or --base=<sha> --head=<sha>.',
    );
    exit(64);
  }

  // Parse changesets
  final changesets = _loadChangesets(changesetsDir);

  // Reconcile real impact with changeset intent.
  final reconciliation = ReleaseReconciler.reconcile(
    changedFiles: changedFiles,
    changesets: changesets,
  );

  // Fail on real impact without changeset (missingIntentFailures).
  if (reconciliation.hasFailures) {
    stderr
      ..writeln('=== Release Intent Check ===')
      ..writeln()
      ..writeln('FAIL: Real package impact without matching changeset.')
      ..writeln();
    for (final failure in reconciliation.missingIntentFailures) {
      stderr
        ..writeln(failure.remediation)
        ..writeln();
    }
    exit(1);
  }

  // Surface unused intent warnings (changeset without real impact).
  final changedFilePaths = changedFiles.map((f) => f.path).toList();
  final publishablePkgs = PublishableClassifier.findPublishablePackages(
    changedFilePaths,
  );

  if (reconciliation.unusedIntentWarnings.isNotEmpty) {
    stdout
      ..writeln('=== Release Intent Check ===')
      ..writeln()
      ..writeln('PASS: No missing changesets for real impact.')
      ..writeln();
    for (final warning in reconciliation.unusedIntentWarnings) {
      stdout.writeln('WARNING: ${warning.reason}');
    }
    stdout
      ..writeln()
      ..writeln('Changed files: ${changedFiles.length}')
      ..writeln(
        'Publishable packages: '
        '${publishablePkgs.isEmpty ? "none" : publishablePkgs.join(", ")}',
      )
      ..writeln('Changesets found: ${changesets.length}')
      ..writeln(
        'Release candidates: '
        '${reconciliation.releaseCandidates.length}',
      );
    exit(0);
  }

  // All good — no failures, no warnings.
  stdout
    ..writeln('=== Release Intent Check ===')
    ..writeln()
    ..writeln('PASS: All publishable changes have matching changesets.')
    ..writeln()
    ..writeln('Changed files: ${changedFiles.length}')
    ..writeln(
      'Publishable packages: '
      '${publishablePkgs.isEmpty ? "none" : publishablePkgs.join(", ")}',
    )
    ..writeln('Changesets found: ${changesets.length}')
    ..writeln('Release candidates: ${reconciliation.releaseCandidates.length}');
  exit(0);
}

Future<void> _handlePlan(List<String> args) async {
  final format = _extractArg(args, 'format').isEmpty
      ? 'markdown'
      : _extractArg(args, 'format');
  final changesetsDir = _extractArg(args, 'changesets-dir').isEmpty
      ? _defaultChangesetsDir
      : _extractArg(args, 'changesets-dir');
  final changedFilesArg = _extractArg(args, 'changed-files');
  final base = _extractArg(args, 'base');
  final head = _extractArg(args, 'head');

  if (format != 'markdown' && format != 'json') {
    stderr.writeln('ERROR: --format must be markdown or json.');
    exit(64);
  }

  final changesets = _loadChangesets(changesetsDir);

  if (changedFilesArg.isEmpty && (base.isEmpty || head.isEmpty)) {
    stderr.writeln(
      'ERROR: plan requires diff context via --changed-files=<files> '
      'or --base=<sha> --head=<sha>. Changesets alone are intent, not '
      'impact proof.',
    );
    exit(64);
  }

  final ReleasePlan plan;
  final List<UnusedIntentWarning> unusedWarnings;

  List<ChangedFile> changedFiles;
  if (changedFilesArg.isNotEmpty) {
    changedFiles = changedFilesArg
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .map((f) => ChangedFile(path: f))
        .toList();
  } else {
    changedFiles = await _getGitDiffChangedFiles(base, head);
  }

  final reconciliation = ReleaseReconciler.reconcile(
    changedFiles: changedFiles,
    changesets: changesets,
  );

  if (reconciliation.hasFailures) {
    stderr
      ..writeln('=== Release Plan ===')
      ..writeln()
      ..writeln('FAIL: Real package impact without matching changeset.')
      ..writeln('Refusing to render a partial release plan.')
      ..writeln();
    for (final failure in reconciliation.missingIntentFailures) {
      stderr
        ..writeln(failure.remediation)
        ..writeln();
    }
    exit(1);
  }

  plan = _buildPlanFromCandidates(reconciliation.releaseCandidates);
  unusedWarnings = reconciliation.unusedIntentWarnings;

  if (format == 'json') {
    stdout.writeln(plan.renderJson());
  } else {
    stdout
      ..writeln('=== Release Plan ===')
      ..writeln()
      ..writeln('Changesets loaded: ${changesets.length}')
      ..writeln('Candidates: ${plan.candidates.length}')
      ..writeln();

    for (final warning in unusedWarnings) {
      stdout.writeln('WARNING: ${warning.reason}');
    }
    if (unusedWarnings.isNotEmpty) stdout.writeln();

    stdout.writeln(plan.renderMarkdown());
  }
}

Future<void> _handleVersionPr(List<String> args) async {
  final changesetsDir = _extractArg(args, 'changesets-dir').isEmpty
      ? _defaultChangesetsDir
      : _extractArg(args, 'changesets-dir');
  final workspaceRoot = _extractArg(args, 'workspace-root').isEmpty
      ? Directory.current.path
      : _extractArg(args, 'workspace-root');
  final changedFilesArg = _extractArg(args, 'changed-files');
  final base = _extractArg(args, 'base');
  final head = _extractArg(args, 'head');

  final changesets = _loadChangesets(changesetsDir);

  if (changedFilesArg.isEmpty && (base.isEmpty || head.isEmpty)) {
    stderr.writeln(
      'ERROR: version-pr requires diff context via --changed-files=<files> '
      'or --base=<sha> --head=<sha>. Refusing to write weak provenance '
      'from changeset intent alone.',
    );
    exit(64);
  }

  final ReleasePlan plan;
  final List<UnusedIntentWarning> unusedWarnings;

  List<ChangedFile> changedFiles;
  if (changedFilesArg.isNotEmpty) {
    changedFiles = changedFilesArg
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .map((f) => ChangedFile(path: f))
        .toList();
  } else {
    changedFiles = await _getGitDiffChangedFiles(base, head);
  }

  final reconciliation = ReleaseReconciler.reconcile(
    changedFiles: changedFiles,
    changesets: changesets,
  );

  if (reconciliation.hasFailures) {
    stderr
      ..writeln('=== Version PR ===')
      ..writeln()
      ..writeln('FAIL: Real package impact without matching changeset.')
      ..writeln('Refusing to write a partial release/version PR.')
      ..writeln();
    for (final failure in reconciliation.missingIntentFailures) {
      stderr
        ..writeln(failure.remediation)
        ..writeln();
    }
    exit(1);
  }

  plan = _buildPlanFromCandidates(reconciliation.releaseCandidates);
  unusedWarnings = reconciliation.unusedIntentWarnings;

  if (plan.candidates.isEmpty) {
    final reason = changesets.isEmpty
        ? 'no changesets found'
        : 'changeset intent has no real package impact';
    stdout
      ..writeln('=== Version PR ===')
      ..writeln()
      ..writeln('No release candidates — $reason.')
      ..writeln();

    for (final warning in unusedWarnings) {
      stdout.writeln('WARNING: ${warning.reason}');
    }

    stdout.writeln(
      'No release tags will be created until a version PR with validated '
      'release candidates merges.',
    );
    return;
  }

  stdout
    ..writeln('=== Version PR ===')
    ..writeln()
    ..writeln('Applying version edits to: $workspaceRoot')
    ..writeln('Candidates: ${plan.candidates.length}')
    ..writeln();

  for (final warning in unusedWarnings) {
    stdout.writeln('WARNING: ${warning.reason}');
  }
  if (unusedWarnings.isNotEmpty) stdout.writeln();

  final edits = VersionEditor.applyVersionEdits(
    plan,
    workspaceRoot,
    changesetsDir: changesetsDir,
  );

  for (final edit in edits) {
    stdout.writeln('  ${edit.packageName}: ${edit.description}');
  }

  stdout
    ..writeln()
    ..writeln(plan.renderMarkdown());
}

Future<void> _handleValidateRelease(List<String> args) async {
  final tag = _extractArg(args, 'tag');
  final workspaceRoot = _extractArg(args, 'workspace-root').isEmpty
      ? Directory.current.path
      : _extractArg(args, 'workspace-root');
  final changesetsDir = _extractArg(args, 'changesets-dir').isEmpty
      ? _defaultChangesetsDir
      : _extractArg(args, 'changesets-dir');

  if (tag.isEmpty) {
    stderr.writeln('ERROR: --tag is required for validate-release.');
    _printUsage();
    exit(64);
  }

  // Parse the tag to determine the package name.
  final TagInfo tagInfo;
  try {
    tagInfo = TagParser.parse(tag);
  } on FormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    stdout.writeln(
      '{"isValid": false, "errors": ["${e.message}"], '
      '"package": "", "version": "", "isMajor": false}',
    );
    exit(1);
  }

  // Read pubspec content.
  final pubspecPath =
      '$workspaceRoot/packages/${tagInfo.packageName}/pubspec.yaml';
  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    stderr.writeln('ERROR: pubspec not found at $pubspecPath.');
    stdout.writeln(
      '{"isValid": false, '
      '"errors": ["pubspec not found for ${tagInfo.packageName}"], '
      '"package": "${tagInfo.packageName}", '
      '"version": "${tagInfo.version}", "isMajor": false}',
    );
    exit(1);
  }
  final pubspecContent = pubspecFile.readAsStringSync();

  // Read changelog content.
  final changelogPath =
      '$workspaceRoot/packages/${tagInfo.packageName}/CHANGELOG.md';
  final changelogFile = File(changelogPath);
  if (!changelogFile.existsSync()) {
    stderr.writeln('ERROR: CHANGELOG.md not found at $changelogPath.');
    stdout.writeln(
      '{"isValid": false, '
      '"errors": ["CHANGELOG.md not found for ${tagInfo.packageName}"], '
      '"package": "${tagInfo.packageName}", '
      '"version": "${tagInfo.version}", "isMajor": false}',
    );
    exit(1);
  }
  final changelogContent = changelogFile.readAsStringSync();

  // Read provenance manifest (may be absent — fails closed).
  final provenancePath =
      '$changesetsDir/releases/${tagInfo.packageName}-${tagInfo.version}.json';
  final provenanceFile = File(provenancePath);
  final String? provenanceJson;
  if (provenanceFile.existsSync()) {
    provenanceJson = provenanceFile.readAsStringSync();
  } else {
    provenanceJson = null;
  }

  // Run validation with dependency preflight for explicit package.
  final result = ReleaseValidator.validateRelease(
    tag: tag,
    pubspecContent: pubspecContent,
    changelogContent: changelogContent,
    provenanceJson: provenanceJson,
    metadataFetcher: _fetchPubDevMetadata,
  );

  // Output JSON result to stdout (JSON-only for workflow consumption).
  final output = {
    'isValid': result.isValid,
    'errors': result.errors,
    'package': result.packageName,
    'version': result.version,
    'isMajor': result.isMajor,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));

  if (!result.isValid) {
    stderr
      ..writeln()
      ..writeln('=== Release Validation FAILED ===')
      ..writeln();
    for (final error in result.errors) {
      stderr.writeln('  - $error');
    }
    exit(1);
  } else {
    stderr
      ..writeln()
      ..writeln('=== Release Validation PASSED ===')
      ..writeln('  Package: ${result.packageName}')
      ..writeln('  Version: ${result.version}')
      ..writeln('  Major:   ${result.isMajor}');
  }
}

/// Builds a [ReleasePlan] from reconciled release candidates.
///
/// Computes dependency propagation from the candidate list.
ReleasePlan _buildPlanFromCandidates(List<ReleaseCandidate> candidates) {
  final dependencyUpdates = <DependencyUpdate>[];
  final candidateNames = candidates.map((c) => c.packageName).toSet();
  if (candidateNames.contains('explicit_outcome') &&
      candidateNames.contains('explicit')) {
    dependencyUpdates.add(
      const DependencyUpdate(
        packageName: 'explicit',
        dependencyName: 'explicit_outcome',
      ),
    );
  }
  return ReleasePlan(
    candidates: candidates,
    dependencyUpdates: dependencyUpdates,
  );
}

List<Changeset> _loadChangesets(String dir) {
  final changesetsDir = Directory(dir);
  if (!changesetsDir.existsSync()) {
    return [];
  }

  final changesets = <Changeset>[];
  final files =
      changesetsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    if (_isChangesetTemplateFile(file.path)) continue;

    try {
      final content = file.readAsStringSync();
      changesets.add(Changeset.parse(content));
    } on FormatException catch (e) {
      stderr
        ..writeln('ERROR: Failed to parse changeset ${file.path}: ${e.message}')
        ..writeln()
        ..writeln('Malformed changesets are release-intent failures.')
        ..writeln(
          'Fix the file or remove it if it is not active release intent.',
        )
        ..writeln('Expected format:')
        ..writeln('---')
        ..writeln('package_name: patch')
        ..writeln('---')
        ..writeln()
        ..writeln('Describe the change.');
      exit(65); // EX_DATAERR
    }
  }
  return changesets;
}

bool _isChangesetTemplateFile(String path) {
  final fileName = path.split(RegExp(r'[/\\]')).last.toLowerCase();
  return fileName == 'readme.md';
}

Future<List<ChangedFile>> _getGitDiffChangedFiles(
  String base,
  String head,
) async {
  // Step 1: Get the list of changed file names.
  final nameResult = await Process.run('git', [
    'diff',
    '--name-only',
    '$base...$head',
  ]);
  if (nameResult.exitCode != 0) {
    stderr
      ..writeln('ERROR: git diff failed for range $base...$head.')
      ..writeln()
      ..writeln('Release intent check cannot continue without changed files.')
      ..writeln(
        'Remediation: verify the base/head SHAs exist in this checkout,',
      )
      ..writeln('ensure CI uses actions/checkout with fetch-depth: 0, or pass')
      ..writeln('--changed-files=<comma-separated paths> explicitly.')
      ..writeln()
      ..writeln('git stderr: ${(nameResult.stderr as String).trim()}');
    exit(69); // EX_UNAVAILABLE
  }
  final nameOutput = (nameResult.stdout as String).trim();
  if (nameOutput.isEmpty) return [];
  final fileNames = nameOutput.split('\n');

  // Step 2: Collect unified diff content per file for content-aware analysis.
  final changedFiles = <ChangedFile>[];
  for (final fileName in fileNames) {
    final diffResult = await Process.run('git', [
      'diff',
      '$base...$head',
      '--',
      fileName,
    ]);
    final diffContent = diffResult.exitCode == 0
        ? (diffResult.stdout as String).trim()
        : null;
    changedFiles.add(
      ChangedFile(
        path: fileName,
        diffContent: (diffContent?.isNotEmpty ?? false) ? diffContent : null,
      ),
    );
  }

  return changedFiles;
}

/// Fetches pub.dev package metadata via the pub.dev API.
///
/// Uses `curl` for synchronous HTTP in the CLI context.
/// Returns a [PubDevMetadata] with all published versions.
/// Throws on network or parse errors (fail-closed).
PubDevMetadata _fetchPubDevMetadata(String packageName) {
  final url = 'https://pub.dev/api/packages/$packageName';
  final result = Process.runSync('curl', [
    '--silent',
    '--fail',
    '--max-time',
    '10',
    url,
  ]);

  if (result.exitCode != 0) {
    throw Exception(
      'pub.dev API request failed for $packageName '
      '(curl exit code ${result.exitCode})',
    );
  }

  final body = (result.stdout as String).trim();
  if (body.isEmpty) {
    throw Exception('pub.dev API returned empty response for $packageName');
  }

  final decoded = jsonDecode(body) as Map<String, dynamic>;
  final versionsList = decoded['versions'] as List<dynamic>? ?? [];
  final versions = versionsList
      .map((v) => (v as Map<String, dynamic>)['version'] as String)
      .toList();

  return PubDevMetadata(packageName: packageName, versions: versions);
}
