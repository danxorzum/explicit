import 'package:test/test.dart';

import '../src/dart36_fixture.dart';

void main() {
  group('Dart36Fixture', () {
    group('generateConsumerPubspec', () {
      test('generates pubspec with SDK >=3.6.0 <4.0.0', () {
        final pubspec = generateConsumerPubspec(
          explicitPath: '/tmp/repo/packages/explicit',
          outcomePath: '/tmp/repo/packages/explicit_outcome',
        );

        expect(pubspec, contains('sdk: ">=3.6.0 <4.0.0"'));
      });

      test('references both packages via path dependencies', () {
        final pubspec = generateConsumerPubspec(
          explicitPath: '/repo/packages/explicit',
          outcomePath: '/repo/packages/explicit_outcome',
        );

        expect(pubspec, contains('explicit:'));
        expect(pubspec, contains('path: /repo/packages/explicit'));
        expect(pubspec, contains('explicit_outcome:'));
        expect(pubspec, contains('path: /repo/packages/explicit_outcome'));
      });

      test('includes test and very_good_analysis dev dependencies', () {
        final pubspec = generateConsumerPubspec(
          explicitPath: '/a/packages/explicit',
          outcomePath: '/a/packages/explicit_outcome',
        );

        expect(pubspec, contains('dev_dependencies:'));
        expect(pubspec, contains('test:'));
        expect(pubspec, contains('very_good_analysis: ^7.0.0'));
      });

      test('does not declare resolution workspace', () {
        final pubspec = generateConsumerPubspec(
          explicitPath: '/x/packages/explicit',
          outcomePath: '/x/packages/explicit_outcome',
        );

        expect(pubspec, isNot(contains('resolution: workspace')));
        expect(pubspec, isNot(contains('workspace:')));
      });

      test('overrides explicit_outcome to local path after version guard', () {
        final pubspec = generateConsumerPubspec(
          explicitPath: '/x/packages/explicit',
          outcomePath: '/x/packages/explicit_outcome',
        );

        expect(pubspec, contains('dependency_overrides:'));
        expect(pubspec, contains('explicit_outcome:'));
        expect(pubspec, contains('path: /x/packages/explicit_outcome'));
      });

      test('uses publish_to none for consumer fixture', () {
        final pubspec = generateConsumerPubspec(
          explicitPath: '/p/packages/explicit',
          outcomePath: '/p/packages/explicit_outcome',
        );

        expect(pubspec, contains('publish_to: none'));
      });

      test('handles relative paths correctly', () {
        final pubspec = generateConsumerPubspec(
          explicitPath: '../packages/explicit',
          outcomePath: '../packages/explicit_outcome',
        );

        expect(pubspec, contains('path: ../packages/explicit'));
        expect(pubspec, contains('path: ../packages/explicit_outcome'));
      });

      test('declares mocktail-compatible test constraint', () {
        final pubspec = generateConsumerPubspec(
          explicitPath: '/a/packages/explicit',
          outcomePath: '/a/packages/explicit_outcome',
        );

        // test >=1.25.0 <2.0.0 allows Dart 3.6 resolution (max 1.26.3)
        expect(pubspec, contains('test: ">=1.25.0 <2.0.0"'));
      });
    });

    group('validateExplicitOutcomeConstraint', () {
      test('accepts coordinated explicit_outcome release constraint', () {
        expect(
          () => validateExplicitOutcomeConstraint(
            explicitPubspec: '''
name: explicit
version: 0.0.2
dependencies:
  explicit_outcome: ^0.0.2
''',
            outcomePubspec: '''
name: explicit_outcome
version: 0.0.2
''',
          ),
          returnsNormally,
        );
      });

      test('rejects stale explicit_outcome release constraint', () {
        expect(
          () => validateExplicitOutcomeConstraint(
            explicitPubspec: '''
name: explicit
version: 0.0.2
dependencies:
  explicit_outcome: ^0.0.1
''',
            outcomePubspec: '''
name: explicit_outcome
version: 0.0.2
''',
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('explicit_outcome ^0.0.2'),
            ),
          ),
        );
      });
    });

    group('generateAnalysisOptions', () {
      test('includes very_good_analysis options', () {
        final options = generateAnalysisOptions();
        expect(
          options,
          contains('include: package:very_good_analysis/analysis_options.yaml'),
        );
      });
    });

    group('generateSmokeTest', () {
      test('imports explicit package (re-exports outcome types)', () {
        final smoke = generateSmokeTest();

        expect(smoke, contains("import 'package:explicit/explicit.dart'"));
      });

      test('exercises Result and Option types', () {
        final smoke = generateSmokeTest();

        expect(smoke, contains('Ok'));
        expect(smoke, contains('Err'));
        expect(smoke, contains('Val'));
        expect(smoke, contains('Nil'));
      });

      test('contains a main function with assertions', () {
        final smoke = generateSmokeTest();

        expect(smoke, contains('void main()'));
        expect(smoke, contains('assert'));
      });
    });
  });
}
