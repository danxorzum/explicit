import 'package:test/test.dart';

import '../src/affected_detector.dart';

void main() {
  group('AffectedDetector', () {
    group('detectAffectedPackages', () {
      test('returns explicit_outcome and explicit '
          'when explicit_outcome files change', () {
        final changedFiles = [
          'packages/explicit_outcome/lib/src/option/opt.dart',
        ];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('returns only explicit when only explicit files change', () {
        final changedFiles = ['packages/explicit/lib/src/some_file.dart'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, contains('explicit'));
        expect(affected, isNot(contains('explicit_outcome')));
      });

      test('returns all packages when root pubspec.yaml changes', () {
        final changedFiles = ['pubspec.yaml'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('returns all packages when pubspec.lock changes', () {
        final changedFiles = ['pubspec.lock'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('returns all packages when analysis_options.yaml changes', () {
        final changedFiles = ['analysis_options.yaml'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('returns all packages when workflow files change', () {
        final changedFiles = ['.github/workflows/ci.yaml'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('returns all packages when tool scripts change', () {
        final changedFiles = ['tool/quality_gate.dart'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('returns all packages when package pubspec changes', () {
        final changedFiles = ['packages/explicit/pubspec.yaml'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('returns all packages for unknown paths', () {
        final changedFiles = ['some/random/file.txt'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('returns empty list when no files changed', () {
        final changedFiles = <String>[];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, isEmpty);
      });

      test('handles multiple package changes correctly', () {
        final changedFiles = [
          'packages/explicit_outcome/lib/src/option/opt.dart',
          'packages/explicit/lib/src/some_file.dart',
        ];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('root README change triggers validate-all', () {
        final changedFiles = ['README.md'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('package-level non-pubspec file affects only that package', () {
        final changedFiles = ['packages/explicit/README.md'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, contains('explicit'));
        expect(affected, isNot(contains('explicit_outcome')));
      });

      test('explicit_outcome test file change expands to explicit', () {
        final changedFiles = [
          'packages/explicit_outcome/test/src/option/opt_test.dart',
        ];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('.gitignore at root triggers validate-all', () {
        final changedFiles = ['.gitignore'];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });

      test('mixed validate-all and package-only triggers validate all', () {
        final changedFiles = [
          'packages/explicit/lib/src/utils.dart',
          'pubspec.lock',
        ];
        final affected = AffectedDetector.detectAffectedPackages(changedFiles);
        expect(affected, containsAll(['explicit_outcome', 'explicit']));
      });
    });

    group('shouldValidateAll', () {
      test('returns true for root pubspec.yaml', () {
        expect(AffectedDetector.shouldValidateAll(['pubspec.yaml']), isTrue);
      });

      test('returns true for pubspec.lock', () {
        expect(AffectedDetector.shouldValidateAll(['pubspec.lock']), isTrue);
      });

      test('returns true for melos.yaml', () {
        expect(AffectedDetector.shouldValidateAll(['melos.yaml']), isTrue);
      });

      test('returns true for root analysis_options.yaml', () {
        expect(
          AffectedDetector.shouldValidateAll(['analysis_options.yaml']),
          isTrue,
        );
      });

      test('returns true for workflow files', () {
        expect(
          AffectedDetector.shouldValidateAll(['.github/workflows/main.yaml']),
          isTrue,
        );
      });

      test('returns true for tool directory', () {
        expect(
          AffectedDetector.shouldValidateAll(['tool/some_script.dart']),
          isTrue,
        );
      });

      test('returns true for package pubspec.yaml', () {
        expect(
          AffectedDetector.shouldValidateAll([
            'packages/explicit_outcome/pubspec.yaml',
          ]),
          isTrue,
        );
      });

      test('returns false for package source files only', () {
        expect(
          AffectedDetector.shouldValidateAll([
            'packages/explicit/lib/src/utils.dart',
          ]),
          isFalse,
        );
      });

      test('returns false for package test files only', () {
        expect(
          AffectedDetector.shouldValidateAll([
            'packages/explicit/test/src/some_test.dart',
          ]),
          isFalse,
        );
      });
    });
  });
}
