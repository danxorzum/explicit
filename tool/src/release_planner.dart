/// Release planner: parses changesets, classifies publishable files,
/// computes release plans with bump precedence and dependency propagation.
///
/// This module is the boundary for release intent. Candidates come ONLY
/// from changesets — validation expansion does not imply publication.
///
/// Adds release provenance, tag parsing/validation, and dependency preflight.
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
    this.impactProof = const [],
  });

  /// Package name.
  final String packageName;

  /// Resolved bump level (max across all changesets).
  final BumpLevel bump;

  /// Collected changelog notes from all changesets.
  final String notes;

  /// Files that proved real package impact during reconciliation.
  final List<String> impactProof;
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
          'No release tags will be created for this plan.';
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
      ..writeln('### Post-Merge Tag Names')
      ..writeln();
    for (final c in candidates) {
      buffer.writeln('- `${c.packageName}/v<next-version>`');
    }
    buffer
      ..writeln()
      ..writeln(
        'Version PR merge prepares validated release provenance. '
        'After CI is green, the maintainer manually creates release tags. '
        'Tags then trigger OIDC publishing via publish.yaml.',
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
            (d) => {'package': d.packageName, 'dependency': d.dependencyName},
          )
          .toList(),
      'publishFlow':
          'version PR merge prepares validated provenance; maintainer manually '
          'creates tags; tags trigger OIDC publishing via publish.yaml',
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
// Provenance, tag validation, and preflight
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
    required this.previousVersion,
    required this.nextVersion,
    required this.bump,
    required this.changesetHashes,
    required this.changelogNotesHash,
    required this.tag,
    this.provenanceSource = expectedProvenanceSource,
    this.changesetContents = const [],
    this.impactProof = const [],
  });

  /// Parses provenance from a JSON string.
  ///
  /// Throws [FormatException] on malformed JSON or missing fields.
  factory ReleaseProvenance.fromJson(String jsonStr) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } on FormatException {
      throw const FormatException('Provenance manifest is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Provenance manifest must be a JSON object.');
    }

    final pkg = decoded['package'] as String?;
    final ver = decoded['version'] as String?;
    final prevVer = decoded['previousVersion'] as String?;
    final nextVer = decoded['nextVersion'] as String?;
    final bump = decoded['bump'] as String?;
    final hashes = decoded['changesetHashes'] as List<dynamic>?;
    final contents = decoded['changesetContents'] as List<dynamic>?;
    final impactProof = decoded['impactProof'] as List<dynamic>?;
    final notesHash = decoded['changelogNotesHash'] as String?;
    final tag = decoded['tag'] as String?;
    final provenanceSource = decoded['provenanceSource'] as String?;

    if (pkg == null ||
        ver == null ||
        prevVer == null ||
        nextVer == null ||
        bump == null ||
        hashes == null ||
        notesHash == null ||
        tag == null ||
        provenanceSource == null) {
      throw const FormatException(
        'Provenance manifest is missing required fields '
        '(package, version, previousVersion, nextVersion, bump, '
        'changesetHashes, changelogNotesHash, tag, provenanceSource).',
      );
    }

    return ReleaseProvenance(
      packageName: pkg,
      version: ver,
      previousVersion: prevVer,
      nextVersion: nextVer,
      bump: bump,
      changesetHashes: hashes.cast<String>(),
      changesetContents: contents?.cast<String>() ?? const [],
      impactProof: impactProof?.cast<String>() ?? const [],
      changelogNotesHash: notesHash,
      tag: tag,
      provenanceSource: provenanceSource,
    );
  }

  /// Required provenance source emitted by the version PR workflow.
  static const String expectedProvenanceSource =
      'release_version_pr.version-pr.v1';

  /// Package name this provenance belongs to.
  final String packageName;

  /// Release version (nextVersion).
  final String version;

  /// Version before the bump (previousVersion).
  final String previousVersion;

  /// Version after the bump (nextVersion).
  ///
  /// This intentionally duplicates [version], which remains the tag/pubspec
  /// version, so validation can prove the committed version PR output and the
  /// release tag are describing the same transition.
  final String nextVersion;

  /// Bump level name (patch, minor, major).
  final String bump;

  /// Content hashes of source changesets that produced this release.
  final List<String> changesetHashes;

  /// Immutable changeset contents captured by the version PR.
  ///
  /// Version PRs remove consumed changesets, so validation cannot rely on the
  /// original markdown files still existing after merge. Capturing the source
  /// contents here lets validation recompute [changesetHashes]
  /// deterministically from committed provenance instead of trusting the hash
  /// field alone.
  final List<String> changesetContents;

  /// Files that proved real package impact for this candidate.
  final List<String> impactProof;

  /// Hash of the changelog notes for this release.
  final String changelogNotesHash;

  /// Intended release tag (e.g., explicit_outcome/v0.1.0).
  final String tag;

  /// Workflow source that prepared this provenance for manual tag publishing.
  final String provenanceSource;

  /// Serializes provenance to deterministic JSON.
  String toJson() {
    final data = {
      'package': packageName,
      'version': version,
      'previousVersion': previousVersion,
      'nextVersion': nextVersion,
      'bump': bump,
      'changesetHashes': changesetHashes,
      'changesetContents': changesetContents,
      'impactProof': impactProof,
      'changelogNotesHash': changelogNotesHash,
      'tag': tag,
      'provenanceSource': provenanceSource,
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
  static const List<String> _allowedPackages = ['explicit_outcome', 'explicit'];

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
      errors.add('Pubspec version not found for ${tagInfo.packageName}.');
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
      if (provenance.nextVersion != provenance.version) {
        errors.add(
          'Provenance nextVersion "${provenance.nextVersion}" does not '
          'match provenance version "${provenance.version}".',
        );
      }

      if (!_isValidBump(provenance.bump)) {
        errors.add(
          'Provenance bump "${provenance.bump}" is invalid. '
          'Expected patch, minor, or major.',
        );
      }

      // Validate provenance tag matches release tag.
      final expectedTag = '${tagInfo.packageName}/v${tagInfo.version}';
      if (provenance.tag != expectedTag) {
        errors.add(
          'Provenance tag "${provenance.tag}" does not match '
          'release tag "$expectedTag".',
        );
      }

      if (provenance.provenanceSource !=
          ReleaseProvenance.expectedProvenanceSource) {
        errors.add(
          'Provenance source "${provenance.provenanceSource}" '
          'does not match the approved version PR source '
          '"${ReleaseProvenance.expectedProvenanceSource}".',
        );
      }

      // Validate previousVersion + bump → version consistency.
      final expectedNextVersion = _computeExpectedNextVersion(
        provenance.previousVersion,
        provenance.bump,
      );
      if (expectedNextVersion != null &&
          expectedNextVersion != provenance.nextVersion) {
        errors.add(
          'Provenance previousVersion "${provenance.previousVersion}" '
          '+ bump "${provenance.bump}" should produce '
          '"$expectedNextVersion" but provenance version is '
          '"${provenance.nextVersion}".',
        );
      }

      // Detect major bypass: if previousVersion → version implies major
      // but provenance bump says patch or minor.
      final impliedBump = _impliedBumpLevel(
        provenance.previousVersion,
        provenance.nextVersion,
      );
      if (impliedBump == 'major' && provenance.bump != 'major') {
        errors.add(
          'Provenance bump "${provenance.bump}" is inconsistent with '
          'major version change from "${provenance.previousVersion}" '
          'to "${provenance.version}". '
          'Major releases require a changeset-declared major bump before the '
          'maintainer creates the release tag.',
        );
      }

      _validateImpactProof(
        provenance: provenance,
        tagPackage: tagInfo.packageName,
        errors: errors,
      );
      _validateChangelogNotesHash(
        provenance: provenance,
        changelogContent: changelogContent,
        tagVersion: tagInfo.version,
        errors: errors,
      );
      _validateChangesetProof(provenance: provenance, errors: errors);

      // Extract provenance bump for release metadata.
      provenanceBump = provenance.bump;
    }

    final isMajor = provenanceBump == 'major';

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

  /// Computes the expected next version from previousVersion and bump.
  ///
  /// Returns null if the inputs are invalid.
  static String? _computeExpectedNextVersion(
    String previousVersion,
    String bump,
  ) {
    final parts = previousVersion.split('.');
    if (parts.length != 3) return null;

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);

    if (major == null || minor == null || patch == null) return null;

    switch (bump) {
      case 'patch':
        return '$major.$minor.${patch + 1}';
      case 'minor':
        return '$major.${minor + 1}.0';
      case 'major':
        return '${major + 1}.0.0';
      default:
        return null;
    }
  }

  /// Returns true when [bump] is an allowed release bump value.
  static bool _isValidBump(String bump) {
    return bump == 'patch' || bump == 'minor' || bump == 'major';
  }

  static void _validateImpactProof({
    required ReleaseProvenance provenance,
    required String tagPackage,
    required List<String> errors,
  }) {
    if (provenance.impactProof.isEmpty) {
      errors.add(
        'Provenance impactProof is required and must contain at least one '
        'real impacted file for $tagPackage.',
      );
      return;
    }

    final packagePrefix = 'packages/$tagPackage/';
    final invalid = provenance.impactProof
        .where((path) => path.trim().isEmpty || !path.startsWith(packagePrefix))
        .toList();
    if (invalid.isNotEmpty) {
      errors.add(
        'Provenance impactProof contains files outside $packagePrefix: '
        '${invalid.join(', ')}.',
      );
    }
  }

  static void _validateChangelogNotesHash({
    required ReleaseProvenance provenance,
    required String changelogContent,
    required String tagVersion,
    required List<String> errors,
  }) {
    final notes = _extractChangelogNotesForVersion(
      changelogContent,
      tagVersion,
    );
    if (notes == null) {
      errors.add(
        'Cannot validate changelogNotesHash because changelog notes for '
        '$tagVersion could not be extracted.',
      );
      return;
    }

    final actualHash = ReleaseProvenance.computeContentHash(notes);
    if (actualHash != provenance.changelogNotesHash) {
      errors.add(
        'Provenance changelogNotesHash "${provenance.changelogNotesHash}" '
        'does not match recomputed changelog notes hash "$actualHash".',
      );
    }
  }

  static void _validateChangesetProof({
    required ReleaseProvenance provenance,
    required List<String> errors,
  }) {
    if (provenance.changesetContents.isEmpty) {
      errors.add(
        'Provenance changesetContents is required to recompute '
        'changesetHashes after consumed changesets are removed.',
      );
      return;
    }

    final actualHashes = provenance.changesetContents
        .map(ReleaseProvenance.computeContentHash)
        .toList();
    if (!_sameStringList(actualHashes, provenance.changesetHashes)) {
      errors.add(
        'Provenance changesetHashes do not match recomputed hashes from '
        'changesetContents. Expected ${actualHashes.join(', ')}.',
      );
    }

    final packageDeclaration = '${provenance.packageName}:';
    if (!provenance.changesetContents.any(
      (content) => content.contains(packageDeclaration),
    )) {
      errors.add(
        'Provenance changesetContents do not declare '
        '${provenance.packageName}.',
      );
    }
  }

  static String? _extractChangelogNotesForVersion(
    String changelogContent,
    String version,
  ) {
    final lines = changelogContent.split('\n');
    final notes = <String>[];
    var inSection = false;

    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (inSection) break;
        final heading = line.substring(3).trim();
        if (heading == version || heading.startsWith('$version ')) {
          inSection = true;
        }
        continue;
      }

      if (inSection) {
        notes.add(line);
      }
    }

    if (!inSection) return null;
    return notes.join('\n').trim();
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Determines the implied bump level from previousVersion to nextVersion.
  ///
  /// Returns 'major', 'minor', 'patch', or 'unknown'.
  static String _impliedBumpLevel(String previousVersion, String nextVersion) {
    final prevParts = previousVersion.split('.');
    final nextParts = nextVersion.split('.');
    if (prevParts.length != 3 || nextParts.length != 3) return 'unknown';

    final prevMajor = int.tryParse(prevParts[0]);
    final nextMajor = int.tryParse(nextParts[0]);

    if (prevMajor == null || nextMajor == null) return 'unknown';

    if (nextMajor > prevMajor) return 'major';

    final prevMinor = int.tryParse(prevParts[1]);
    final nextMinor = int.tryParse(nextParts[1]);

    if (prevMinor == null || nextMinor == null) return 'unknown';

    if (nextMinor > prevMinor) return 'minor';

    return 'patch';
  }
}

/// Pub.dev package metadata for dependency preflight.
///
/// Injectable for testing — production code fetches from pub.dev API,
/// tests inject deterministic fixtures.
class PubDevMetadata {
  const PubDevMetadata({required this.packageName, required this.versions});

  /// Package name on pub.dev.
  final String packageName;

  /// All published versions.
  final List<String> versions;
}

/// Result of a dependency preflight check.
class PreflightResult {
  const PreflightResult({required this.isSatisfied, required this.errors});

  /// Whether the dependency constraint is satisfied.
  final bool isSatisfied;

  /// Error messages (empty when [isSatisfied] is true).
  final List<String> errors;
}

// ---------------------------------------------------------------------------
// Corrective Slice 1: Content-Aware Impact Classifier + Reconciliation
// ---------------------------------------------------------------------------

/// A changed file with optional diff content for impact analysis.
///
/// When [diffContent] is provided, the classifier performs content-aware
/// analysis to distinguish real code changes from comment/whitespace-only
/// changes. When absent, the classifier falls back to path-based analysis.
class ChangedFile {
  const ChangedFile({required this.path, this.diffContent});

  /// File path relative to the repository root.
  final String path;

  /// Unified diff content for the file (optional).
  ///
  /// When provided, enables content-aware analysis for Dart files.
  final String? diffContent;
}

/// Classification category for a changed file's impact.
enum ImpactCategory {
  /// Real code/token changes that affect package behavior.
  realImpact,

  /// Documentation-only changes (README, CHANGELOG, .md files).
  docsOnly,

  /// Test-only changes (no production impact).
  testOnly,

  /// Example-only changes (no published API impact).
  exampleOnly,

  /// Dart file with only comment changes (no token changes).
  commentOnly,

  /// Dart file with only whitespace/formatting changes.
  whitespaceOnly,

  /// File is not under a publishable package path.
  notPublishable,
}

/// Classification result for a single changed file.
class FileClassification {
  const FileClassification({
    required this.filePath,
    required this.category,
    required this.packageName,
  });

  /// File path relative to the repository root.
  final String filePath;

  /// The determined impact category.
  final ImpactCategory category;

  /// Package name if the file belongs to a known package, null otherwise.
  final String? packageName;
}

/// Aggregated package-level impact from all changed files.
class PackageImpact {
  const PackageImpact({
    required this.packageName,
    required this.hasRealImpact,
    required this.impactedFiles,
    required this.ignoredFiles,
  });

  /// Package name.
  final String packageName;

  /// Whether the package has at least one real code change.
  final bool hasRealImpact;

  /// Files that contribute real impact.
  final List<String> impactedFiles;

  /// Files that were ignored (docs, comments, whitespace, etc.).
  final List<String> ignoredFiles;
}

/// Result of content-aware impact classification across all changed files.
class ImpactClassification {
  const ImpactClassification({
    required this.packageImpacts,
    required this.classifications,
  });

  /// Per-package aggregated impact.
  final Map<String, PackageImpact> packageImpacts;

  /// Individual file classifications.
  final List<FileClassification> classifications;

  /// Package names that have real impact (sorted).
  List<String> get impactedPackages {
    return packageImpacts.entries
        .where((e) => e.value.hasRealImpact)
        .map((e) => e.key)
        .toList()
      ..sort();
  }
}

/// Analyzes unified diffs for Dart files to detect real code token changes.
///
/// Strips comments (single-line `//`, doc `///`, block `/* */`) and
/// whitespace from diff lines, then checks if any meaningful tokens remain
/// in the additions or removals.
class DartDiffAnalyzer {
  /// Returns true if the diff contains real Dart code token changes.
  ///
  /// Analyzes only `+` and `-` lines from unified diff format.
  /// Strips comments (including multi-line block comments) and normalizes
  /// whitespace; if the resulting token streams differ, the change is
  /// considered real.
  static bool hasRealCodeChanges(String diffContent) {
    if (diffContent.trim().isEmpty) return false;

    final lines = diffContent.split('\n');
    final addedLines = <String>[];
    final removedLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('+') && !line.startsWith('+++')) {
        addedLines.add(line.substring(1));
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        removedLines.add(line.substring(1));
      }
    }

    // Strip comments (tracking block comment state across lines) and
    // normalize whitespace to produce token streams.
    final addedTokens = _extractTokens(addedLines);
    final removedTokens = _extractTokens(removedLines);

    // If both token streams are empty, only comments/whitespace changed.
    if (addedTokens.isEmpty && removedTokens.isEmpty) return false;

    // If token streams are identical, it's a format/whitespace-only change.
    if (addedTokens == removedTokens) return false;

    return true;
  }

  /// Extracts a normalized token string from a list of diff lines,
  /// stripping comments (including multi-line block comments) and
  /// collapsing all whitespace.
  static String _extractTokens(List<String> lines) {
    final buffer = StringBuffer();
    var inBlockComment = false;

    for (final line in lines) {
      var current = line;

      // Handle multi-line block comment continuation.
      if (inBlockComment) {
        final endIdx = current.indexOf('*/');
        if (endIdx == -1) {
          continue; // entire line is inside block comment
        }
        current = current.substring(endIdx + 2);
        inBlockComment = false;
      }

      // Process the remaining content for comments.
      final processed = _stripAllComments(current);
      if (processed.inBlockComment) {
        inBlockComment = true;
      }
      buffer
        ..write(processed.text)
        ..write(' ');
    }

    // Normalize: strip all whitespace to detect format-only changes.
    return buffer.toString().replaceAll(RegExp(r'\s+'), '');
  }

  /// Result of stripping comments from a line.
  static _StripResult _stripAllComments(String line) {
    final buffer = StringBuffer();
    var i = 0;
    var inSingleQuote = false;
    var inDoubleQuote = false;

    while (i < line.length) {
      final ch = line[i];

      // Check for single-line comment.
      if (!inSingleQuote &&
          !inDoubleQuote &&
          ch == '/' &&
          i + 1 < line.length &&
          line[i + 1] == '/') {
        // Rest of line is a comment.
        break;
      }

      // Check for block comment start.
      if (!inSingleQuote &&
          !inDoubleQuote &&
          ch == '/' &&
          i + 1 < line.length &&
          line[i + 1] == '*') {
        // Find the end of the block comment on this line.
        final endIdx = line.indexOf('*/', i + 2);
        if (endIdx != -1) {
          i = endIdx + 2;
          continue;
        } else {
          // Block comment continues to next lines.
          return _StripResult(text: buffer.toString(), inBlockComment: true);
        }
      }

      // Track string literals.
      if (ch == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (ch == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      }

      buffer.write(ch);
      i++;
    }

    return _StripResult(text: buffer.toString(), inBlockComment: false);
  }
}

/// Internal result of stripping comments from a single line.
class _StripResult {
  const _StripResult({required this.text, required this.inBlockComment});

  /// The line content after removing comments.
  final String text;

  /// Whether a block comment was opened and not closed on this line.
  final bool inBlockComment;
}

/// Content-aware impact classifier for Dart package source changes.
///
/// Classifies each changed file into an [ImpactCategory] based on its
/// path and optional diff content. Aggregates results per-package to
/// determine which packages have real impact.
class ImpactClassifier {
  /// Classifies a list of changed files into impact categories.
  ///
  /// For Dart files under `lib/`, uses [DartDiffAnalyzer] when diff
  /// content is available to distinguish real code changes from
  /// comment-only or whitespace-only changes.
  static ImpactClassification classify(List<ChangedFile> files) {
    final classifications = <FileClassification>[];
    final packageFiles = <String, List<FileClassification>>{};

    for (final file in files) {
      final classification = _classifyFile(file);
      classifications.add(classification);

      if (classification.packageName != null) {
        packageFiles
            .putIfAbsent(classification.packageName!, () => [])
            .add(classification);
      }
    }

    // Aggregate per-package impact.
    final packageImpacts = <String, PackageImpact>{};
    for (final entry in packageFiles.entries) {
      final pkg = entry.key;
      final fileClassifications = entry.value;
      final impacted = fileClassifications
          .where((c) => c.category == ImpactCategory.realImpact)
          .map((c) => c.filePath)
          .toList();
      final ignored = fileClassifications
          .where((c) => c.category != ImpactCategory.realImpact)
          .map((c) => c.filePath)
          .toList();

      packageImpacts[pkg] = PackageImpact(
        packageName: pkg,
        hasRealImpact: impacted.isNotEmpty,
        impactedFiles: impacted,
        ignoredFiles: ignored,
      );
    }

    return ImpactClassification(
      packageImpacts: packageImpacts,
      classifications: classifications,
    );
  }

  /// Classifies a single file based on its path and optional diff content.
  static FileClassification _classifyFile(ChangedFile file) {
    final path = file.path;

    // Determine package ownership.
    final pkg = PublishableClassifier.packageName(path);
    if (pkg == null) {
      return FileClassification(
        filePath: path,
        category: ImpactCategory.notPublishable,
        packageName: null,
      );
    }

    final prefix = 'packages/$pkg/';
    final relative = path.substring(prefix.length);

    // Test files → testOnly.
    if (relative.startsWith('test/')) {
      return FileClassification(
        filePath: path,
        category: ImpactCategory.testOnly,
        packageName: pkg,
      );
    }

    // Example files → exampleOnly.
    if (relative.startsWith('example/')) {
      return FileClassification(
        filePath: path,
        category: ImpactCategory.exampleOnly,
        packageName: pkg,
      );
    }

    // Documentation files → docsOnly.
    if (_isDocFile(relative)) {
      return FileClassification(
        filePath: path,
        category: ImpactCategory.docsOnly,
        packageName: pkg,
      );
    }

    // pubspec.yaml → always real impact.
    if (relative == 'pubspec.yaml') {
      return FileClassification(
        filePath: path,
        category: ImpactCategory.realImpact,
        packageName: pkg,
      );
    }

    // lib/** files — content-aware analysis if diff available.
    if (relative.startsWith('lib/')) {
      if (file.diffContent != null) {
        final hasReal = DartDiffAnalyzer.hasRealCodeChanges(file.diffContent!);
        if (!hasReal) {
          // Determine if it's comment-only or whitespace-only.
          final category = _classifyNonRealDiff(file.diffContent!);
          return FileClassification(
            filePath: path,
            category: category,
            packageName: pkg,
          );
        }
      }
      // Real change or no diff to analyze (fallback: assume real).
      return FileClassification(
        filePath: path,
        category: ImpactCategory.realImpact,
        packageName: pkg,
      );
    }

    // Other package files (e.g., build.yaml) → not publishable.
    return FileClassification(
      filePath: path,
      category: ImpactCategory.notPublishable,
      packageName: pkg,
    );
  }

  /// Returns true if the relative path is a documentation file.
  static bool _isDocFile(String relativePath) {
    final lower = relativePath.toLowerCase();
    if (lower.endsWith('.md')) return true;
    if (lower == 'readme') return true;
    if (lower == 'changelog') return true;
    if (lower == 'license') return true;
    return false;
  }

  /// Classifies a non-real diff as comment-only or whitespace-only.
  static ImpactCategory _classifyNonRealDiff(String diffContent) {
    final lines = diffContent.split('\n');
    var hasCommentContent = false;

    for (final line in lines) {
      if (line.startsWith('+') && !line.startsWith('+++')) {
        final content = line.substring(1).trim();
        if (content.startsWith('//') ||
            content.startsWith('///') ||
            content.startsWith('/*') ||
            content.startsWith('*') ||
            content.endsWith('*/')) {
          hasCommentContent = true;
        }
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        final content = line.substring(1).trim();
        if (content.startsWith('//') ||
            content.startsWith('///') ||
            content.startsWith('/*') ||
            content.startsWith('*') ||
            content.endsWith('*/')) {
          hasCommentContent = true;
        }
      }
    }

    return hasCommentContent
        ? ImpactCategory.commentOnly
        : ImpactCategory.whitespaceOnly;
  }
}

/// A package that has real impact but no matching changeset intent.
class MissingIntentFailure {
  const MissingIntentFailure({
    required this.packageName,
    required this.remediation,
  });

  /// Package name that needs a changeset.
  final String packageName;

  /// Human-readable remediation instructions.
  final String remediation;
}

/// A changeset intent that has no corresponding real package impact.
class UnusedIntentWarning {
  const UnusedIntentWarning({required this.packageName, required this.reason});

  /// Package name with unused intent.
  final String packageName;

  /// Explanation of why the intent is unused.
  final String reason;
}

/// Result of reconciling real impact with changeset intent.
///
/// Release candidates are `intent ∩ realImpact`.
/// Missing intent failures are `realImpact - intent`.
/// Unused intent warnings are `intent - realImpact`.
class ReconciliationResult {
  const ReconciliationResult({
    required this.releaseCandidates,
    required this.missingIntentFailures,
    required this.unusedIntentWarnings,
  });

  /// Packages with both intent and real impact (in publish order).
  final List<ReleaseCandidate> releaseCandidates;

  /// Packages with real impact but no changeset (CI must fail).
  final List<MissingIntentFailure> missingIntentFailures;

  /// Packages with changeset but no real impact (surfaced, excluded).
  final List<UnusedIntentWarning> unusedIntentWarnings;

  /// Whether any failures exist (CI should fail when true).
  bool get hasFailures => missingIntentFailures.isNotEmpty;
}

/// Reconciles real package impact with changeset intent.
///
/// Produces three outputs:
/// - Release candidates: packages with both intent and real impact.
/// - Missing intent failures: packages with real impact but no changeset.
/// - Unused intent warnings: changesets with no real package impact.
class ReleaseReconciler {
  /// Reconciles changed files against changesets.
  ///
  /// Uses [ImpactClassifier] for content-aware impact detection and
  /// compares it against changeset-declared intent.
  static ReconciliationResult reconcile({
    required List<ChangedFile> changedFiles,
    required List<Changeset> changesets,
  }) {
    // Step 1: Classify real impact.
    final classification = ImpactClassifier.classify(changedFiles);
    final impactedPackages = classification.impactedPackages.toSet();

    // Step 2: Collect changeset intent.
    final intentPackages = <String, BumpLevel>{};
    final intentNotes = <String, List<String>>{};
    for (final cs in changesets) {
      for (final entry in cs.bumps.entries) {
        final pkg = entry.key;
        final bump = entry.value;
        final existing = intentPackages[pkg];
        intentPackages[pkg] = existing == null
            ? bump
            : BumpLevel.max([existing, bump]);
        intentNotes.putIfAbsent(pkg, () => <String>[]);
        if (cs.notes.isNotEmpty) {
          intentNotes[pkg]!.add(cs.notes);
        }
      }
    }

    // Step 3: Compute sets.
    // intent ∩ realImpact → release candidates
    final candidateNames =
        impactedPackages.where(intentPackages.containsKey).toList()
          ..sort((a, b) {
            if (a == 'explicit_outcome') return -1;
            if (b == 'explicit_outcome') return 1;
            return a.compareTo(b);
          });

    // realImpact - intent → missing intent failures
    final missingIntentNames =
        impactedPackages
            .where((pkg) => !intentPackages.containsKey(pkg))
            .toList()
          ..sort();

    // intent - realImpact → unused intent warnings
    final unusedIntentNames =
        intentPackages.keys
            .where((pkg) => !impactedPackages.contains(pkg))
            .toList()
          ..sort();

    // Build candidates.
    final candidates = candidateNames
        .map(
          (name) => ReleaseCandidate(
            packageName: name,
            bump: intentPackages[name]!,
            notes: (intentNotes[name] ?? []).join('\n'),
            impactProof:
                classification.packageImpacts[name]?.impactedFiles ?? const [],
          ),
        )
        .toList();

    // Build failures.
    final failures = missingIntentNames
        .map(
          (name) => MissingIntentFailure(
            packageName: name,
            remediation: _buildRemediation(name),
          ),
        )
        .toList();

    // Build warnings.
    final warnings = unusedIntentNames
        .map(
          (name) => UnusedIntentWarning(
            packageName: name,
            reason:
                'Changeset declares intent for $name but '
                'no real package impact was detected. '
                'The changeset will be excluded from release candidates.',
          ),
        )
        .toList();

    return ReconciliationResult(
      releaseCandidates: candidates,
      missingIntentFailures: failures,
      unusedIntentWarnings: warnings,
    );
  }

  /// Builds a remediation message for a package missing a changeset.
  static String _buildRemediation(String packageName) {
    return 'Missing changeset for: $packageName\n'
        '\n'
        'Create a changeset with:\n'
        '  dart run tool/release_changeset.dart init '
        '--package=$packageName --bump=patch '
        '--summary="Describe your change"\n'
        '\n'
        'See .changesets/README.md for format details.';
  }
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
      final msg =
          'Failed to fetch pub.dev metadata for '
          'explicit_outcome: $e. Failing closed — cannot '
          'verify dependency availability.';
      return PreflightResult(isSatisfied: false, errors: [msg]);
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
        final msg =
            'No published version of explicit_outcome '
            'satisfies constraint ^$requiredVersion. '
            'explicit_outcome must be published before explicit.';
        return PreflightResult(isSatisfied: false, errors: [msg]);
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
