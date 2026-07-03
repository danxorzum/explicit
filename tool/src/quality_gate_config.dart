/// The mode in which the quality gate runs.
enum GateMode {
  /// Pull request / branch mode: validate affected packages only.
  pr,

  /// Validate all packages (main branch, publish simulation).
  all,

  /// Pre-push hook mode: validate affected packages.
  prePush,
}

/// Parsed configuration for the quality gate CLI.
class QualityGateConfig {
  const QualityGateConfig({
    required this.mode,
    this.base,
    this.head,
    this.listOnly = false,
  });

  /// Parses command-line arguments into a [QualityGateConfig].
  ///
  /// Supported flags:
  /// - `--mode=pr|all|pre-push` (default: all)
  /// - `--base=<sha>` (required for pr mode)
  /// - `--head=<sha>` (required for pr mode)
  /// - `--list-only` (print affected packages and exit)
  factory QualityGateConfig.parse(List<String> args) {
    GateMode? mode;
    String? base;
    String? head;
    var listOnly = false;

    for (final arg in args) {
      if (arg.startsWith('--mode=')) {
        final value = arg.substring('--mode='.length);
        mode = _parseMode(value);
      } else if (arg.startsWith('--base=')) {
        base = arg.substring('--base='.length);
      } else if (arg.startsWith('--head=')) {
        head = arg.substring('--head='.length);
      } else if (arg == '--list-only') {
        listOnly = true;
      }
    }

    // Default to 'all' mode when no mode specified (safest default)
    mode ??= GateMode.all;

    if (mode == GateMode.pr && (base == null || head == null)) {
      throw const FormatException(
        'pr mode requires both --base=<sha> and --head=<sha>',
      );
    }

    return QualityGateConfig(
      mode: mode,
      base: base,
      head: head,
      listOnly: listOnly,
    );
  }

  /// The validation mode.
  final GateMode mode;

  /// Base commit SHA for diff (pr mode only).
  final String? base;

  /// Head commit SHA for diff (pr mode only).
  final String? head;

  /// When true, print affected packages and exit without running gates.
  final bool listOnly;

  /// Whether this mode requires git diff computation.
  bool get requiresGitDiff => mode == GateMode.pr;

  static GateMode _parseMode(String value) {
    switch (value) {
      case 'pr':
        return GateMode.pr;
      case 'all':
        return GateMode.all;
      case 'pre-push':
        return GateMode.prePush;
      default:
        throw FormatException(
          'Invalid mode: $value. Use pr, all, or pre-push.',
        );
    }
  }
}
