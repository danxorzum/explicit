// Release changeset CLI: init, check, plan, version-pr.
//
// Usage:
//   dart run tool/release_changeset.dart init --package=<name> --bump=<level> --summary="<text>"
//   dart run tool/release_changeset.dart check --changed-files=<files> [--base=<sha> --head=<sha>]
//   dart run tool/release_changeset.dart plan --format=markdown|json
//   dart run tool/release_changeset.dart version-pr
//
// This CLI is the release intent boundary. Candidates come ONLY from
// changesets — validation expansion does not imply publication.

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
    ..writeln('  version-pr Apply version/changelog edits (slice two)')
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

  // Get changed files
  List<String> changedFiles;
  if (changedFilesArg.isNotEmpty) {
    changedFiles = changedFilesArg
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
  } else if (base.isNotEmpty && head.isNotEmpty) {
    changedFiles = await _getGitDiffFiles(base, head);
  } else {
    stderr.writeln(
      'ERROR: provide --changed-files=<files> or --base=<sha> --head=<sha>.',
    );
    exit(64);
  }

  // Parse changesets
  final changesets = _loadChangesets(changesetsDir);

  // Run check
  final result = ReleasePlanner.check(
    changedFiles: changedFiles,
    changesets: changesets,
  );

  if (result.passed) {
    final publishablePkgs = PublishableClassifier.findPublishablePackages(
      changedFiles,
    );
    final pkgList = publishablePkgs.isEmpty
        ? 'none'
        : publishablePkgs.join(', ');
    stdout
      ..writeln('=== Changeset Release Intent Check ===')
      ..writeln()
      ..writeln('PASS: All publishable changes have matching changesets.')
      ..writeln()
      ..writeln('Changed files: ${changedFiles.length}')
      ..writeln('Publishable packages: $pkgList')
      ..writeln('Changesets found: ${changesets.length}');
    exit(0);
  } else {
    stderr
      ..writeln('=== Changeset Release Intent Check ===')
      ..writeln()
      ..writeln('FAIL: Missing changesets for publishable changes.')
      ..writeln()
      ..writeln(result.remediation);
    exit(1);
  }
}

Future<void> _handlePlan(List<String> args) async {
  final format = _extractArg(args, 'format').isEmpty
      ? 'markdown'
      : _extractArg(args, 'format');
  final changesetsDir = _extractArg(args, 'changesets-dir').isEmpty
      ? _defaultChangesetsDir
      : _extractArg(args, 'changesets-dir');

  if (format != 'markdown' && format != 'json') {
    stderr.writeln('ERROR: --format must be markdown or json.');
    exit(64);
  }

  final changesets = _loadChangesets(changesetsDir);
  final plan = ReleasePlanner.plan(changesets);

  if (format == 'json') {
    stdout.writeln(plan.renderJson());
  } else {
    stdout
      ..writeln('=== Release Plan ===')
      ..writeln()
      ..writeln('Changesets loaded: ${changesets.length}')
      ..writeln('Candidates: ${plan.candidates.length}')
      ..writeln()
      ..writeln(plan.renderMarkdown());
  }
}

Future<void> _handleVersionPr(List<String> args) async {
  final changesetsDir = _extractArg(args, 'changesets-dir').isEmpty
      ? _defaultChangesetsDir
      : _extractArg(args, 'changesets-dir');
  final workspaceRoot = _extractArg(args, 'workspace-root').isEmpty
      ? Directory.current.path
      : _extractArg(args, 'workspace-root');

  final changesets = _loadChangesets(changesetsDir);
  final plan = ReleasePlanner.plan(changesets);

  if (plan.candidates.isEmpty) {
    stdout
      ..writeln('=== Version PR ===')
      ..writeln()
      ..writeln('No release candidates — no changesets found.')
      ..writeln()
      ..writeln(
        'Publish handoff: no publish in slice one — '
        'tag-triggered OIDC publishing is planned for slice two.',
      );
    return;
  }

  stdout
    ..writeln('=== Version PR ===')
    ..writeln()
    ..writeln('Applying version edits to: $workspaceRoot')
    ..writeln('Candidates: ${plan.candidates.length}')
    ..writeln();

  final edits = VersionEditor.applyVersionEdits(plan, workspaceRoot);

  for (final edit in edits) {
    stdout.writeln('  ${edit.packageName}: ${edit.description}');
  }

  stdout
    ..writeln()
    ..writeln(plan.renderMarkdown());
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

Future<List<String>> _getGitDiffFiles(String base, String head) async {
  final result = await Process.run(
    'git',
    ['diff', '--name-only', '$base...$head'],
  );
  if (result.exitCode != 0) {
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
      ..writeln('git stderr: ${(result.stderr as String).trim()}');
    exit(69); // EX_UNAVAILABLE
  }
  final output = (result.stdout as String).trim();
  if (output.isEmpty) return [];
  return output.split('\n');
}
