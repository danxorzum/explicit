/// A single safety rule violation found in source content.
class SafetyViolation {
  const SafetyViolation({
    required this.rule,
    required this.line,
    required this.matchedText,
  });

  /// The rule that was violated (e.g., "no-force-publish").
  final String rule;

  /// Line number where the violation was found (1-indexed).
  final int line;

  /// The text that matched the forbidden pattern.
  final String matchedText;

  @override
  String toString() => 'Line $line: [$rule] "$matchedText"';
}

/// Result of a safety assertion pass.
class SafetyResult {
  const SafetyResult({required this.violations});

  /// All violations found. Empty means safe.
  final List<SafetyViolation> violations;

  /// True when no violations were found.
  bool get isSafe => violations.isEmpty;
}

/// Static safety assertions for publish-related code.
///
/// Workflow/job-aware allowlist.
/// - Credentials (`PUB_TOKEN`, `PUB_CREDENTIALS`) are ALWAYS forbidden.
/// - `id-token: write` and `dart pub publish --force` are allowed ONLY inside
///   the approved publish workflow job: `publish.yaml::publish_package`.
/// - All other workflows/jobs deny OIDC, publish commands, and credentials.
class PublishSafety {
  /// Rule name: no `dart pub publish --force` outside approved publish jobs.
  static const String noForcePublishRule = 'no-force-publish';

  /// Rule name: no `melos publish --no-dry-run`.
  static const String noMelosNoDryRunRule = 'no-melos-no-dry-run';

  /// Rule name: no plain `dart pub publish` outside approved jobs.
  static const String noPlainPublishRule = 'no-plain-publish';

  /// Rule name: no OIDC `id-token: write` permission.
  static const String noOidcRule = 'no-oidc-id-token';

  /// Rule name: no publish token environment variables.
  static const String noTokenEnvRule = 'no-publish-token-env';

  /// Approved workflow + job pairs that may use OIDC and publish commands.
  static const List<String> _allowedOidcJobs = [
    'publish.yaml::publish_package',
  ];

  /// Asserts that [content] does not contain forbidden publish patterns.
  ///
  /// When [workflow] and [job] are provided, the check is context-aware:
  /// OIDC and `dart pub publish` are allowed only in the approved
  /// publish workflow jobs. Credentials remain always forbidden.
  ///
  /// Returns a [SafetyResult] with any violations found.
  /// An empty violations list means the content is safe.
  static SafetyResult assertSafeContent(
    String content, {
    String? workflow,
    String? job,
  }) {
    final violations = <SafetyViolation>[];
    final lines = content.split('\n');

    final isApprovedPublishJob =
        workflow != null &&
        job != null &&
        _allowedOidcJobs.contains('$workflow::$job');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      // Check for `dart pub publish --force` — allowed only in approved
      // publish jobs because pub.dev trusted publishing requires it in CI to
      // skip the interactive confirmation prompt.
      if (_containsForcePublish(line) && !isApprovedPublishJob) {
        violations.add(
          SafetyViolation(
            rule: noForcePublishRule,
            line: lineNum,
            matchedText: line.trim(),
          ),
        );
      }

      // Check for `melos publish --no-dry-run` — always forbidden.
      if (_containsMelosNoDryRun(line)) {
        violations.add(
          SafetyViolation(
            rule: noMelosNoDryRunRule,
            line: lineNum,
            matchedText: line.trim(),
          ),
        );
      }

      // Check for plain `dart pub publish` — allowed only in approved
      // publish jobs. This catches `run: dart pub publish` without
      // --dry-run or --force in non-approved workflows/jobs.
      if (_containsPlainPublish(line) && !isApprovedPublishJob) {
        violations.add(
          SafetyViolation(
            rule: noPlainPublishRule,
            line: lineNum,
            matchedText: line.trim(),
          ),
        );
      }

      // Check for OIDC id-token permission — allowed only in approved jobs.
      if (_containsOidcPermission(line) && !isApprovedPublishJob) {
        violations.add(
          SafetyViolation(
            rule: noOidcRule,
            line: lineNum,
            matchedText: line.trim(),
          ),
        );
      }

      // Check for publish token env vars — always forbidden.
      if (_containsTokenEnvVar(line)) {
        violations.add(
          SafetyViolation(
            rule: noTokenEnvRule,
            line: lineNum,
            matchedText: line.trim(),
          ),
        );
      }
    }

    return SafetyResult(violations: violations);
  }

  /// Checks for `publish --force` or `publish', '--force'` patterns.
  static bool _containsForcePublish(String line) {
    // Match both shell and Dart list syntax
    return line.contains('publish --force') ||
        line.contains("publish', '--force") ||
        line.contains('publish", "--force');
  }

  /// Checks for `melos publish --no-dry-run`.
  static bool _containsMelosNoDryRun(String line) {
    return line.contains('--no-dry-run');
  }

  /// Checks for plain `dart pub publish` without safety flags.
  ///
  /// Detects `dart pub publish` that is NOT followed by `--dry-run`,
  /// `-n`, or `--force`. The `--force` variant is caught by
  /// [_containsForcePublish] separately.
  static bool _containsPlainPublish(String line) {
    final trimmed = line.trim();
    // Match "dart pub publish" as a command (shell `run:` or standalone).
    if (!trimmed.contains('dart pub publish')) return false;

    // Exclude dry-run and force variants (handled by other rules).
    if (trimmed.contains('--dry-run') ||
        trimmed.contains('-n') ||
        trimmed.contains('--force') ||
        trimmed.contains("publish', '--force") ||
        trimmed.contains('publish", "--force')) {
      return false;
    }

    // Exclude SIMULATION ONLY strings.
    if (trimmed.contains('SIMULATION ONLY')) return false;

    return true;
  }

  /// Checks for OIDC `id-token: write` permission.
  static bool _containsOidcPermission(String line) {
    return line.contains('id-token: write') || line.contains('id-token:write');
  }

  /// Checks for publish token environment variable references.
  static bool _containsTokenEnvVar(String line) {
    return line.contains('PUB_TOKEN') || line.contains('PUB_CREDENTIALS');
  }
}
