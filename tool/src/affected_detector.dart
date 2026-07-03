/// Detects which packages are affected by a set of changed files.
///
/// Implements dependency expansion: changes to `explicit_outcome` automatically
/// include `explicit` since it depends on `explicit_outcome`.
class AffectedDetector {
  /// All publishable packages in the workspace.
  static const List<String> allPackages = ['explicit_outcome', 'explicit'];

  /// Detects which packages are affected by [changedFiles].
  ///
  /// Returns a list of package names that need validation.
  /// If [shouldValidateAll] returns true, returns all packages.
  /// If `explicit_outcome` is affected, expands to include `explicit`.
  static List<String> detectAffectedPackages(List<String> changedFiles) {
    if (changedFiles.isEmpty) {
      return <String>[];
    }

    if (shouldValidateAll(changedFiles)) {
      return List<String>.from(allPackages);
    }

    final affected = <String>{};

    for (final file in changedFiles) {
      if (file.startsWith('packages/explicit_outcome/')) {
        affected
          ..add('explicit_outcome')
          // Dependency expansion: explicit depends on explicit_outcome
          ..add('explicit');
      } else if (file.startsWith('packages/explicit/')) {
        affected.add('explicit');
      } else {
        // Unknown path - validate all
        return List<String>.from(allPackages);
      }
    }

    return affected.toList()..sort();
  }

  /// Returns true if any changed file triggers validate-all behavior.
  ///
  /// Validate-all triggers:
  /// - Root pubspec.yaml or pubspec.lock
  /// - melos.yaml or root melos config
  /// - Root analysis_options.yaml
  /// - .github/workflows/**
  /// - tool/**
  /// - packages/*/pubspec.yaml
  static bool shouldValidateAll(List<String> changedFiles) {
    for (final file in changedFiles) {
      if (_isValidateAllTrigger(file)) {
        return true;
      }
    }
    return false;
  }

  static bool _isValidateAllTrigger(String file) {
    // Root config files
    if (file == 'pubspec.yaml' ||
        file == 'pubspec.lock' ||
        file == 'melos.yaml' ||
        file == 'analysis_options.yaml') {
      return true;
    }

    // GitHub workflows
    if (file.startsWith('.github/workflows/')) {
      return true;
    }

    // Tool scripts
    if (file.startsWith('tool/')) {
      return true;
    }

    // Package pubspecs
    if (file.startsWith('packages/') && file.endsWith('pubspec.yaml')) {
      return true;
    }

    return false;
  }
}
