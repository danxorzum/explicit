/// Release planner: parses changesets, classifies publishable files,
/// computes release plans with bump precedence and dependency propagation.
///
/// This module is the boundary for release intent. Candidates come ONLY
/// from changesets — validation expansion does not imply publication.
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
          'Publish handoff: no publish in slice one — '
          'tag-triggered OIDC publishing is planned for slice two.';
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
        'Publish handoff: no publish in slice one — '
        'tag-triggered OIDC publishing is planned for slice two.',
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
      'publishHandoff': 'slice-one: no publish; slice-two: tag-triggered OIDC',
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
