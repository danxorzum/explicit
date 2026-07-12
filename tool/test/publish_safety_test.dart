import 'package:test/test.dart';

import '../src/publish_safety.dart';

void main() {
  group('PublishSafety', () {
    group('assertSafeContent (default — no workflow/job context)', () {
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

      test('detects OIDC permission patterns (default context)', () {
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

    group('assertSafeContent with workflow/job allowlist', () {
      test(
        'allows id-token: write in publish.yaml::publish_package',
        () {
          const content = '''
permissions:
  id-token: write
  contents: read
''';
          final result = PublishSafety.assertSafeContent(
            content,
            workflow: 'publish.yaml',
            job: 'publish_package',
          );
          expect(result.isSafe, isTrue);
        },
      );

      test('allows dart pub publish in publish.yaml::publish_package', () {
        const content = '''
run: dart pub publish
''';
        final result = PublishSafety.assertSafeContent(
          content,
          workflow: 'publish.yaml',
          job: 'publish_package',
        );
        // dart pub publish (without --force) is allowed in the publish job.
        expect(
          result.violations.where(
            (v) => v.rule == PublishSafety.noForcePublishRule,
          ),
          isEmpty,
        );
      });

      test('denies id-token: write in publish.yaml::validate_release', () {
        const content = '''
permissions:
  id-token: write
''';
        final result = PublishSafety.assertSafeContent(
          content,
          workflow: 'publish.yaml',
          job: 'validate_release',
        );
        expect(result.isSafe, isFalse);
        expect(
          result.violations.any((v) => v.rule == PublishSafety.noOidcRule),
          isTrue,
        );
      });

      test('denies id-token: write in release_version_pr.yaml', () {
        const content = '''
permissions:
  id-token: write
''';
        final result = PublishSafety.assertSafeContent(
          content,
          workflow: 'release_version_pr.yaml',
          job: 'release_version_pr',
        );
        expect(result.isSafe, isFalse);
      });

      test('denies id-token: write in ci.yaml', () {
        const content = '''
permissions:
  id-token: write
''';
        final result = PublishSafety.assertSafeContent(
          content,
          workflow: 'ci.yaml',
          job: 'quality_gate',
        );
        expect(result.isSafe, isFalse);
      });

      test('denies id-token: write in publish_simulation.yaml', () {
        const content = '''
permissions:
  id-token: write
''';
        final result = PublishSafety.assertSafeContent(
          content,
          workflow: 'publish_simulation.yaml',
          job: 'publish_simulation',
        );
        expect(result.isSafe, isFalse);
      });

      test('denies id-token: write in unknown workflow', () {
        const content = '''
permissions:
  id-token: write
''';
        final result = PublishSafety.assertSafeContent(
          content,
          workflow: 'custom_deploy.yaml',
          job: 'deploy',
        );
        expect(result.isSafe, isFalse);
      });

      test(
        'credentials (PUB_TOKEN) forbidden everywhere including '
        'publish jobs',
        () {
          const content = '''
env:
  PUB_TOKEN: secret
''';
          final resultPatch = PublishSafety.assertSafeContent(
            content,
            workflow: 'publish.yaml',
            job: 'publish_package',
          );
          expect(resultPatch.isSafe, isFalse);
          expect(
            resultPatch.violations.any(
              (v) => v.rule == PublishSafety.noTokenEnvRule,
            ),
            isTrue,
          );
        },
      );

      test(
        'credentials (PUB_CREDENTIALS) forbidden in publish jobs',
        () {
          const content = '''
env:
  PUB_CREDENTIALS: secret
''';
          final result = PublishSafety.assertSafeContent(
            content,
            workflow: 'publish.yaml',
            job: 'publish_package',
          );
          expect(result.isSafe, isFalse);
        },
      );

      test(
        'allows dart pub publish --force in publish.yaml::publish_package',
        () {
          const content = '''
run: dart pub publish --force
''';
          final result = PublishSafety.assertSafeContent(
            content,
            workflow: 'publish.yaml',
            job: 'publish_package',
          );
          expect(
            result.violations.where(
              (v) => v.rule == PublishSafety.noForcePublishRule,
            ),
            isEmpty,
            reason:
                '--force is required for non-interactive trusted publishing '
                'and allowed only in approved publish jobs.',
          );
        },
      );

      test('denies dart pub publish --force outside approved publish jobs', () {
        const content = '''
run: dart pub publish --force
''';
        final result = PublishSafety.assertSafeContent(
          content,
          workflow: 'publish.yaml',
          job: 'validate_release',
        );
        expect(result.isSafe, isFalse);
        expect(
          result.violations.any(
            (v) => v.rule == PublishSafety.noForcePublishRule,
          ),
          isTrue,
        );
      });

      // Regression: plain `dart pub publish` (no --force, no --dry-run)
      // must be denied in non-approved workflows/jobs.
      test(
        'denies plain dart pub publish in non-approved job '
        '(ci.yaml::quality_gate)',
        () {
          const content = '''
      - name: Publish
        run: dart pub publish
''';
          final result = PublishSafety.assertSafeContent(
            content,
            workflow: 'ci.yaml',
            job: 'quality_gate',
          );
          expect(result.isSafe, isFalse);
          expect(
            result.violations.any(
              (v) => v.rule == PublishSafety.noPlainPublishRule,
            ),
            isTrue,
            reason: 'Plain dart pub publish must be denied in ci.yaml',
          );
        },
      );

      test(
        'denies plain dart pub publish in release_version_pr.yaml',
        () {
          const content = '''
      - name: Publish
        run: dart pub publish
''';
          final result = PublishSafety.assertSafeContent(
            content,
            workflow: 'release_version_pr.yaml',
            job: 'release_version_pr',
          );
          expect(result.isSafe, isFalse);
          expect(
            result.violations.any(
              (v) => v.rule == PublishSafety.noPlainPublishRule,
            ),
            isTrue,
          );
        },
      );

      test(
        'denies plain dart pub publish in publish.yaml::validate_release',
        () {
          const content = '''
      - name: Publish
        run: dart pub publish
''';
          final result = PublishSafety.assertSafeContent(
            content,
            workflow: 'publish.yaml',
            job: 'validate_release',
          );
          expect(result.isSafe, isFalse);
          expect(
            result.violations.any(
              (v) => v.rule == PublishSafety.noPlainPublishRule,
            ),
            isTrue,
          );
        },
      );

      test(
        'denies plain dart pub publish with no workflow/job context',
        () {
          const content = '''
run: dart pub publish
''';
          final result = PublishSafety.assertSafeContent(content);
          expect(result.isSafe, isFalse);
          expect(
            result.violations.any(
              (v) => v.rule == PublishSafety.noPlainPublishRule,
            ),
            isTrue,
          );
        },
      );

      test(
        'denies plain dart pub publish in unknown workflow',
        () {
          const content = '''
run: dart pub publish
''';
          final result = PublishSafety.assertSafeContent(
            content,
            workflow: 'custom_deploy.yaml',
            job: 'deploy',
          );
          expect(result.isSafe, isFalse);
          expect(
            result.violations.any(
              (v) => v.rule == PublishSafety.noPlainPublishRule,
            ),
            isTrue,
          );
        },
      );

      test(
        'allows plain dart pub publish in publish.yaml::publish_package',
        () {
          const content = '''
      - name: Publish package
        run: dart pub publish
''';
          final result = PublishSafety.assertSafeContent(
            content,
            workflow: 'publish.yaml',
            job: 'publish_package',
          );
          expect(
            result.violations.where(
              (v) => v.rule == PublishSafety.noPlainPublishRule,
            ),
            isEmpty,
            reason: 'Approved publish job may use plain dart pub publish',
          );
        },
      );

      test(
        'dry-run publish not flagged by plain publish rule',
        () {
          const content = '''
run: dart pub publish --dry-run
''';
          final result = PublishSafety.assertSafeContent(content);
          expect(
            result.violations.where(
              (v) => v.rule == PublishSafety.noPlainPublishRule,
            ),
            isEmpty,
            reason: 'Dry-run publish is safe and should not be flagged',
          );
        },
      );
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
        const result = SafetyResult(
          violations: [
            SafetyViolation(
              rule: 'test',
              line: 1,
              matchedText: 'bad',
            ),
          ],
        );
        expect(result.isSafe, isFalse);
      });
    });
  });
}
