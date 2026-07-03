/// Metadata about a publishable package.
class PackageInfo {
  const PackageInfo({
    required this.name,
    required this.version,
    required this.path,
  });

  /// Parses package info from pubspec.yaml content.
  ///
  /// Uses simple line-based parsing to avoid YAML dependency.
  /// Throws [FormatException] if name or version is missing.
  factory PackageInfo.fromPubspecContent(String content, String packagePath) {
    String? name;
    String? version;

    for (final line in content.split('\n')) {
      final trimmed = line.trim();

      // Match top-level "name:" field
      if (trimmed.startsWith('name:') && !trimmed.startsWith('name: ')) {
        // Skip nested fields
        continue;
      }
      if (line.startsWith('name:')) {
        name = line.substring('name:'.length).trim();
      }

      // Match top-level "version:" field
      if (line.startsWith('version:')) {
        version = line.substring('version:'.length).trim();
      }
    }

    if (name == null || name.isEmpty) {
      throw FormatException(
        'Missing "name" field in pubspec at $packagePath',
      );
    }
    if (version == null || version.isEmpty) {
      throw FormatException(
        'Missing "version" field in pubspec at $packagePath',
      );
    }

    return PackageInfo(name: name, version: version, path: packagePath);
  }

  /// Package name (e.g., "explicit_outcome").
  final String name;

  /// Package version (e.g., "0.0.1").
  final String version;

  /// Relative path to the package directory (e.g., "packages/explicit_outcome").
  final String path;

  /// Returns packages in correct publish order.
  ///
  /// explicit_outcome MUST be published before explicit because
  /// explicit depends on explicit_outcome.
  static List<PackageInfo> publishOrder(List<PackageInfo> packages) {
    return List<PackageInfo>.from(packages)
      ..sort((a, b) {
        // explicit_outcome always first
        if (a.name == 'explicit_outcome') return -1;
        if (b.name == 'explicit_outcome') return 1;
        return a.name.compareTo(b.name);
      });
  }

  /// Returns the simulation log line for this package.
  ///
  /// Format: "SIMULATION ONLY: would publish {name} {version} from {path}"
  String simulationLine() =>
      'SIMULATION ONLY: would publish $name $version from $path';

  /// Returns the safe dry-run command for this package.
  String dryRunCommand() => 'dart pub publish --dry-run';
}
