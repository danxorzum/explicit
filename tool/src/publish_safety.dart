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
/// Verifies that tool scripts do NOT contain:
/// - Real publish commands (`dart pub publish --force`)
/// - Melos no-dry-run publish (`melos publish --no-dry-run`)
/// - OIDC permission grants (`id-token: write`)
/// - Publish token environment variables (`PUB_TOKEN`, `PUB_CREDENTIALS`)
class PublishSafety {
  /// Rule name: no `dart pub publish --force`.
  static const String noForcePublishRule = 'no-force-publish';

  /// Rule name: no `melos publish --no-dry-run`.
  static const String noMelosNoDryRunRule = 'no-melos-no-dry-run';

  /// Rule name: no OIDC `id-token: write` permission.
  static const String noOidcRule = 'no-oidc-id-token';

  /// Rule name: no publish token environment variables.
  static const String noTokenEnvRule = 'no-publish-token-env';

  /// Asserts that [content] does not contain forbidden publish patterns.
  ///
  /// Returns a [SafetyResult] with any violations found.
  /// An empty violations list means the content is safe.
  static SafetyResult assertSafeContent(String content) {
    final violations = <SafetyViolation>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      // Check for `dart pub publish --force`
      if (_containsForcePublish(line)) {
        violations.add(SafetyViolation(
          rule: noForcePublishRule,
          line: lineNum,
          matchedText: line.trim(),
        ));
      }

      // Check for `melos publish --no-dry-run`
      if (_containsMelosNoDryRun(line)) {
        violations.add(SafetyViolation(
          rule: noMelosNoDryRunRule,
          line: lineNum,
          matchedText: line.trim(),
        ));
      }

      // Check for OIDC id-token permission
      if (_containsOidcPermission(line)) {
        violations.add(SafetyViolation(
          rule: noOidcRule,
          line: lineNum,
          matchedText: line.trim(),
        ));
      }

      // Check for publish token env vars
      if (_containsTokenEnvVar(line)) {
        violations.add(SafetyViolation(
          rule: noTokenEnvRule,
          line: lineNum,
          matchedText: line.trim(),
        ));
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

  /// Checks for OIDC `id-token: write` permission.
  static bool _containsOidcPermission(String line) {
    return line.contains('id-token: write') ||
        line.contains('id-token:write');
  }

  /// Checks for publish token environment variable references.
  static bool _containsTokenEnvVar(String line) {
    return line.contains('PUB_TOKEN') || line.contains('PUB_CREDENTIALS');
  }
}
