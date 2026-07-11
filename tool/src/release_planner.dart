/// Release planner: parses changesets, classifies publishable files,
/// computes release plans with bump precedence and dependency propagation.
///
/// This module is the boundary for release intent. Candidates come ONLY
/// from changesets — validation expansion does not imply publication.
///
/// Slice 3 adds: release provenance, tag parsing/validation,
/// dependency preflight, and major release detection.
library;

import 'dart:convert';

/// Semantic version bump level.
enum BumpLevel {
  /// Bug fix or internal refactor.
  patch,

  /// Backwards-compatible API addition.
  minor,

  /// Breaking API change.
  major;

  /// Parses a bump level string.
  static BumpLevel parse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'patch':
        return BumpLevel.patch;
      case 'minor':
        return BumpLevel.minor;
      case 'major':
        return BumpLevel.major;
      default:
        throw FormatException(
          'Invalid bump level: "$value". Use patch, minor, or major.',
        );
    }
  }

  /// Returns the highest bump level from a non-empty list.
  static BumpLevel max(List<BumpLevel> levels) {
    if (levels.isEmpty) {
      throw StateError('Cannot compute max of empty bump list.');
    }
    return levels.reduce((a, b) => a.index >= b.index ? a : b);
  }
}

/// A parsed changeset with package bumps and changelog notes.
class Changeset {
  const Changeset({required this.bumps, required this.notes});

  /// Parses a changeset from Markdown content with YAML front matter.
  factory Changeset.parse(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('---')) {
      throw const FormatException(
        'Changeset must start with --- (YAML front matter).',
      );
    }

    final endIndex = trimmed.indexOf('---', 3);
    if (endIndex == -1) {
      throw const FormatException(
        'Changeset front matter must be closed with ---.',
      );
    }

    final frontMatter = trimmed.substring(3, endIndex).trim();
    if (frontMatter.isEmpty) {
      throw const FormatException(
        'Changeset front matter is empty. '
        'Add package: bump entries (e.g., explicit_outcome: minor).',
      );
    }

    final bumps = <String, BumpLevel>{};
    for (final line in frontMatter.split('\n')) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      final colonIndex = trimmedLine.indexOf(':');
      if (colonIndex == -1) {
        throw FormatException(
          'Invalid front matter line: "$trimmedLine". '
          'Expected format: package_name: bump_level',
        );
      }

      final packageName = trimmedLine.substring(0, colonIndex).trim();
      final bumpValue = trimmedLine.substring(colonIndex + 1).trim();
      bumps[packageName] = BumpLevel.parse(bumpValue);
    }

    if (bumps.isEmpty) {
      throw const FormatException(
        'No packages found in front matter. '
        'Add at least one package: bump entry.',
      );
    }

    final notes = trimmed.substring(endIndex + 3).trim();

    return Changeset(bumps: bumps, notes: notes);
  }

  /// Map of package names to their declared bump levels.
  final Map<String, BumpLevel> bumps;

  /// Changelog notes from the Markdown body.
  final String notes;
}

/// Classifies changed files as publishable or non-publishable.
class PublishableClassifier {
  /// Known publishable package names.
  static const List<String> publishablePackages = [
    'explicit_outcome',
    'explicit',
  ];

  /// Returns true if the file path represents a publishable change.
  ///
  /// Publishable paths:
  /// - `packages/<name>/lib/**`
  /// - `packages/<name>/pubspec.yaml`
  /// - `packages/<name>/example/**`
  ///
  /// Non-publishable: tests, docs, tooling, workflows, root configs.
  static bool isPublishable(String filePath) {
    for (final pkg in publishablePackages) {
      final prefix = 'packages/$pkg/';
      if (!filePath.startsWith(prefix)) continue;

      final relative = filePath.substring(prefix.length);

      // lib/** is publishable
      if (relative.startsWith('lib/')) return true;

      // pubspec.yaml is publishable
      if (relative == 'pubspec.yaml') return true;

      // example/** is publishable
      if (relative.startsWith('example/')) return true;
    }
    return false;
  }

  /// Extracts the package name from a publishable file path.
  ///
  /// Returns null if the path is not under a known package.
  static String? packageName(String filePath) {
    for (final pkg in publishablePackages) {
      if (filePath.startsWith('packages/$pkg/')) return pkg;
    }
    return null;
  }

  /// Returns unique package names that have publishable changes.
  static List<String> findPublishablePackages(List<String> changedFiles) {
    final packages = <String>{};
    for (final file in changedFiles) {
      if (isPublishable(file)) {
        final name = packageName(file);
        if (name != null) packages.add(name);
      }
    }
    return packages.toList()..sort();
  }
}

/// A single release candidate with its bump level and collected notes.
class ReleaseCandidate {
  const ReleaseCandidate({
    required this.packageName,
    required this.bump,
    required this.notes,
  });

  /// Package name.
  final String packageName;

  /// Resolved bump level (max across all changesets).
  final BumpLevel bump;

  /// Collected changelog notes from all changesets.
  final String notes;
}

/// A dependency update: when a package's dependency on another released
/// package should be bumped to the new caret range.
class DependencyUpdate {
  const DependencyUpdate({
    required this.packageName,
    required this.dependencyName,
  });

  /// The package whose dependency needs updating.
  final String packageName;

  /// The dependency being updated.
  final String dependencyName;
}

/// Result of a changeset check against changed files.
class CheckResult {
  const CheckResult({
    required this.passed,
    required this.missingPackages,
    required this.remediation,
  });

  /// Whether the check passed (all publishable changes have changesets).
  final bool passed;

  /// Package names that have publishable changes but no changeset.
  final List<String> missingPackages;

  /// Human-readable remediation message.
  final String remediation;
}

/// The computed release plan with candidates and dependency updates.
class ReleasePlan {
  const ReleasePlan({
    required this.candidates,
    required this.dependencyUpdates,
  });

  /// Release candidates in publish order.
  final List<ReleaseCandidate> candidates;

  /// Dependency updates needed when multiple packages are released.
  final List<DependencyUpdate> dependencyUpdates;

  /// Renders the plan as Markdown for logs and PR bodies.
  String renderMarkdown() {
    if (candidates.isEmpty) {
      return '## Release Plan\n\n'
          'No release candidates.\n\n'
          'Publish handoff: tag-triggered OIDC publishing is available '
          'via the publish workflow (publish.yaml).';
    }

    final buffer = StringBuffer()
      ..writeln('## Release Plan')
      ..writeln()
      ..writeln('### Candidates')
      ..writeln();

    for (final c in candidates) {
      buffer
        ..writeln('- **${c.packageName}**: ${c.bump.name}')
        ..writeln('  ${c.notes}')
        ..writeln();
    }

    if (dependencyUpdates.isNotEmpty) {
      buffer
        ..writeln('### Dependency Updates')
        ..writeln();
      for (final d in dependencyUpdates) {
        buffer.writeln(
          '- ${d.packageName} depends on ${d.dependencyName} '
          '(caret range update needed)',
        );
      }
      buffer.writeln();
    }

    buffer
      ..writeln('### Future Tag Names')
      ..writeln();
    for (final c in candidates) {
      buffer.writeln('- `${c.packageName}/v<next-version>`');
    }
    buffer
      ..writeln()
      ..writeln(
        'Publish handoff: tag-triggered OIDC publishing is available '
        'via the publish workflow (publish.yaml).',
      );

    return buffer.toString();
  }

  /// Renders the plan as JSON for machine consumption.
  String renderJson() {
    final data = {
      'candidates': candidates
          .map(
            (c) => {
              'package': c.packageName,
              'bump': c.bump.name,
              'notes': c.notes,
            },
          )
          .toList(),
      'dependencyUpdates': dependencyUpdates
          .map(
            (d) => {
              'package': d.packageName,
              'dependency': d.dependencyName,
            },
          )
          .toList(),
      'publishHandoff': 'tag-triggered OIDC publishing via publish.yaml',
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}

/// Computes release plans from changesets.
class ReleasePlanner {
  /// Computes a release plan from parsed changesets.
  ///
  /// Candidates come ONLY from changesets. Validation expansion
  /// does not imply publication.
  static ReleasePlan plan(List<Changeset> changesets) {
    // Merge bumps per package, taking the max.
    final packageBumps = <String, BumpLevel>{};
    final packageNotes = <String, List<String>>{};

    for (final cs in changesets) {
      for (final entry in cs.bumps.entries) {
        final pkg = entry.key;
        final bump = entry.value;
        final existing = packageBumps[pkg];
        packageBumps[pkg] = existing == null
            ? bump
            : BumpLevel.max([existing, bump]);
        packageNotes.putIfAbsent(pkg, () => <String>[]);
        if (cs.notes.isNotEmpty) {
          packageNotes[pkg]!.add(cs.notes);
        }
      }
    }

    // Build candidates in publish order (explicit_outcome first).
    final orderedNames = packageBumps.keys.toList()
      ..sort((a, b) {
        if (a == 'explicit_outcome') return -1;
        if (b == 'explicit_outcome') return 1;
        return a.compareTo(b);
      });

    final candidates = orderedNames
        .map(
          (name) => ReleaseCandidate(
            packageName: name,
            bump: packageBumps[name]!,
            notes: (packageNotes[name] ?? []).join('\n'),
          ),
        )
        .toList();

    // Dependency propagation: if both explicit_outcome and explicit are
    // released, explicit's dependency on explicit_outcome needs updating.
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

  /// Checks whether publishable changed files have matching changesets.
  ///
  /// Returns a [CheckResult] indicating pass/fail and missing packages.
  static CheckResult check({
    required List<String> changedFiles,
    required List<Changeset> changesets,
  }) {
    final publishablePackages = PublishableClassifier.findPublishablePackages(
      changedFiles,
    );

    // Collect packages covered by changesets.
    final coveredPackages = <String>{};
    for (final cs in changesets) {
      coveredPackages.addAll(cs.bumps.keys);
    }

    final missing = publishablePackages
        .where((pkg) => !coveredPackages.contains(pkg))
        .toList();

    if (missing.isEmpty) {
      return const CheckResult(
        passed: true,
        missingPackages: [],
        remediation: '',
      );
    }

    final remediationLines = <String>[
      'Missing changeset for: ${missing.join(', ')}',
      '',
      'Create a changeset with:',
      for (final pkg in missing)
        '  dart run tool/release_changeset.dart init --package=$pkg --bump=patch --summary="Describe your change"',
      '',
      'See .changesets/README.md for format details.',
    ];

    return CheckResult(
      passed: false,
      missingPackages: missing,
      remediation: remediationLines.join('\n'),
    );
  }
}

// ---------------------------------------------------------------------------
// Slice 3: Provenance, Tag Validation, Preflight, Major Detection
// ---------------------------------------------------------------------------

/// Release provenance manifest committed during version-pr.
///
/// Records the package, version, bump level, source changeset identifiers
/// (content hashes), and a hash of the changelog notes. Publish validation
/// requires this manifest to exist and agree with tag/pubspec/changelog.
class ReleaseProvenance {
  const ReleaseProvenance({
    required this.packageName,
    required this.version,
    required this.bump,
    required this.changesetHashes,
    required this.changelogNotesHash,
  });

  /// Parses provenance from a JSON string.
  ///
  /// Throws [FormatException] on malformed JSON or missing fields.
  factory ReleaseProvenance.fromJson(String jsonStr) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } on FormatException {
      throw const FormatException(
        'Provenance manifest is not valid JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Provenance manifest must be a JSON object.',
      );
    }

    final pkg = decoded['package'] as String?;
    final ver = decoded['version'] as String?;
    final bump = decoded['bump'] as String?;
    final hashes = decoded['changesetHashes'] as List<dynamic>?;
    final notesHash = decoded['changelogNotesHash'] as String?;

    if (pkg == null ||
        ver == null ||
        bump == null ||
        hashes == null ||
        notesHash == null) {
      throw const FormatException(
        'Provenance manifest is missing required fields '
        '(package, version, bump, changesetHashes, changelogNotesHash).',
      );
    }

    return ReleaseProvenance(
      packageName: pkg,
      version: ver,
      bump: bump,
      changesetHashes: hashes.cast<String>(),
      changelogNotesHash: notesHash,
    );
  }

  /// Package name this provenance belongs to.
  final String packageName;

  /// Release version.
  final String version;

  /// Bump level name (patch, minor, major).
  final String bump;

  /// Content hashes of source changesets that produced this release.
  final List<String> changesetHashes;

  /// Hash of the changelog notes for this release.
  final String changelogNotesHash;

  /// Serializes provenance to deterministic JSON.
  String toJson() {
    final data = {
      'package': packageName,
      'version': version,
      'bump': bump,
      'changesetHashes': changesetHashes,
      'changelogNotesHash': changelogNotesHash,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Computes a deterministic content hash for a given string.
  ///
  /// Uses a simple FNV-1a inspired hash for deterministic, dependency-free
  /// hashing suitable for content integrity checks (not cryptographic).
  static String computeContentHash(String content) {
    var hash = 0x811c9dc5;
    for (final codeUnit in content.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// Parsed release tag with package name and version.
class TagInfo {
  const TagInfo({required this.packageName, required this.version});

  /// Package name extracted from the tag.
  final String packageName;

  /// Semantic version extracted from the tag (without the `v` prefix).
  final String version;
}

/// Parses and validates release tags.
///
/// Tag contract: `<package>/v<semver>`, limited to `explicit_outcome`
/// and `explicit`. Rejects unknown packages, malformed semver, and
/// ambiguous formats.
class TagParser {
  /// Known publishable package names.
  static const List<String> _allowedPackages = [
    'explicit_outcome',
    'explicit',
  ];

  /// Parses a release tag string into a [TagInfo].
  ///
  /// Throws [FormatException] if the tag does not match the contract.
  static TagInfo parse(String tag) {
    if (tag.isEmpty) {
      throw const FormatException(
        'Release tag is empty. Expected <package>/v<semver>.',
      );
    }

    final slashIndex = tag.indexOf('/');
    if (slashIndex == -1) {
      throw FormatException(
        'Release tag "$tag" is missing the "/" separator. '
        'Expected format: <package>/v<semver>.',
      );
    }

    final packageName = tag.substring(0, slashIndex);
    final versionPart = tag.substring(slashIndex + 1);

    if (!_allowedPackages.contains(packageName)) {
      throw FormatException(
        'Unknown package "$packageName" in tag "$tag". '
        'Allowed packages: ${_allowedPackages.join(', ')}.',
      );
    }

    if (!versionPart.startsWith('v')) {
      throw FormatException(
        'Version part "$versionPart" in tag "$tag" must start with "v". '
        'Expected format: <package>/v<semver>.',
      );
    }

    final version = versionPart.substring(1);
    _validateSemver(version, tag);

    return TagInfo(packageName: packageName, version: version);
  }

  /// Validates that [version] is a valid semver string.
  ///
  /// Accepts `major.minor.patch` with optional pre-release suffix.
  static void _validateSemver(String version, String originalTag) {
    // Split off pre-release suffix if present.
    final corePart = version.contains('-')
        ? version.substring(0, version.indexOf('-'))
        : version;

    final parts = corePart.split('.');
    if (parts.length != 3) {
      throw FormatException(
        'Version "$version" in tag "$originalTag" is not valid semver. '
        'Expected major.minor.patch (e.g., 1.2.3).',
      );
    }

    for (final part in parts) {
      if (int.tryParse(part) == null) {
        throw FormatException(
          'Version "$version" in tag "$originalTag" has non-numeric '
          'component "$part". Each semver part must be a non-negative '
          'integer.',
        );
      }
    }
  }
}

/// Result of a release validation check.
class ReleaseValidation {
  const ReleaseValidation({
    required this.isValid,
    required this.errors,
    required this.packageName,
    required this.version,
    required this.isMajor,
  });

  /// Whether the release passed all validation gates.
  final bool isValid;

  /// Validation error messages (empty when [isValid] is true).
  final List<String> errors;

  /// Package name from the tag (always populated if tag parsed).
  final String packageName;

  /// Version from the tag (always populated if tag parsed).
  final String version;

  /// Whether this is a major release.
  final bool isMajor;
}

/// Validates a release tag against pubspec, changelog, and provenance.
///
/// All four sources must agree on package name and version.
/// Fails closed on absent or malformed provenance.
///
/// When a metadata fetcher is provided and the package is `explicit`,
/// runs dependency preflight to verify `explicit_outcome` availability.
class ReleaseValidator {
  /// Validates a release from its tag, pubspec, changelog, and provenance.
  ///
  /// [provenanceJson] may be null (absent provenance fails closed).
  /// [metadataFetcher] is optional; when provided, enables dependency
  /// preflight for `explicit` package validation.
  static ReleaseValidation validateRelease({
    required String tag,
    required String pubspecContent,
    required String changelogContent,
    required String? provenanceJson,
    PubDevMetadata Function(String packageName)? metadataFetcher,
  }) {
    final errors = <String>[];

    // Parse the tag.
    final TagInfo tagInfo;
    try {
      tagInfo = TagParser.parse(tag);
    } on FormatException catch (e) {
      return ReleaseValidation(
        isValid: false,
        errors: ['Tag parse failed: ${e.message}'],
        packageName: '',
        version: '',
        isMajor: false,
      );
    }

    // Read pubspec version.
    final pubspecVersion = _readVersionFromPubspec(pubspecContent);
    if (pubspecVersion == null) {
      errors.add(
        'Pubspec version not found for ${tagInfo.packageName}.',
      );
    } else if (pubspecVersion != tagInfo.version) {
      errors.add(
        'Version mismatch: tag says ${tagInfo.version}, '
        'pubspec says $pubspecVersion.',
      );
    }

    // Check changelog heading.
    final hasChangelogHeading = changelogContent.contains(
      '## ${tagInfo.version}',
    );
    if (!hasChangelogHeading) {
      errors.add(
        'changelog heading "## ${tagInfo.version}" not found '
        'in ${tagInfo.packageName} CHANGELOG.md.',
      );
    }

    // Validate provenance (fail closed).
    String? provenanceBump;
    if (provenanceJson == null) {
      errors.add(
        'Release provenance manifest is absent for '
        '${tagInfo.packageName}/v${tagInfo.version}. '
        'Provenance is required for publish validation',
      );
    } else {
      final ReleaseProvenance provenance;
      try {
        provenance = ReleaseProvenance.fromJson(provenanceJson);
      } on FormatException catch (e) {
        errors.add(
          'Release provenance manifest is malformed for '
          '${tagInfo.packageName}/v${tagInfo.version}: ${e.message}',
        );
        return ReleaseValidation(
          isValid: false,
          errors: errors,
          packageName: tagInfo.packageName,
          version: tagInfo.version,
          isMajor: false,
        );
      }

      if (provenance.packageName != tagInfo.packageName) {
        errors.add(
          'Provenance package "${provenance.packageName}" does not '
          'match tag package "${tagInfo.packageName}".',
        );
      }
      if (provenance.version != tagInfo.version) {
        errors.add(
          'Provenance version "${provenance.version}" does not '
          'match tag version "${tagInfo.version}".',
        );
      }

      // Extract provenance bump for major detection.
      provenanceBump = provenance.bump;
    }

    // Detect major release using provenance bump (primary source).
    final isMajor = MajorDetector.isMajorRelease(
      tagVersion: tagInfo.version,
      pubspecContent: pubspecContent,
      provenanceBump: provenanceBump,
    );

    // Run dependency preflight for `explicit` package.
    if (tagInfo.packageName == 'explicit' && metadataFetcher != null) {
      final preflight = DependencyPreflight.check(
        explicitPubspecContent: pubspecContent,
        metadataFetcher: metadataFetcher,
      );
      if (!preflight.isSatisfied) {
        errors.addAll(preflight.errors);
      }
    }

    return ReleaseValidation(
      isValid: errors.isEmpty,
      errors: errors,
      packageName: tagInfo.packageName,
      version: tagInfo.version,
      isMajor: isMajor,
    );
  }

  /// Reads the `version:` field from pubspec content.
  static String? _readVersionFromPubspec(String pubspecContent) {
    for (final line in pubspecContent.split('\n')) {
      if (line.startsWith('version:') || line.startsWith('version :')) {
        final colonIdx = line.indexOf(':');
        return line.substring(colonIdx + 1).trim();
      }
    }
    return null;
  }
}

/// Detects whether a release tag represents a major version bump.
///
/// Primary detection uses the provenance `bump` field (committed during
/// version-pr). Falls back to comparing tag major vs pubspec major when
/// provenance is unavailable (legacy path).
class MajorDetector {
  /// Returns true if the release is a major version bump.
  ///
  /// When [provenanceBump] is provided (normal path), uses it directly:
  /// `major` → true, anything else → false.
  ///
  /// When [provenanceBump] is null (fallback), compares tag major to
  /// pubspec major: strictly greater → true.
  static bool isMajorRelease({
    required String tagVersion,
    required String pubspecContent,
    String? provenanceBump,
  }) {
    // Primary: use provenance bump (authoritative source).
    if (provenanceBump != null) {
      return provenanceBump == 'major';
    }

    // Fallback: compare tag major to pubspec major.
    final tagMajor = _parseMajor(tagVersion);
    final pubspecVersion = _readVersionFromPubspec(pubspecContent);
    if (pubspecVersion == null || tagMajor == null) return false;

    final pubspecMajor = _parseMajor(pubspecVersion);
    if (pubspecMajor == null) return false;

    return tagMajor > pubspecMajor;
  }

  /// Extracts the major version number from a semver string.
  static int? _parseMajor(String version) {
    final corePart = version.contains('-')
        ? version.substring(0, version.indexOf('-'))
        : version;
    final parts = corePart.split('.');
    if (parts.isEmpty) return null;
    return int.tryParse(parts[0]);
  }

  /// Reads the `version:` field from pubspec content.
  static String? _readVersionFromPubspec(String pubspecContent) {
    for (final line in pubspecContent.split('\n')) {
      if (line.startsWith('version:') || line.startsWith('version :')) {
        final colonIdx = line.indexOf(':');
        return line.substring(colonIdx + 1).trim();
      }
    }
    return null;
  }
}

/// Pub.dev package metadata for dependency preflight.
///
/// Injectable for testing — production code fetches from pub.dev API,
/// tests inject deterministic fixtures.
class PubDevMetadata {
  const PubDevMetadata({
    required this.packageName,
    required this.versions,
  });

  /// Package name on pub.dev.
  final String packageName;

  /// All published versions.
  final List<String> versions;
}

/// Result of a dependency preflight check.
class PreflightResult {
  const PreflightResult({
    required this.isSatisfied,
    required this.errors,
  });

  /// Whether the dependency constraint is satisfied.
  final bool isSatisfied;

  /// Error messages (empty when [isSatisfied] is true).
  final List<String> errors;
}

/// Preflight check: verifies that `explicit`'s dependency on
/// `explicit_outcome` is satisfied by published versions on pub.dev.
///
/// Fails closed on metadata/network errors. Metadata fetching is
/// injectable for deterministic testing.
class DependencyPreflight {
  /// Checks whether the required `explicit_outcome` version exists
  /// on pub.dev before allowing `explicit` to publish.
  ///
  /// [metadataFetcher] is a function that returns metadata for a given
  /// package name. Tests inject fixtures; production uses pub.dev API.
  static PreflightResult check({
    required String explicitPubspecContent,
    required PubDevMetadata Function(String packageName) metadataFetcher,
  }) {
    // Read the explicit_outcome constraint from explicit's pubspec.
    final constraint = _readDependencyConstraint(
      explicitPubspecContent,
      'explicit_outcome',
    );

    // If explicit doesn't depend on explicit_outcome, skip preflight.
    if (constraint == null) {
      return const PreflightResult(isSatisfied: true, errors: []);
    }

    // Fetch pub.dev metadata (fail closed on errors).
    final PubDevMetadata metadata;
    try {
      metadata = metadataFetcher('explicit_outcome');
    } on Exception catch (e) {
      final msg = 'Failed to fetch pub.dev metadata for '
          'explicit_outcome: $e. Failing closed — cannot '
          'verify dependency availability.';
      return PreflightResult(
        isSatisfied: false,
        errors: [msg],
      );
    }

    // Check if the required version exists and satisfies the constraint.
    final requiredVersion = _extractCaretVersion(constraint);
    if (requiredVersion == null) {
      return const PreflightResult(isSatisfied: true, errors: []);
    }

    final hasVersion = metadata.versions.contains(requiredVersion);
    if (!hasVersion) {
      // Also check if any version satisfies the caret constraint.
      final satisfying = metadata.versions.where(
        (v) => _satisfiesCaret(v, requiredVersion),
      );
      if (satisfying.isEmpty) {
        final msg = 'No published version of explicit_outcome '
            'satisfies constraint ^$requiredVersion. '
            'explicit_outcome must be published before explicit.';
        return PreflightResult(
          isSatisfied: false,
          errors: [msg],
        );
      }
    }

    return const PreflightResult(isSatisfied: true, errors: []);
  }

  /// Reads a dependency constraint from pubspec content.
  ///
  /// Returns the constraint string (e.g., "^0.1.0") or null if
  /// the dependency is not declared.
  static String? _readDependencyConstraint(
    String pubspecContent,
    String dependencyName,
  ) {
    for (final line in pubspecContent.split('\n')) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('$dependencyName:') ||
          trimmed.startsWith('$dependencyName :')) {
        final colonIdx = trimmed.indexOf(':');
        return trimmed.substring(colonIdx + 1).trim();
      }
    }
    return null;
  }

  /// Extracts the version from a caret constraint like "^0.1.0".
  static String? _extractCaretVersion(String constraint) {
    if (constraint.startsWith('^')) {
      return constraint.substring(1);
    }
    return null;
  }

  /// Checks if [version] satisfies a caret constraint `^[baseVersion]`.
  ///
  /// Caret means: >= baseVersion and < next breaking version.
  static bool _satisfiesCaret(String version, String baseVersion) {
    final vParts = version.split('.');
    final bParts = baseVersion.split('.');
    if (vParts.length < 3 || bParts.length < 3) return false;

    final vMajor = int.tryParse(vParts[0]);
    final vMinor = int.tryParse(vParts[1]);
    final vPatch = int.tryParse(vParts[2]);
    final bMajor = int.tryParse(bParts[0]);
    final bMinor = int.tryParse(bParts[1]);
    final bPatch = int.tryParse(bParts[2]);

    if (vMajor == null ||
        vMinor == null ||
        vPatch == null ||
        bMajor == null ||
        bMinor == null ||
        bPatch == null) {
      return false;
    }

    // Must be >= base version.
    if (vMajor < bMajor) return false;
    if (vMajor == bMajor && vMinor < bMinor) return false;
    if (vMajor == bMajor && vMinor == bMinor && vPatch < bPatch) return false;

    // Must be < next breaking version.
    if (bMajor > 0) {
      return vMajor == bMajor;
    } else if (bMinor > 0) {
      return vMajor == 0 && vMinor == bMinor;
    } else {
      return vMajor == 0 && vMinor == 0 && vPatch == bPatch;
    }
  }
}
