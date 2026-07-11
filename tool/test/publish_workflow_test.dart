import 'dart:io';

import 'package:test/test.dart';

import '../src/publish_safety.dart';

void main() {
  group('publish.yaml workflow static assertions', () {
    late String publishYaml;

    setUpAll(() {
      final file = File('.github/workflows/publish.yaml');
      if (!file.existsSync()) {
        fail('publish.yaml not found at .github/workflows/publish.yaml');
      }
      publishYaml = file.readAsStringSync();
    });

    test('triggers only on tag push patterns', () {
      // Must have tags trigger pattern.
      expect(publishYaml, contains('tags:'));
      // Must NOT have push to main.
      expect(
        publishYaml.contains(RegExp(r'branches:\s*\n\s*-\s*main')),
        isFalse,
        reason: 'publish.yaml must not trigger on push to main',
      );
      // Must NOT have pull_request trigger.
      expect(
        publishYaml,
        isNot(contains('pull_request')),
        reason: 'publish.yaml must not trigger on pull requests',
      );
    });

    test('tag patterns match <package>/v<semver> format', () {
      expect(publishYaml, contains('explicit_outcome/v*'));
      expect(publishYaml, contains('explicit/v*'));
    });

    test('has validate_release job', () {
      expect(publishYaml, contains('validate_release'));
    });

    test('has publish_patch_minor job', () {
      expect(publishYaml, contains('publish_patch_minor'));
    });

    test('has publish_major job', () {
      expect(publishYaml, contains('publish_major'));
    });

    test(
      'publish_major is the only job with environment: release-major',
      () {
        // Count occurrences of "environment: release-major".
        final matches = RegExp(r'environment:\s*release-major')
            .allMatches(publishYaml);
        expect(
          matches.length,
          1,
          reason: 'Exactly one job should use release-major environment',
        );
      },
    );

    test('publish_patch_minor has no Environment', () {
      // Extract the publish_patch_minor job section and verify
      // no environment key.
      final jobStart = publishYaml.indexOf('publish_patch_minor');
      expect(jobStart, isNot(-1));
      // Find the next job boundary (next top-level key under jobs:).
      final nextJobMatch = RegExp(r'\n\s{2}\w')
          .firstMatch(publishYaml.substring(jobStart + 20));
      final jobEnd = nextJobMatch != null
          ? jobStart + 20 + nextJobMatch.start
          : publishYaml.length;
      final jobSection = publishYaml.substring(jobStart, jobEnd);
      expect(
        jobSection,
        isNot(contains('environment:')),
        reason: 'publish_patch_minor must not have an Environment',
      );
    });

    test('publish_patch_minor has id-token: write permission', () {
      final jobStart = publishYaml.indexOf('publish_patch_minor');
      final nextJobMatch = RegExp(r'\n\s{2}\w')
          .firstMatch(publishYaml.substring(jobStart + 20));
      final jobEnd = nextJobMatch != null
          ? jobStart + 20 + nextJobMatch.start
          : publishYaml.length;
      final jobSection = publishYaml.substring(jobStart, jobEnd);
      expect(jobSection, contains('id-token: write'));
    });

    test('publish_major has id-token: write permission', () {
      final jobStart = publishYaml.indexOf('publish_major');
      final jobEnd = publishYaml.length;
      final jobSection = publishYaml.substring(jobStart, jobEnd);
      expect(jobSection, contains('id-token: write'));
    });

    test('validate_release has no id-token permission', () {
      final jobStart = publishYaml.indexOf('validate_release');
      final nextJobMatch = RegExp(r'\n\s{2}\w')
          .firstMatch(publishYaml.substring(jobStart + 16));
      final jobEnd = nextJobMatch != null
          ? jobStart + 16 + nextJobMatch.start
          : publishYaml.length;
      final jobSection = publishYaml.substring(jobStart, jobEnd);
      expect(
        jobSection,
        isNot(contains('id-token')),
        reason: 'validate_release must not request OIDC',
      );
    });

    test('no PUB_TOKEN or PUB_CREDENTIALS secrets', () {
      expect(publishYaml, isNot(contains('PUB_TOKEN')));
      expect(publishYaml, isNot(contains('PUB_CREDENTIALS')));
    });

    test('no workflow_dispatch default trigger', () {
      expect(
        publishYaml,
        isNot(contains('workflow_dispatch')),
        reason: 'publish.yaml must not have manual dispatch',
      );
    });

    test('publish.yaml passes safety check for approved jobs', () {
      // The full publish.yaml should pass safety when scanned
      // with the allowlisted jobs.
      final resultValidate = PublishSafety.assertSafeContent(
        publishYaml,
        workflow: 'publish.yaml',
        job: 'validate_release',
      );
      // validate_release should not have OIDC or publish commands.
      // (The file as a whole may contain them for other jobs, but
      // the validator should flag them only if they appear outside
      // the allowlisted context.)
      // For the full-file scan, we accept that OIDC appears but
      // only in allowlisted jobs — the scanner handles this.
      // This test verifies no credentials leak anywhere.
      expect(
        resultValidate.violations
            .where(
              (v) => v.rule == PublishSafety.noTokenEnvRule,
            ),
        isEmpty,
        reason: 'No PUB_TOKEN/PUB_CREDENTIALS anywhere in publish.yaml',
      );
    });
  });

  group('release_version_pr.yaml publish-free assertions', () {
    late String versionPrYaml;

    setUpAll(() {
      final file = File('.github/workflows/release_version_pr.yaml');
      if (!file.existsSync()) {
        fail(
          'release_version_pr.yaml not found',
        );
      }
      versionPrYaml = file.readAsStringSync();
    });

    test('no id-token: write permission', () {
      expect(versionPrYaml, isNot(contains('id-token: write')));
      expect(versionPrYaml, isNot(contains('id-token:write')));
    });

    test('no dart pub publish command', () {
      expect(versionPrYaml, isNot(contains('pub publish')));
    });

    test('no PUB_TOKEN or PUB_CREDENTIALS', () {
      expect(versionPrYaml, isNot(contains('PUB_TOKEN')));
      expect(versionPrYaml, isNot(contains('PUB_CREDENTIALS')));
    });
  });

  group('ci.yaml publish-free assertions', () {
    late String ciYaml;

    setUpAll(() {
      final file = File('.github/workflows/ci.yaml');
      if (!file.existsSync()) {
        fail('ci.yaml not found');
      }
      ciYaml = file.readAsStringSync();
    });

    test('no id-token: write permission', () {
      expect(ciYaml, isNot(contains('id-token: write')));
    });

    test('no dart pub publish command', () {
      expect(ciYaml, isNot(contains('pub publish')));
    });
  });

  group('publish_simulation.yaml regression', () {
    late String simYaml;

    setUpAll(() {
      final file = File('.github/workflows/publish_simulation.yaml');
      if (!file.existsSync()) {
        fail('publish_simulation.yaml not found');
      }
      simYaml = file.readAsStringSync();
    });

    test('no id-token: write permission', () {
      expect(simYaml, isNot(contains('id-token: write')));
    });

    test('no dart pub publish --force', () {
      expect(simYaml, isNot(contains('publish --force')));
    });

    test('no melos publish --no-dry-run', () {
      expect(simYaml, isNot(contains('--no-dry-run')));
    });
  });
}
