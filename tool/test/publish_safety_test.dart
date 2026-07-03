import 'package:test/test.dart';

import '../src/publish_safety.dart';

void main() {
  group('PublishSafety', () {
    group('assertSafeContent', () {
      test('passes for safe content with no forbidden commands', () {
        const safeContent = '''
// This is a safe publish simulation
stdout.writeln('SIMULATION ONLY: would publish package');
stdout.writeln('dart pub publish --dry-run');
''';
        final result = PublishSafety.assertSafeContent(safeContent);
        expect(result.isSafe, isTrue);
        expect(result.violations, isEmpty);
      });

      test('detects dart pub publish --force', () {
        const unsafeContent = '''
// Running real publish
Process.run('dart', ['pub', 'publish', '--force']);
''';
        final result = PublishSafety.assertSafeContent(unsafeContent);
        expect(result.isSafe, isFalse);
        expect(result.violations, hasLength(1));
        expect(
          result.violations.first.rule,
          PublishSafety.noForcePublishRule,
        );
      });

      test('detects melos publish --no-dry-run', () {
        const unsafeContent = '''
melos publish --no-dry-run
''';
        final result = PublishSafety.assertSafeContent(unsafeContent);
        expect(result.isSafe, isFalse);
        expect(result.violations, hasLength(1));
        expect(
          result.violations.first.rule,
          PublishSafety.noMelosNoDryRunRule,
        );
      });

      test('detects PUB_TOKEN environment variable', () {
        const unsafeContent = '''
final token = Platform.environment['PUB_TOKEN'];
''';
        final result = PublishSafety.assertSafeContent(unsafeContent);
        expect(result.isSafe, isFalse);
        expect(result.violations, hasLength(1));
        expect(
          result.violations.first.rule,
          PublishSafety.noTokenEnvRule,
        );
      });

      test('detects PUB_CREDENTIALS environment variable', () {
        const unsafeContent = '''
final creds = Platform.environment['PUB_CREDENTIALS'];
''';
        final result = PublishSafety.assertSafeContent(unsafeContent);
        expect(result.isSafe, isFalse);
        expect(result.violations, hasLength(1));
        expect(
          result.violations.first.rule,
          PublishSafety.noTokenEnvRule,
        );
      });

      test('detects OIDC permission patterns', () {
        const unsafeContent = '''
permissions:
  id-token: write
''';
        final result = PublishSafety.assertSafeContent(unsafeContent);
        expect(result.isSafe, isFalse);
        expect(result.violations, hasLength(1));
        expect(
          result.violations.first.rule,
          PublishSafety.noOidcRule,
        );
      });

      test('detects multiple violations', () {
        const unsafeContent = '''
dart pub publish --force
melos publish --no-dry-run
PUB_TOKEN=secret
id-token: write
''';
        final result = PublishSafety.assertSafeContent(unsafeContent);
        expect(result.isSafe, isFalse);
        expect(result.violations, hasLength(4));
      });

      test('allows dry-run commands', () {
        const safeContent = '''
dart pub publish --dry-run
dart pub publish -n
''';
        final result = PublishSafety.assertSafeContent(safeContent);
        expect(result.isSafe, isTrue);
        expect(result.violations, isEmpty);
      });

      test('allows SIMULATION ONLY strings', () {
        const safeContent = '''
stdout.writeln('SIMULATION ONLY: would publish explicit_outcome 0.0.1');
''';
        final result = PublishSafety.assertSafeContent(safeContent);
        expect(result.isSafe, isTrue);
      });

      test('detects --force in different contexts', () {
        const unsafeContent = '''
Process.run('dart', ['pub', 'publish', '--force'], ...);
''';
        final result = PublishSafety.assertSafeContent(unsafeContent);
        expect(result.isSafe, isFalse);
      });

      test('passes for empty content', () {
        final result = PublishSafety.assertSafeContent('');
        expect(result.isSafe, isTrue);
        expect(result.violations, isEmpty);
      });
    });

    group('SafetyViolation', () {
      test('contains rule name and line number', () {
        const violation = SafetyViolation(
          rule: 'no-force-publish',
          line: 42,
          matchedText: 'dart pub publish --force',
        );
        expect(violation.rule, 'no-force-publish');
        expect(violation.line, 42);
        expect(violation.matchedText, 'dart pub publish --force');
      });
    });

    group('SafetyResult', () {
      test('isSafe is true when no violations', () {
        const result = SafetyResult(violations: []);
        expect(result.isSafe, isTrue);
      });

      test('isSafe is false when violations exist', () {
        const result = SafetyResult(violations: [
          SafetyViolation(
            rule: 'test',
            line: 1,
            matchedText: 'bad',
          ),
        ]);
        expect(result.isSafe, isFalse);
      });
    });
  });
}
