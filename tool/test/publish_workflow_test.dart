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

    test('has a single publish_package job without major split', () {
      expect(publishYaml, contains('publish_package'));
      expect(publishYaml, isNot(contains('publish_patch_minor')));
      expect(publishYaml, isNot(contains('publish_major')));
      expect(publishYaml, isNot(contains('release-major')));
      expect(publishYaml, isNot(contains('environment:')));
    });

    test('publish_package has id-token and uses --force', () {
      final jobSection = _workflowJobSections(publishYaml)['publish_package'];
      expect(jobSection, isNotNull);
      expect(jobSection, contains('id-token: write'));
      expect(jobSection, contains('dart pub publish --force'));
    });

    test('validate_release never uses dart pub publish --force', () {
      final jobStart = publishYaml.indexOf('validate_release');
      final nextJobMatch = RegExp(
        r'\n\s{2}\w',
      ).firstMatch(publishYaml.substring(jobStart + 16));
      final jobEnd = nextJobMatch != null
          ? jobStart + 16 + nextJobMatch.start
          : publishYaml.length;
      final jobSection = publishYaml.substring(jobStart, jobEnd);
      expect(jobSection, isNot(contains('dart pub publish --force')));
    });

    test('validate_release has no id-token permission', () {
      final jobStart = publishYaml.indexOf('validate_release');
      final nextJobMatch = RegExp(
        r'\n\s{2}\w',
      ).firstMatch(publishYaml.substring(jobStart + 16));
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
        resultValidate.violations.where(
          (v) => v.rule == PublishSafety.noTokenEnvRule,
        ),
        isEmpty,
        reason: 'No PUB_TOKEN/PUB_CREDENTIALS anywhere in publish.yaml',
      );
    });

    test('publish.yaml job sections pass context-aware safety rules', () {
      final jobs = _workflowJobSections(publishYaml);
      const approvedPublishJobs = {'publish_package'};

      expect(
        jobs.keys,
        containsAll(['validate_release', ...approvedPublishJobs]),
      );

      for (final MapEntry(key: jobName, value: jobSection) in jobs.entries) {
        final result = PublishSafety.assertSafeContent(
          jobSection,
          workflow: 'publish.yaml',
          job: jobName,
        );

        expect(
          result.isSafe,
          isTrue,
          reason:
              'publish.yaml::$jobName must satisfy publish safety rules. '
              'Violations: ${result.violations}',
        );

        final usesOidc = jobSection.contains(RegExp(r'id-token:\s*write'));
        final usesForcePublish = jobSection.contains(
          'dart pub publish --force',
        );

        if (approvedPublishJobs.contains(jobName)) {
          expect(
            usesOidc,
            isTrue,
            reason: 'Approved publish job $jobName must use OIDC.',
          );
          expect(
            usesForcePublish,
            isTrue,
            reason:
                'Approved publish job $jobName must publish non-interactively.',
          );
        } else {
          expect(
            usesOidc,
            isFalse,
            reason: 'Only approved publish jobs may request OIDC.',
          );
          expect(
            usesForcePublish,
            isFalse,
            reason: 'Only approved publish jobs may run dart pub publish.',
          );
          expect(
            jobSection,
            isNot(contains('dart pub publish')),
            reason: '$jobName must not publish without --force either.',
          );
        }

        expect(
          result.violations.where(
            (violation) => violation.rule == PublishSafety.noTokenEnvRule,
          ),
          isEmpty,
          reason: 'Credentials are forbidden in every publish.yaml job.',
        );
      }
    });

    test('validate_release cannot request OIDC or publish', () {
      final validateRelease = _workflowJobSections(
        publishYaml,
      )['validate_release'];
      expect(validateRelease, isNotNull);

      final result = PublishSafety.assertSafeContent(
        validateRelease!,
        workflow: 'publish.yaml',
        job: 'validate_release',
      );

      expect(result.isSafe, isTrue);
      expect(validateRelease, isNot(contains(RegExp(r'id-token:\s*write'))));
      expect(validateRelease, isNot(contains('dart pub publish')));
    });

    test(
      'validate_release accepts maintainer-pushed tags after validation',
      () {
        final validateRelease = _workflowJobSections(
          publishYaml,
        )['validate_release']!;

        expect(
          validateRelease,
          isNot(contains('TAG_PUSH_ACTOR')),
          reason: 'Manual maintainer tag creation is the approval boundary.',
        );
      },
    );

    test('validate_release verifies the checked-out tag target commit', () {
      final validateRelease = _workflowJobSections(
        publishYaml,
      )['validate_release']!;

      expect(
        validateRelease,
        allOf([
          contains(r'git rev-list -n 1 "$TAG"'),
          contains('git rev-parse HEAD'),
          contains('Release tag target check failed'),
        ]),
        reason:
            'Publish validation must bind the workflow checkout to the tag '
            'target before OIDC publish jobs can run.',
      );
    });

    test('credentials are rejected in every publish.yaml job context', () {
      final jobs = _workflowJobSections(publishYaml);

      for (final jobName in jobs.keys) {
        final result = PublishSafety.assertSafeContent(
          'env:\n  PUB_TOKEN: secret\n  PUB_CREDENTIALS: secret\n',
          workflow: 'publish.yaml',
          job: jobName,
        );

        expect(result.isSafe, isFalse);
        expect(
          result.violations.where(
            (v) => v.rule == PublishSafety.noTokenEnvRule,
          ),
          hasLength(2),
          reason:
              'Credentials must remain forbidden even in allowed publish job '
              'context publish.yaml::$jobName.',
        );
      }
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

    // Regression: every plan/version-pr invocation must pass diff context
    // so the reconciler produces impact-aware candidates.

    test('has diff context computation step', () {
      // The workflow must compute a base/head range before invoking
      // plan or version-pr. Look for a step that sets base_sha output.
      expect(
        versionPrYaml,
        contains('base_sha'),
        reason:
            'Workflow must compute a diff context range '
            '(base_sha output) before invoking plan/version-pr',
      );
    });

    test('diff context never uses the latest global release tag as base', () {
      final diffStep = _workflowStepSection(
        versionPrYaml,
        'Compute diff context',
      );

      expect(
        diffStep,
        isNot(contains("git tag --list '*/v*'")),
        reason:
            'A single latest global package tag can hide unreleased changesets '
            'for another package.',
      );
      expect(
        diffStep.toLowerCase(),
        isNot(contains('latest release tag')),
        reason: 'Diff base must not be selected from package release tags.',
      );
    });

    test('diff context uses version PR merge or push before SHA', () {
      final diffStep = _workflowStepSection(
        versionPrYaml,
        'Compute diff context',
      );

      expect(
        diffStep,
        allOf([
          contains('chore(release): prepare package versions'),
          contains('LAST_RELEASE_COMMIT'),
          contains('PUSH_BEFORE_SHA'),
          contains('using push before SHA'),
        ]),
        reason:
            'The release version PR range must start from the last version PR '
            'baseline, or from the current push before SHA before such a '
            'baseline exists, so historical package files are not treated as '
            'current release impact.',
      );
    });

    test('diff context does not fall back to repository root', () {
      final diffStep = _workflowStepSection(
        versionPrYaml,
        'Compute diff context',
      );

      expect(
        diffStep,
        isNot(contains('git rev-list --max-parents=0 HEAD')),
        reason:
            'Root fallback reclassifies historical package files as current '
            'release impact and incorrectly requires changesets.',
      );
    });

    test('every plan invocation passes --base and --head', () {
      // Join continuation lines (backslash + newline) so multi-line
      // shell commands become single logical lines for assertion.
      final joined = versionPrYaml.replaceAll('\\\n', ' ');
      final planLines = joined
          .split('\n')
          .where(
            (line) =>
                line.contains('release_changeset.dart') &&
                line.contains(' plan'),
          )
          .toList();

      expect(
        planLines,
        isNotEmpty,
        reason: 'Expected at least one plan invocation',
      );

      for (final line in planLines) {
        expect(
          line,
          allOf(contains('--base'), contains('--head')),
          reason:
              'plan invocation must pass --base and --head for '
              'impact-aware reconciliation. '
              'Line: $line',
        );
      }
    });

    test('every version-pr invocation passes --base and --head', () {
      // Join continuation lines (backslash + newline) so multi-line
      // shell commands become single logical lines for assertion.
      final joined = versionPrYaml.replaceAll('\\\n', ' ');
      final versionPrLines = joined
          .split('\n')
          .where(
            (line) =>
                line.contains('release_changeset.dart') &&
                line.contains(' version-pr'),
          )
          .toList();

      expect(
        versionPrLines,
        isNotEmpty,
        reason: 'Expected at least one version-pr invocation',
      );

      for (final line in versionPrLines) {
        expect(
          line,
          allOf(contains('--base'), contains('--head')),
          reason:
              'version-pr invocation must pass --base and --head for '
              'impact-aware reconciliation. '
              'Line: $line',
        );
      }
    });

    test(
      'no stale release-transfer language in PR body or comments',
      () {
        // The corrected contract: the maintainer manually creates tags after
        // the version PR merges and CI is green.
        const staleTransferTerm =
            'hand'
            'off';
        expect(
          versionPrYaml,
          isNot(contains('tags will be created manually')),
          reason: 'Use current manual tag wording instead of stale phrasing.',
        );
        expect(
          versionPrYaml.toLowerCase(),
          isNot(contains(staleTransferTerm)),
          reason:
              'Release workflow logs and PR body must not describe a manual '
              'transfer step.',
        );
        expect(
          versionPrYaml,
          contains(
            'maintainer manually creates and pushes validated release tags',
          ),
          reason: 'Workflow logs must describe the corrected manual tag flow.',
        );
      },
    );

    test('check_candidates step passes --base and --head to plan', () {
      // The check_candidates step invokes plan internally to count
      // candidates. It must also pass diff context.
      final joined = versionPrYaml.replaceAll('\\\n', ' ');
      final lines = joined.split('\n');

      // Find the check_candidates step section.
      var inCheckStep = false;
      var foundPlanWithContext = false;
      for (final line in lines) {
        if (line.contains('id: check_candidates')) {
          inCheckStep = true;
        } else if (inCheckStep && RegExp(r'^\s{6}-\s').hasMatch(line)) {
          // Next step boundary — exit.
          break;
        }
        if (inCheckStep &&
            line.contains('release_changeset.dart') &&
            line.contains(' plan')) {
          if (line.contains('--base') && line.contains('--head')) {
            foundPlanWithContext = true;
          }
        }
      }

      expect(
        foundPlanWithContext,
        isTrue,
        reason:
            'check_candidates step must invoke plan with '
            '--base/--head for impact-aware candidate counting',
      );
    });

    test(
      'downstream steps are gated on diff context availability',
      () {
        // Steps that invoke plan/version-pr must have an `if:` condition
        // that checks base_sha is non-empty, ensuring fail-closed behavior
        // when no safe diff range can be computed.
        expect(
          versionPrYaml,
          contains("steps.diff_context.outputs.base_sha != ''"),
          reason:
              'Steps requiring diff context must be gated on '
              'base_sha being non-empty (fail-closed)',
        );
      },
    );

    test(
      'version-edit downstream steps require candidates and diff context',
      () {
        final commandsOnly = _withoutYamlComments(versionPrYaml);
        for (final stepName in [
          'Apply version edits',
          'Generate PR body',
          'Create or update release version PR',
        ]) {
          final step = _workflowStepSection(commandsOnly, stepName);
          expect(
            step,
            allOf([
              contains("steps.diff_context.outputs.base_sha != ''"),
              contains(
                'fromJSON(steps.check_candidates.outputs.candidate_count) > 0',
              ),
            ]),
            reason:
                '$stepName must not run when candidate_count is unset or '
                'when base_sha is unavailable.',
          );
          expect(
            step,
            isNot(contains("candidate_count != '0'")),
            reason:
                '$stepName must not treat an unset candidate_count as '
                'work.',
          );
        }
      },
    );

    test(
      'fail-closed message is logged when no diff context available',
      () {
        // When no safe base is found, the workflow should log a clear
        // fail-closed message rather than silently proceeding.
        expect(
          versionPrYaml,
          contains('FAIL CLOSED'),
          reason:
              'Workflow must log fail-closed when no safe diff '
              'context is available',
        );
      },
    );

    test('initial release PR diff context uses push before SHA, not root', () {
      final diffContextStep = _workflowStepSection(
        versionPrYaml,
        'Compute diff context',
      );

      expect(
        diffContextStep,
        contains('PUSH_BEFORE_SHA'),
        reason:
            'Before the first version PR exists, push workflows must compare '
            'only the current push instead of the entire repository history.',
      );
      expect(
        diffContextStep,
        isNot(contains('rev-list --max-parents=0')),
        reason:
            'Root fallback reclassifies historical package files as current '
            'release impact and incorrectly requires changesets.',
      );
    });

    test('version PR workflow never creates or pushes release tags', () {
      expect(versionPrYaml, isNot(contains('create-tags')));
      expect(versionPrYaml, isNot(contains('git tag -f')));
      expect(versionPrYaml, isNot(contains('git tag "')));
      expect(versionPrYaml, isNot(contains(r'git push origin "$TAG"')));
      expect(versionPrYaml, contains('maintainer manually creates'));
    });

    test('release PR body is passed through a body file', () {
      final createOrUpdateStep = _workflowStepSection(
        versionPrYaml,
        'Create or update release version PR',
      );

      expect(
        createOrUpdateStep,
        isNot(contains(r'--body "${{ steps.pr_body.outputs.body }}"')),
        reason:
            'Changeset notes must not be interpolated into double-quoted '
            'shell arguments because command substitutions would execute.',
      );
      expect(
        createOrUpdateStep,
        isNot(contains('steps.pr_body.outputs.body')),
        reason: 'PR body output must not be re-expanded by the shell.',
      );
      expect(
        createOrUpdateStep,
        contains(r'--body-file "$PR_BODY_FILE"'),
        reason: 'gh pr create/edit must read the generated body from a file.',
      );
      expect(
        createOrUpdateStep,
        isNot(contains(' --body ')),
        reason: 'Use --body-file instead of inline --body arguments.',
      );
    });

    test('generated release PR body is written to a temp file', () {
      final generateBodyStep = _workflowStepSection(
        versionPrYaml,
        'Generate PR body',
      );

      expect(
        generateBodyStep,
        allOf([
          contains(
            r'PR_BODY_FILE="$RUNNER_TEMP/release-version-pr-body.md"',
          ),
          contains(r'} > "$PR_BODY_FILE"'),
        ]),
        reason:
            'The workflow must materialize the markdown body before '
            'invoking gh.',
      );
      expect(
        generateBodyStep,
        isNot(contains('body<<EOF')),
        reason:
            'The PR body should not be exposed as a multi-line GitHub output.',
      );
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

String _withoutYamlComments(String yaml) => yaml
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

String _workflowStepSection(String yaml, String stepName) {
  final start = yaml.indexOf('- name: $stepName');
  expect(start, isNot(-1), reason: 'Expected workflow step: $stepName');
  final afterStart = yaml.substring(start + 1);
  final nextStep = RegExp(r'\n\s{6}- name: ').firstMatch(afterStart);
  final end = nextStep == null ? yaml.length : start + 1 + nextStep.start;
  return yaml.substring(start, end).replaceAll('\\\n', ' ');
}

Map<String, String> _workflowJobSections(String yaml) {
  final lines = yaml.split('\n');
  final jobsStartIndex = lines.indexWhere((line) => line.trim() == 'jobs:');
  expect(jobsStartIndex, isNonNegative, reason: 'Expected jobs: section');

  final jobs = <String, String>{};
  String? currentJob;
  final currentLines = <String>[];

  void flushCurrentJob() {
    final job = currentJob;
    if (job != null) {
      jobs[job] = currentLines.join('\n');
      currentLines.clear();
    }
  }

  for (final line in lines.skip(jobsStartIndex + 1)) {
    final topLevelAfterJobs = line.isNotEmpty && !line.startsWith(' ');
    if (topLevelAfterJobs) break;

    final jobMatch = RegExp(r'^  ([A-Za-z0-9_-]+):\s*$').firstMatch(line);
    if (jobMatch != null) {
      flushCurrentJob();
      currentJob = jobMatch.group(1);
      currentLines.add(line);
      continue;
    }

    if (currentJob != null) {
      currentLines.add(line);
    }
  }
  flushCurrentJob();

  return jobs;
}
