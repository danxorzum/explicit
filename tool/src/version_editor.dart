/// Version editor: applies line-based version and changelog edits
/// to package pubspec.yaml and CHANGELOG.md files.
///
/// This module implements the version-pr boundary.
/// It updates versions, changelogs, and dependency caret ranges
/// based on a computed release plan.
library;

import 'dart:io';

import 'release_planner.dart';

/// Describes a single file edit made during version application.
class VersionEdit {
  const VersionEdit({
    required this.packageName,
    required this.filePath,
    required this.description,
  });

  /// Package name this edit belongs to.
  final String packageName;

  /// Relative path of the edited file.
  final String filePath;

  /// Human-readable description of the edit.
  final String description;
}

/// Applies version, changelog, and dependency edits to a workspace.
class VersionEditor {
  /// Computes the next semantic version from [currentVersion] and [bump].
  ///
  /// Throws [FormatException] if [currentVersion] is not a valid semver
  /// triple (major.minor.patch).
  static String computeNextVersion(String currentVersion, BumpLevel bump) {
    final parts = currentVersion.split('.');
    if (parts.length != 3) {
      throw FormatException(
        'Invalid version format: "$currentVersion". '
        'Expected major.minor.patch (e.g., 0.0.1).',
      );
    }

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);

    if (major == null || minor == null || patch == null) {
      throw FormatException(
        'Invalid version format: "$currentVersion". '
        'Each part must be a non-negative integer.',
      );
    }

    switch (bump) {
      case BumpLevel.patch:
        return '$major.$minor.${patch + 1}';
      case BumpLevel.minor:
        return '$major.${minor + 1}.0';
      case BumpLevel.major:
        return '${major + 1}.0.0';
    }
  }

  /// Replaces the `version:` line in [pubspecContent] with [newVersion].
  ///
  /// Returns the original content unchanged if the version already matches.
  static String bumpPubspecVersion(String pubspecContent, String newVersion) {
    final lines = pubspecContent.split('\n');
    final result = <String>[];

    for (final line in lines) {
      if (_isVersionLine(line)) {
        final currentVersion = _extractVersionValue(line);
        if (currentVersion == newVersion) {
          result.add(line);
        } else {
          result.add('version: $newVersion');
        }
      } else {
        result.add(line);
      }
    }

    return result.join('\n');
  }

  /// Prepends a changelog entry after the `# Changelog` title line.
  ///
  /// The entry includes a version heading with date and the provided notes.
  static String prependChangelogEntry(
    String changelogContent,
    String version,
    String notes,
    DateTime date,
  ) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final dateStr = '${date.year}-$month-$day';

    final lines = changelogContent.split('\n');
    final result = <String>[];
    var inserted = false;

    for (final line in lines) {
      result.add(line);
      if (!inserted && line.trimLeft().startsWith('# ')) {
        // Insert after the title line.
        result
          ..add('')
          ..add('## $version ($dateStr)')
          ..add('')
          ..add(notes);
        inserted = true;
      }
    }

    return result.join('\n');
  }

  /// Updates the caret range for [dependencyName] in [pubspecContent].
  ///
  /// Returns the original content unchanged if the dependency is not found.
  static String updateDependencyVersion(
    String pubspecContent,
    String dependencyName,
    String newVersion,
  ) {
    final lines = pubspecContent.split('\n');
    final result = <String>[];
    var found = false;

    for (final line in lines) {
      if (_isDependencyLine(line, dependencyName)) {
        final indent = line.substring(0, line.indexOf(dependencyName));
        result.add('$indent$dependencyName: ^$newVersion');
        found = true;
      } else {
        result.add(line);
      }
    }

    return found ? result.join('\n') : pubspecContent;
  }

  /// Applies all version edits from a [ReleasePlan] to the workspace
  /// at [workspaceRoot].
  ///
  /// Edits are applied in publish order (explicit_outcome first).
  /// When [changesetsDir] is provided, emits release provenance
  /// manifests to `<changesetsDir>/releases/<package>-<version>.json`.
  /// Returns a list of [VersionEdit] describing every change made.
  static List<VersionEdit> applyVersionEdits(
    ReleasePlan plan,
    String workspaceRoot, {
    String? changesetsDir,
  }) {
    if (plan.candidates.isEmpty) return [];

    final edits = <VersionEdit>[];
    final now = DateTime.now();

    // Build a map of package → new version for dependency propagation.
    // Also capture previous versions for provenance.
    final newVersions = <String, String>{};
    final previousVersions = <String, String>{};
    for (final candidate in plan.candidates) {
      final pubspecPath =
          '$workspaceRoot/packages/${candidate.packageName}/pubspec.yaml';
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) continue;

      final currentVersion = _readCurrentVersion(
        pubspecFile.readAsStringSync(),
      );
      if (currentVersion == null) continue;

      previousVersions[candidate.packageName] = currentVersion;
      newVersions[candidate.packageName] = computeNextVersion(
        currentVersion,
        candidate.bump,
      );
    }

    // Apply edits per candidate in publish order.
    for (final candidate in plan.candidates) {
      final pkgDir = '$workspaceRoot/packages/${candidate.packageName}';
      final pubspecPath = '$pkgDir/pubspec.yaml';
      final changelogPath = '$pkgDir/CHANGELOG.md';

      final newVersion = newVersions[candidate.packageName];
      if (newVersion == null) continue;

      // Bump pubspec version.
      final pubspecFile = File(pubspecPath);
      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        final updated = bumpPubspecVersion(content, newVersion);
        pubspecFile.writeAsStringSync(updated);
        edits.add(
          VersionEdit(
            packageName: candidate.packageName,
            filePath: 'packages/${candidate.packageName}/pubspec.yaml',
            description: 'Bumped version to $newVersion',
          ),
        );
      }

      // Prepend changelog entry.
      final changelogFile = File(changelogPath);
      if (changelogFile.existsSync()) {
        final content = changelogFile.readAsStringSync();
        final updated = prependChangelogEntry(
          content,
          newVersion,
          candidate.notes,
          now,
        );
        changelogFile.writeAsStringSync(updated);
        edits.add(
          VersionEdit(
            packageName: candidate.packageName,
            filePath: 'packages/${candidate.packageName}/CHANGELOG.md',
            description: 'Added changelog entry for $newVersion',
          ),
        );
      }
    }

    // Apply dependency propagation updates.
    for (final depUpdate in plan.dependencyUpdates) {
      final depNewVersion = newVersions[depUpdate.dependencyName];
      if (depNewVersion == null) continue;

      final pubspecPath =
          '$workspaceRoot/packages/${depUpdate.packageName}/pubspec.yaml';
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) continue;

      final content = pubspecFile.readAsStringSync();
      final updated = updateDependencyVersion(
        content,
        depUpdate.dependencyName,
        depNewVersion,
      );
      pubspecFile.writeAsStringSync(updated);
      edits.add(
        VersionEdit(
          packageName: depUpdate.packageName,
          filePath: 'packages/${depUpdate.packageName}/pubspec.yaml',
          description:
              'Updated ${depUpdate.dependencyName} '
              'dependency to ^$depNewVersion',
        ),
      );
    }

    // Emit release provenance manifests.
    if (changesetsDir != null) {
      _emitProvenance(plan, newVersions, previousVersions, changesetsDir);
      _removeConsumedChangesets(changesetsDir);
    }

    return edits;
  }

  /// Emits release provenance manifests for each candidate.
  ///
  /// Writes one JSON file per candidate to
  /// `<changesetsDir>/releases/<package>-<version>.json`.
  /// Hashes are deterministic and idempotent.
  static void _emitProvenance(
    ReleasePlan plan,
    Map<String, String> newVersions,
    Map<String, String> previousVersions,
    String changesetsDir,
  ) {
    final releasesDir = Directory('$changesetsDir/releases');
    if (releasesDir.existsSync()) {
      for (final file in releasesDir.listSync().whereType<File>()) {
        if (file.path.endsWith('.json')) {
          file.deleteSync();
        }
      }
    } else {
      releasesDir.createSync(recursive: true);
    }

    // Load changeset files to compute content hashes.
    final changesetFiles = _loadChangesetFiles(changesetsDir);

    for (final candidate in plan.candidates) {
      final version = newVersions[candidate.packageName];
      final previousVersion = previousVersions[candidate.packageName];
      if (version == null || previousVersion == null) continue;

      // Compute changeset hashes for this candidate's package.
      final changesetHashes = <String>[];
      final changesetContents = <String>[];
      for (final csFile in changesetFiles) {
        if (csFile.content.contains('${candidate.packageName}:')) {
          changesetContents.add(csFile.content);
          changesetHashes.add(
            ReleaseProvenance.computeContentHash(csFile.content),
          );
        }
      }

      // Compute changelog notes hash.
      final notesHash = ReleaseProvenance.computeContentHash(candidate.notes);

      // Compute intended tag.
      final tag = '${candidate.packageName}/v$version';

      final provenance = ReleaseProvenance(
        packageName: candidate.packageName,
        version: version,
        previousVersion: previousVersion,
        nextVersion: version,
        bump: candidate.bump.name,
        changesetHashes: changesetHashes,
        changesetContents: changesetContents,
        impactProof: candidate.impactProof,
        changelogNotesHash: notesHash,
        tag: tag,
      );

      final filename = '${candidate.packageName}-$version.json';
      File(
        '${releasesDir.path}/$filename',
      ).writeAsStringSync(provenance.toJson());
    }
  }

  /// Removes active changeset markdown after immutable provenance is written.
  static void _removeConsumedChangesets(String changesetsDir) {
    for (final changeset in _loadChangesetFiles(changesetsDir)) {
      final file = File(changeset.path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }

  /// Loads changeset markdown files from the changesets directory.
  static List<_ChangesetFile> _loadChangesetFiles(String changesetsDir) {
    final dir = Directory(changesetsDir);
    if (!dir.existsSync()) return [];

    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .where(
              (f) =>
                  f.path.split(RegExp(r'[/\\]')).last.toLowerCase() !=
                  'readme.md',
            )
            .map(
              (f) => _ChangesetFile(
                path: f.path,
                content: f.readAsStringSync(),
              ),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Returns true if the line is a top-level `version:` field.
  static bool _isVersionLine(String line) {
    return line.startsWith('version:') || line.startsWith('version :');
  }

  /// Extracts the version value from a `version: X.Y.Z` line.
  static String? _extractVersionValue(String line) {
    final colonIdx = line.indexOf(':');
    if (colonIdx == -1) return null;
    return line.substring(colonIdx + 1).trim();
  }

  /// Reads the current version from pubspec content.
  static String? _readCurrentVersion(String pubspecContent) {
    for (final line in pubspecContent.split('\n')) {
      if (_isVersionLine(line)) {
        return _extractVersionValue(line);
      }
    }
    return null;
  }

  /// Returns true if the line declares a dependency on [dependencyName].
  static bool _isDependencyLine(String line, String dependencyName) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('$dependencyName:') ||
        trimmed.startsWith('$dependencyName :');
  }
}

/// Internal helper: a changeset file path and its content.
class _ChangesetFile {
  const _ChangesetFile({required this.path, required this.content});

  final String path;
  final String content;
}
