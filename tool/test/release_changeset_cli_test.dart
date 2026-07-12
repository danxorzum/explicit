import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../src/release_planner.dart';

void main() {
  group('release_changeset CLI', () {
    group('init subcommand', () {
      test('creates changeset file with correct format', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'init',
            '--package=explicit_outcome',
            '--bump=minor',
            '--summary=Add typed outcome map helper',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());

        final files = changesetsDir.listSync().whereType<File>().toList();
        expect(files, hasLength(1));

        final content = files.first.readAsStringSync();
        expect(content, contains('explicit_outcome: minor'));
        expect(content, contains('Add typed outcome map helper'));

        tempDir.deleteSync(recursive: true);
      });

      test('fails on missing required arguments', () {
        final result = Process.runSync(
          'dart',
          ['run', 'tool/release_changeset.dart', 'init'],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('--package'));
      });

      test('fails on invalid bump level', () {
        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'init',
            '--package=explicit_outcome',
            '--bump=huge',
            '--summary=Bad bump',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('patch'));
      });
    });

    group('check subcommand', () {
      test('passes when publishable changes have changesets', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        // Create a changeset
        File('${changesetsDir.path}/test-change.md').writeAsStringSync('''
---
explicit_outcome: minor
---

- Add feature.
''');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'check',
            '--changed-files=packages/explicit_outcome/lib/src/option/opt.dart',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('PASS'));

        tempDir.deleteSync(recursive: true);
      });

      test('fails when publishable change has no changeset', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'check',
            '--changed-files=packages/explicit_outcome/lib/src/option/opt.dart',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 1);
        expect(result.stderr.toString(), contains('FAIL'));
        expect(result.stderr.toString(), contains('explicit_outcome'));

        tempDir.deleteSync(recursive: true);
      });

      test('passes when only non-publishable files changed', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'check',
            '--changed-files=tool/quality_gate.dart,docs/setup.md',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());

        tempDir.deleteSync(recursive: true);
      });

      test('fails when changeset is malformed', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        File('${changesetsDir.path}/broken.md').writeAsStringSync('not yaml');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'check',
            '--changed-files=packages/explicit_outcome/lib/src/option/opt.dart',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('Malformed changesets'));
        expect(result.stderr.toString(), contains('Expected format'));

        tempDir.deleteSync(recursive: true);
      });

      test('fails closed when git diff fails', () {
        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'check',
            '--base=missing-base-sha',
            '--head=missing-head-sha',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('git diff failed'));
        expect(result.stderr.toString(), contains('cannot continue'));
        expect(result.stderr.toString(), contains('--changed-files'));
      });
    });

    group('plan subcommand', () {
      test('plan without diff context fails closed', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        File('${changesetsDir.path}/feature-a.md').writeAsStringSync('''
---
explicit_outcome: minor
---

- Add outcome map.
''');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'plan',
            '--format=markdown',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('requires diff context'));

        tempDir.deleteSync(recursive: true);
      });

      test('version-pr without diff context fails closed', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        File('${changesetsDir.path}/feature-a.md').writeAsStringSync('''
---
explicit: patch
---

- Fix bug.
''');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'version-pr',
            '--changesets-dir=${changesetsDir.path}',
            '--workspace-root=${tempDir.path}',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('requires diff context'));

        tempDir.deleteSync(recursive: true);
      });

      test('renders parseable json without human log lines', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        File('${changesetsDir.path}/feature-a.md').writeAsStringSync('''
---
explicit: patch
---

- Fix bug.
''');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'plan',
            '--format=json',
            '--changed-files=tool/release_changeset.dart',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final decoded =
            jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
        expect(decoded, isA<Map<String, dynamic>>());
        expect(decoded['candidates'], isA<List<dynamic>>());

        tempDir.deleteSync(recursive: true);
      });

      test('shows no candidates when no changesets exist', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'plan',
            '--format=markdown',
            '--changed-files=tool/release_changeset.dart',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('No release candidates'));

        tempDir.deleteSync(recursive: true);
      });

      test('ignores README but not arbitrary template-like filenames', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        File('${changesetsDir.path}/README.md').writeAsStringSync('''
---
explicit_outcome: major
---

- Documentation only.
''');
        File('${changesetsDir.path}/release-template.md').writeAsStringSync('''
---
explicit: minor
---

- Template only.
''');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'plan',
            '--format=markdown',
            '--changed-files=packages/explicit/lib/src/parser.dart',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('Changesets loaded: 1'));
        expect(result.stdout.toString(), contains('explicit'));
        expect(result.stdout.toString(), contains('minor'));
        expect(result.stdout.toString(), isNot(contains('explicit_outcome')));

        tempDir.deleteSync(recursive: true);
      });

      test('loads changesets in deterministic filename order', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        File('${changesetsDir.path}/b-second.md').writeAsStringSync('''
---
explicit: patch
---

- Second.
''');
        File('${changesetsDir.path}/a-first.md').writeAsStringSync('''
---
explicit: patch
---

- First.
''');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'plan',
            '--format=json',
            '--changed-files=packages/explicit/lib/src/parser.dart',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final decoded =
            jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>;
        final candidate = candidates.single as Map<String, dynamic>;
        expect(candidate['notes'], contains('- First.\n- Second.'));

        tempDir.deleteSync(recursive: true);
      });

      test('fails when changeset is malformed', () {
        final tempDir = Directory.systemTemp.createTempSync('changeset_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

        File('${changesetsDir.path}/broken.md').writeAsStringSync('not yaml');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'plan',
            '--format=json',
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stdout.toString(), isEmpty);
        expect(result.stderr.toString(), contains('Malformed changesets'));
        expect(result.stderr.toString(), contains('Expected format'));

        tempDir.deleteSync(recursive: true);
      });

      test('default docs fail closed without diff context', () {
        final result = Process.runSync(
          'dart',
          ['run', 'tool/release_changeset.dart', 'plan', '--format=markdown'],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('requires diff context'));
      });
    });

    group('version-pr subcommand', () {
      test('applies version edits from reconciled impact to workspace', () {
        final tempDir = Directory.systemTemp.createTempSync('version_pr_test_');

        // Create workspace structure.
        Directory(
          '${tempDir.path}/packages/explicit_outcome',
        ).createSync(recursive: true);
        Directory(
          '${tempDir.path}/packages/explicit',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.0.1
description: Dart typed outcomes.
''');
        File(
          '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.0.1

- Initial release.
''');
        File(
          '${tempDir.path}/packages/explicit/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit
version: 0.0.1
description: Declarative Dart utilities.
dependencies:
  explicit_outcome: ^0.0.1
''');
        File(
          '${tempDir.path}/packages/explicit/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.0.1

- Initial release.
''');

        // Create changesets directory.
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();
        File('${changesetsDir.path}/add-feature.md').writeAsStringSync('''
---
explicit_outcome: minor
explicit: patch
---

- Add typed outcome API improvements.
''');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'version-pr',
            '--changed-files=packages/explicit_outcome/lib/src/option.dart,packages/explicit/lib/src/parser.dart',
            '--changesets-dir=${changesetsDir.path}',
            '--workspace-root=${tempDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('explicit_outcome'));
        expect(result.stdout.toString(), contains('0.1.0'));

        // Verify files were edited.
        final outcomePubspec = File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).readAsStringSync();
        expect(outcomePubspec, contains('version: 0.1.0'));

        final explicitPubspec = File(
          '${tempDir.path}/packages/explicit/pubspec.yaml',
        ).readAsStringSync();
        expect(explicitPubspec, contains('version: 0.0.2'));
        expect(explicitPubspec, contains('explicit_outcome: ^0.1.0'));

        tempDir.deleteSync(recursive: true);
      });

      test(
        'exits zero with no-candidates message when no reconciled impact',
        () {
          final tempDir = Directory.systemTemp.createTempSync(
            'version_pr_test_',
          );
          final changesetsDir = Directory('${tempDir.path}/.changesets')
            ..createSync();

          final result = Process.runSync(
            'dart',
            [
              'run',
              'tool/release_changeset.dart',
              'version-pr',
              '--changed-files=tool/release_changeset.dart',
              '--changesets-dir=${changesetsDir.path}',
              '--workspace-root=${tempDir.path}',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString().toLowerCase(),
            contains('no release candidates'),
          );

          tempDir.deleteSync(recursive: true);
        },
      );

      test(
        'no-candidates message distinguishes unused changeset intent',
        () {
          final tempDir = Directory.systemTemp.createTempSync(
            'version_pr_test_',
          );
          final changesetsDir = Directory('${tempDir.path}/.changesets')
            ..createSync();
          File('${changesetsDir.path}/unused.md').writeAsStringSync('''
---
explicit_outcome: patch
---

- Intent without real impact.
''');

          final result = Process.runSync(
            'dart',
            [
              'run',
              'tool/release_changeset.dart',
              'version-pr',
              '--changed-files=packages/explicit_outcome/README.md',
              '--changesets-dir=${changesetsDir.path}',
              '--workspace-root=${tempDir.path}',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(result.stdout.toString(), contains('No release candidates'));
          expect(
            result.stdout.toString(),
            contains('changeset intent has no real package impact'),
          );
          expect(
            result.stdout.toString(),
            isNot(contains('no changesets found')),
          );

          tempDir.deleteSync(recursive: true);
        },
      );

      test('logs edits with package names and versions', () {
        final tempDir = Directory.systemTemp.createTempSync('version_pr_test_');

        Directory(
          '${tempDir.path}/packages/explicit_outcome',
        ).createSync(recursive: true);
        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.0.1
description: Dart typed outcomes.
''');
        File(
          '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.0.1

- Initial release.
''');

        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();
        File('${changesetsDir.path}/fix-bug.md').writeAsStringSync('''
---
explicit_outcome: patch
---

- Fix edge case in outcome mapping.
''');

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'version-pr',
            '--changed-files=packages/explicit_outcome/lib/src/option.dart',
            '--changesets-dir=${changesetsDir.path}',
            '--workspace-root=${tempDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('explicit_outcome'));
        expect(result.stdout.toString(), contains('0.0.2'));

        tempDir.deleteSync(recursive: true);
      });
    });

    group('validate-release subcommand', () {
      test('passes when tag, pubspec, changelog, provenance agree', () {
        final tempDir = Directory.systemTemp.createTempSync(
          'validate_release_',
        );

        // Create workspace.
        Directory(
          '${tempDir.path}/packages/explicit_outcome',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.1.0
description: Dart typed outcomes.
''');

        File(
          '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.1.0 (2026-07-09)

- Add typed outcome API.

## 0.0.1

- Initial release.
''');

        // Create provenance manifest.
        final releasesDir = Directory('${tempDir.path}/.changesets/releases')
          ..createSync(recursive: true);
        const changesetContent = '''
---
explicit_outcome: minor
---

- Add typed outcome API.''';
        File(
          '${releasesDir.path}/explicit_outcome-0.1.0.json',
        ).writeAsStringSync(
          jsonEncode({
            'package': 'explicit_outcome',
            'version': '0.1.0',
            'previousVersion': '0.0.1',
            'nextVersion': '0.1.0',
            'bump': 'minor',
            'changesetHashes': [
              ReleaseProvenance.computeContentHash(changesetContent),
            ],
            'changesetContents': [changesetContent],
            'impactProof': ['packages/explicit_outcome/lib/src/option.dart'],
            'changelogNotesHash': ReleaseProvenance.computeContentHash(
              '- Add typed outcome API.',
            ),
            'tag': 'explicit_outcome/v0.1.0',
            'releaseAutomation': ReleaseProvenance.expectedReleaseAutomation,
          }),
        );

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'validate-release',
            '--tag=explicit_outcome/v0.1.0',
            '--workspace-root=${tempDir.path}',
            '--changesets-dir=${tempDir.path}/.changesets',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('explicit_outcome'));
        expect(result.stdout.toString(), contains('0.1.0'));

        tempDir.deleteSync(recursive: true);
      });

      test('fails closed when provenance is absent', () {
        final tempDir = Directory.systemTemp.createTempSync(
          'validate_release_',
        );

        Directory(
          '${tempDir.path}/packages/explicit_outcome',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.1.0
description: Dart typed outcomes.
''');

        File(
          '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.1.0 (2026-07-09)

- Feature.
''');

        // No provenance manifest created.
        Directory('${tempDir.path}/.changesets').createSync();

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'validate-release',
            '--tag=explicit_outcome/v0.1.0',
            '--workspace-root=${tempDir.path}',
            '--changesets-dir=${tempDir.path}/.changesets',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stdout.toString(), contains('provenance'));

        tempDir.deleteSync(recursive: true);
      });

      test('fails on invalid tag format', () {
        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'validate-release',
            '--tag=unknown_pkg/v1.0.0',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('Unknown package'));
      });

      test('fails when --tag is missing', () {
        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'validate-release',
          ],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('--tag'));
      });

      // Regression: stdout must be JSON-only for workflow consumption.
      test('stdout is parseable JSON with no extra text on success', () {
        final tempDir = Directory.systemTemp.createTempSync(
          'validate_release_',
        );

        Directory(
          '${tempDir.path}/packages/explicit_outcome',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.1.0
description: Dart typed outcomes.
''');

        File(
          '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.1.0 (2026-07-09)

- Add typed outcome API.

## 0.0.1

- Initial release.
''');

        final releasesDir = Directory('${tempDir.path}/.changesets/releases')
          ..createSync(recursive: true);
        const changesetContent = '''
---
explicit_outcome: minor
---

- Add typed outcome API.''';
        File(
          '${releasesDir.path}/explicit_outcome-0.1.0.json',
        ).writeAsStringSync(
          jsonEncode({
            'package': 'explicit_outcome',
            'version': '0.1.0',
            'previousVersion': '0.0.1',
            'nextVersion': '0.1.0',
            'bump': 'minor',
            'changesetHashes': [
              ReleaseProvenance.computeContentHash(changesetContent),
            ],
            'changesetContents': [changesetContent],
            'impactProof': ['packages/explicit_outcome/lib/src/option.dart'],
            'changelogNotesHash': ReleaseProvenance.computeContentHash(
              '- Add typed outcome API.',
            ),
            'tag': 'explicit_outcome/v0.1.0',
            'releaseAutomation': ReleaseProvenance.expectedReleaseAutomation,
          }),
        );

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'validate-release',
            '--tag=explicit_outcome/v0.1.0',
            '--workspace-root=${tempDir.path}',
            '--changesets-dir=${tempDir.path}/.changesets',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());

        // stdout must be parseable JSON — no banners, no extra text.
        final stdoutStr = result.stdout.toString().trim();
        final dynamic decoded;
        try {
          decoded = jsonDecode(stdoutStr);
        } on FormatException catch (e) {
          fail(
            'stdout is not valid JSON. '
            'Workflow parses stdout directly, so no extra text allowed.\n'
            'stdout was:\n$stdoutStr\n'
            'Parse error: $e',
          );
        }
        expect(decoded, isA<Map<String, dynamic>>());
        final jsonResult = decoded as Map<String, dynamic>;
        expect(jsonResult['isValid'], isTrue);
        expect(jsonResult['package'], 'explicit_outcome');
        expect(jsonResult['version'], '0.1.0');

        tempDir.deleteSync(recursive: true);
      });

      // Regression: stdout must be parseable JSON on failure too.
      test('stdout is parseable JSON on validation failure', () {
        final tempDir = Directory.systemTemp.createTempSync(
          'validate_release_',
        );

        Directory(
          '${tempDir.path}/packages/explicit_outcome',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.1.0
description: Dart typed outcomes.
''');

        File(
          '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.1.0 (2026-07-09)

- Feature.
''');

        // No provenance manifest — should fail closed.
        Directory('${tempDir.path}/.changesets').createSync();

        final result = Process.runSync(
          'dart',
          [
            'run',
            'tool/release_changeset.dart',
            'validate-release',
            '--tag=explicit_outcome/v0.1.0',
            '--workspace-root=${tempDir.path}',
            '--changesets-dir=${tempDir.path}/.changesets',
          ],
        );

        expect(result.exitCode, isNot(0));

        // stdout must be parseable JSON even on failure.
        final stdoutStr = result.stdout.toString().trim();
        final dynamic decoded;
        try {
          decoded = jsonDecode(stdoutStr);
        } on FormatException catch (e) {
          fail(
            'stdout is not valid JSON on failure path.\n'
            'stdout was:\n$stdoutStr\n'
            'Parse error: $e',
          );
        }
        expect(decoded, isA<Map<String, dynamic>>());
        final jsonResult = decoded as Map<String, dynamic>;
        expect(jsonResult['isValid'], isFalse);

        tempDir.deleteSync(recursive: true);
      });
    });

    group('unknown subcommand', () {
      test('shows usage and exits non-zero', () {
        final result = Process.runSync(
          'dart',
          ['run', 'tool/release_changeset.dart', 'unknown'],
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('Usage'));
      });
    });

    // =========================================================================
    // Content-Aware Integration: reconciler wired into production CLI paths
    // =========================================================================

    /// Resolves the absolute path to the project root (parent of tool/).
    final projectRoot = (() {
      var dir = Directory.current;
      while (!File('${dir.path}/pubspec.yaml').existsSync() ||
          !Directory('${dir.path}/tool').existsSync()) {
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      return dir.path;
    })();

    /// Helper: runs the release_changeset CLI tool from a given working
    /// directory. Uses absolute path so it works from any temp git repo.
    ProcessResult runTool(List<String> args, {required String workingDir}) {
      final toolPath = '$projectRoot/tool/release_changeset.dart';
      return Process.runSync(
        'dart',
        [toolPath, ...args],
        workingDirectory: workingDir,
      );
    }

    /// Helper: creates a temp git repo with an initial commit containing
    /// package scaffolding. Returns the temp dir path.
    String createGitRepoWithPackages() {
      final tempDir = Directory.systemTemp.createTempSync(
        'content_aware_test_',
      );

      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      Process.runSync(
        'git',
        ['config', 'user.email', 'test@test.com'],
        workingDirectory: tempDir.path,
      );
      Process.runSync(
        'git',
        ['config', 'user.name', 'Test'],
        workingDirectory: tempDir.path,
      );

      // Create package scaffolding.
      Directory(
        '${tempDir.path}/packages/explicit_outcome/lib/src',
      ).createSync(recursive: true);
      Directory(
        '${tempDir.path}/packages/explicit/lib/src',
      ).createSync(recursive: true);

      File(
        '${tempDir.path}/packages/explicit_outcome/lib/src/option.dart',
      ).writeAsStringSync('class Option<T> {\n  final T value;\n}\n');
      File(
        '${tempDir.path}/packages/explicit/lib/src/parser.dart',
      ).writeAsStringSync('class Parser {\n  void parse() {}\n}\n');
      File(
        '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
      ).writeAsStringSync(
        'name: explicit_outcome\nversion: 0.0.1\ndescription: Test.\n',
      );
      File('${tempDir.path}/packages/explicit/pubspec.yaml').writeAsStringSync(
        'name: explicit\nversion: 0.0.1\ndescription: Test.\n'
        'dependencies:\n  explicit_outcome: ^0.0.1\n',
      );
      File(
        '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
      ).writeAsStringSync('# Changelog\n\n## 0.0.1\n\n- Initial.\n');
      File(
        '${tempDir.path}/packages/explicit/CHANGELOG.md',
      ).writeAsStringSync('# Changelog\n\n## 0.0.1\n\n- Initial.\n');

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync(
        'git',
        ['commit', '-m', 'initial'],
        workingDirectory: tempDir.path,
      );

      return tempDir.path;
    }

    /// Helper: gets the HEAD commit SHA from a git repo.
    String getHeadSha(String repoPath) {
      final result = Process.runSync(
        'git',
        ['rev-parse', 'HEAD'],
        workingDirectory: repoPath,
      );
      return (result.stdout as String).trim();
    }

    group('content-aware check', () {
      test('comment-only lib diff does not require changeset', () {
        final repoPath = createGitRepoWithPackages();
        final baseSha = getHeadSha(repoPath);

        // Make a comment-only change to a lib file.
        File(
          '$repoPath/packages/explicit_outcome/lib/src/option.dart',
        ).writeAsStringSync(
          'class Option<T> {\n  /// Updated doc comment.\n  final T value;\n}\n',
        );

        Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
        Process.runSync(
          'git',
          ['commit', '-m', 'update comment'],
          workingDirectory: repoPath,
        );
        final headSha = getHeadSha(repoPath);

        final changesetsDir = Directory('$repoPath/.changesets')..createSync();

        final result = runTool(
          [
            'check',
            '--base=$baseSha',
            '--head=$headSha',
            '--changesets-dir=${changesetsDir.path}',
          ],
          workingDir: repoPath,
        );

        // Comment-only change has no real impact → no changeset needed → PASS.
        expect(
          result.exitCode,
          0,
          reason:
              'Comment-only lib change should not require changeset.\n'
              'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
        expect(result.stdout.toString(), contains('PASS'));

        Directory(repoPath).deleteSync(recursive: true);
      });

      test('whitespace-only lib diff does not require changeset', () {
        final repoPath = createGitRepoWithPackages();
        final baseSha = getHeadSha(repoPath);

        // Make a whitespace/formatting-only change.
        File(
          '$repoPath/packages/explicit/lib/src/parser.dart',
        ).writeAsStringSync(
          'class Parser {\n    void parse() {}\n}\n',
        );

        Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
        Process.runSync(
          'git',
          ['commit', '-m', 'formatting'],
          workingDirectory: repoPath,
        );
        final headSha = getHeadSha(repoPath);

        final changesetsDir = Directory('$repoPath/.changesets')..createSync();

        final result = runTool(
          [
            'check',
            '--base=$baseSha',
            '--head=$headSha',
            '--changesets-dir=${changesetsDir.path}',
          ],
          workingDir: repoPath,
        );

        expect(
          result.exitCode,
          0,
          reason:
              'Whitespace-only lib change should not require changeset.\n'
              'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );

        Directory(repoPath).deleteSync(recursive: true);
      });

      test('real code diff without changeset fails check', () {
        final repoPath = createGitRepoWithPackages();
        final baseSha = getHeadSha(repoPath);

        // Make a real code change.
        File(
          '$repoPath/packages/explicit_outcome/lib/src/option.dart',
        ).writeAsStringSync(
          'class Option<T> {\n  final T value;\n  T get() => value;\n}\n',
        );

        Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
        Process.runSync(
          'git',
          ['commit', '-m', 'add getter'],
          workingDirectory: repoPath,
        );
        final headSha = getHeadSha(repoPath);

        final changesetsDir = Directory('$repoPath/.changesets')..createSync();

        final result = runTool(
          [
            'check',
            '--base=$baseSha',
            '--head=$headSha',
            '--changesets-dir=${changesetsDir.path}',
          ],
          workingDir: repoPath,
        );

        // Real impact without changeset → FAIL with remediation.
        expect(
          result.exitCode,
          1,
          reason:
              'Real code change without changeset should fail.\n'
              'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
        expect(result.stderr.toString(), contains('explicit_outcome'));

        Directory(repoPath).deleteSync(recursive: true);
      });

      test(
        'changeset without real impact passes with unused intent warning',
        () {
          final repoPath = createGitRepoWithPackages();
          final baseSha = getHeadSha(repoPath);

          // Make only a comment change (no real impact).
          File(
            '$repoPath/packages/explicit_outcome/lib/src/option.dart',
          ).writeAsStringSync(
            'class Option<T> {\n  // Updated comment\n  final T value;\n}\n',
          );

          Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
          Process.runSync(
            'git',
            ['commit', '-m', 'comment only'],
            workingDirectory: repoPath,
          );
          final headSha = getHeadSha(repoPath);

          // Create a changeset for explicit_outcome (but no real impact).
          final changesetsDir = Directory('$repoPath/.changesets')
            ..createSync();
          File('${changesetsDir.path}/fix-something.md').writeAsStringSync('''
---
explicit_outcome: patch
---

- Fix something.
''');

          final result = runTool(
            [
              'check',
              '--base=$baseSha',
              '--head=$headSha',
              '--changesets-dir=${changesetsDir.path}',
            ],
            workingDir: repoPath,
          );

          // No real impact → no changeset needed → PASS.
          // But should warn about unused intent.
          expect(
            result.exitCode,
            0,
            reason:
                'No real impact means no changeset needed.\n'
                'stdout: ${result.stdout}\nstderr: ${result.stderr}',
          );
          expect(
            result.stdout.toString().toLowerCase(),
            anyOf(contains('unused'), contains('warning'), contains('pass')),
          );

          Directory(repoPath).deleteSync(recursive: true);
        },
      );
    });

    group('content-aware plan', () {
      test(
        'real impact without changeset fails closed without partial plan',
        () {
          final repoPath = createGitRepoWithPackages();
          final baseSha = getHeadSha(repoPath);

          File(
            '$repoPath/packages/explicit_outcome/lib/src/option.dart',
          ).writeAsStringSync(
            'class Option<T> {\n  final T value;\n  T unwrap() => value;\n}\n',
          );
          Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
          Process.runSync(
            'git',
            ['commit', '-m', 'add unwrap'],
            workingDirectory: repoPath,
          );
          final headSha = getHeadSha(repoPath);

          final changesetsDir = Directory('$repoPath/.changesets')
            ..createSync();

          final result = runTool(
            [
              'plan',
              '--format=markdown',
              '--base=$baseSha',
              '--head=$headSha',
              '--changesets-dir=${changesetsDir.path}',
            ],
            workingDir: repoPath,
          );

          expect(result.exitCode, isNot(0));
          expect(result.stderr.toString(), contains('FAIL'));
          expect(result.stderr.toString(), contains('Missing changeset'));
          expect(
            result.stdout.toString(),
            isNot(contains('=== Release Plan ===')),
          );
          expect(result.stdout.toString(), isNot(contains('## Release Plan')));

          Directory(repoPath).deleteSync(recursive: true);
        },
      );

      test(
        'changeset without real impact is excluded from plan candidates',
        () {
          final repoPath = createGitRepoWithPackages();
          final baseSha = getHeadSha(repoPath);

          // Make only a doc change (no real impact).
          File(
            '$repoPath/packages/explicit_outcome/README.md',
          ).writeAsStringSync('# Updated docs\n');

          Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
          Process.runSync(
            'git',
            ['commit', '-m', 'docs only'],
            workingDirectory: repoPath,
          );
          final headSha = getHeadSha(repoPath);

          // Create a changeset for explicit_outcome (but no real impact).
          final changesetsDir = Directory('$repoPath/.changesets')
            ..createSync();
          File('${changesetsDir.path}/fix-something.md').writeAsStringSync('''
---
explicit_outcome: patch
---

- Fix something.
''');

          final result = runTool(
            [
              'plan',
              '--format=json',
              '--base=$baseSha',
              '--head=$headSha',
              '--changesets-dir=${changesetsDir.path}',
            ],
            workingDir: repoPath,
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());

          final decoded =
              jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
          final candidates = decoded['candidates'] as List<dynamic>;

          // Changeset without real impact → no candidates.
          expect(
            candidates,
            isEmpty,
            reason:
                'Changeset without real impact should produce no '
                'candidates. Got: $candidates',
          );

          Directory(repoPath).deleteSync(recursive: true);
        },
      );

      test(
        'real code diff + changeset produces candidate '
        'for impacted package only',
        () {
          final repoPath = createGitRepoWithPackages();
          final baseSha = getHeadSha(repoPath);

          // Make a real code change only in explicit_outcome.
          File(
            '$repoPath/packages/explicit_outcome/lib/src/option.dart',
          ).writeAsStringSync(
            'class Option<T> {\n  final T value;\n  T unwrap() => value;\n}\n',
          );

          Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
          Process.runSync(
            'git',
            ['commit', '-m', 'add unwrap'],
            workingDirectory: repoPath,
          );
          final headSha = getHeadSha(repoPath);

          // Create changesets for BOTH packages.
          final changesetsDir = Directory('$repoPath/.changesets')
            ..createSync();
          File('${changesetsDir.path}/feature.md').writeAsStringSync('''
---
explicit_outcome: minor
explicit: patch
---

- Add features.
''');

          final result = runTool(
            [
              'plan',
              '--format=json',
              '--base=$baseSha',
              '--head=$headSha',
              '--changesets-dir=${changesetsDir.path}',
            ],
            workingDir: repoPath,
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());

          final decoded =
              jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
          final candidates = decoded['candidates'] as List<dynamic>;

          // Only explicit_outcome has real impact → only it
          // should be candidate.
          expect(candidates, hasLength(1));
          expect(
            (candidates.first as Map<String, dynamic>)['package'],
            'explicit_outcome',
          );

          Directory(repoPath).deleteSync(recursive: true);
        },
      );
    });

    group('content-aware version-pr', () {
      test(
        'version-pr applies edits only for reconciled candidates',
        () {
          final repoPath = createGitRepoWithPackages();
          final baseSha = getHeadSha(repoPath);

          // Make a real code change only in explicit_outcome.
          File(
            '$repoPath/packages/explicit_outcome/lib/src/option.dart',
          ).writeAsStringSync(
            'class Option<T> {\n  final T value;\n  T unwrap() => value;\n}\n',
          );

          Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
          Process.runSync(
            'git',
            ['commit', '-m', 'add unwrap'],
            workingDirectory: repoPath,
          );
          final headSha = getHeadSha(repoPath);

          // Create changesets for both packages.
          final changesetsDir = Directory('$repoPath/.changesets')
            ..createSync();
          File('${changesetsDir.path}/feature.md').writeAsStringSync('''
---
explicit_outcome: minor
explicit: patch
---

- Add features.
''');

          final result = runTool(
            [
              'version-pr',
              '--base=$baseSha',
              '--head=$headSha',
              '--changesets-dir=${changesetsDir.path}',
              '--workspace-root=$repoPath',
            ],
            workingDir: repoPath,
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());

          // explicit_outcome should be bumped.
          final outcomePubspec = File(
            '$repoPath/packages/explicit_outcome/pubspec.yaml',
          ).readAsStringSync();
          expect(outcomePubspec, contains('version: 0.1.0'));

          // explicit should NOT be bumped (no real impact).
          final explicitPubspec = File(
            '$repoPath/packages/explicit/pubspec.yaml',
          ).readAsStringSync();
          expect(
            explicitPubspec,
            contains('version: 0.0.1'),
            reason: 'explicit has no real impact, should not be bumped',
          );

          Directory(repoPath).deleteSync(recursive: true);
        },
      );

      test(
        'version-pr --base --head writes provenance only for '
        'reconciled candidates',
        () {
          final repoPath = createGitRepoWithPackages();
          final baseSha = getHeadSha(repoPath);

          // Real code change only in explicit_outcome.
          File(
            '$repoPath/packages/explicit_outcome/lib/src/option.dart',
          ).writeAsStringSync(
            'class Option<T> {\n  final T value;\n  T unwrap() => value;\n}\n',
          );

          Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
          Process.runSync(
            'git',
            ['commit', '-m', 'add unwrap'],
            workingDirectory: repoPath,
          );
          final headSha = getHeadSha(repoPath);

          // Changeset declares intent for both packages.
          final changesetsDir = Directory('$repoPath/.changesets')
            ..createSync();
          File('${changesetsDir.path}/feature.md').writeAsStringSync('''
---
explicit_outcome: minor
explicit: patch
---

- Add features.
''');

          final result = runTool(
            [
              'version-pr',
              '--base=$baseSha',
              '--head=$headSha',
              '--changesets-dir=${changesetsDir.path}',
              '--workspace-root=$repoPath',
            ],
            workingDir: repoPath,
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());

          // Provenance should exist for explicit_outcome (reconciled).
          final outcomeProvFile = File(
            '${changesetsDir.path}/releases/'
            'explicit_outcome-0.1.0.json',
          );
          expect(
            outcomeProvFile.existsSync(),
            isTrue,
            reason: 'Provenance should be emitted for reconciled candidate',
          );

          // Verify provenance content includes previousVersion and tag.
          final prov =
              jsonDecode(
                    outcomeProvFile.readAsStringSync(),
                  )
                  as Map<String, dynamic>;
          expect(prov['package'], 'explicit_outcome');
          expect(prov['version'], '0.1.0');
          expect(prov['previousVersion'], '0.0.1');
          expect(prov['nextVersion'], '0.1.0');
          expect(prov['bump'], 'minor');
          expect(prov['tag'], 'explicit_outcome/v0.1.0');
          expect(
            prov['impactProof'],
            contains('packages/explicit_outcome/lib/src/option.dart'),
          );

          // Provenance should NOT exist for explicit (not reconciled).
          final explicitProvFile = File(
            '${changesetsDir.path}/releases/explicit-0.0.2.json',
          );
          expect(
            explicitProvFile.existsSync(),
            isFalse,
            reason:
                'Provenance must NOT be emitted for changeset intent '
                'without real impact',
          );

          Directory(repoPath).deleteSync(recursive: true);
        },
      );

      test(
        'changeset without real impact does not emit provenance',
        () {
          final repoPath = createGitRepoWithPackages();
          final baseSha = getHeadSha(repoPath);

          // Only a doc change (no real impact).
          File(
            '$repoPath/packages/explicit_outcome/README.md',
          ).writeAsStringSync('# Updated docs\n');

          Process.runSync('git', ['add', '.'], workingDirectory: repoPath);
          Process.runSync(
            'git',
            ['commit', '-m', 'docs only'],
            workingDirectory: repoPath,
          );
          final headSha = getHeadSha(repoPath);

          // Changeset declares intent for explicit_outcome.
          final changesetsDir = Directory('$repoPath/.changesets')
            ..createSync();
          File('${changesetsDir.path}/fix.md').writeAsStringSync('''
---
explicit_outcome: patch
---

- Fix something.
''');

          final result = runTool(
            [
              'version-pr',
              '--base=$baseSha',
              '--head=$headSha',
              '--changesets-dir=${changesetsDir.path}',
              '--workspace-root=$repoPath',
            ],
            workingDir: repoPath,
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());

          // No provenance should be emitted (no real impact).
          final releasesDir = Directory(
            '${changesetsDir.path}/releases',
          );
          final hasProvenance =
              releasesDir.existsSync() && releasesDir.listSync().isNotEmpty;
          expect(
            hasProvenance,
            isFalse,
            reason:
                'No provenance should be emitted when changeset '
                'has no real package impact',
          );

          Directory(repoPath).deleteSync(recursive: true);
        },
      );
    });

    group('corrective slice 2: validation provenance enforcement', () {
      test(
        'manual version edit without provenance fails validation',
        () {
          final tempDir = Directory.systemTemp.createTempSync('manual_edit_');

          Directory(
            '${tempDir.path}/packages/explicit_outcome',
          ).createSync(recursive: true);

          // Simulate a manual version edit: pubspec says 0.5.0
          // but no provenance was generated by the version-pr path.
          File(
            '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
          ).writeAsStringSync('''
name: explicit_outcome
version: 0.5.0
description: Dart typed outcomes.
''');

          File(
            '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
          ).writeAsStringSync('''
# Changelog

## 0.5.0 (2026-07-09)

- Manual version edit.
''');

          Directory('${tempDir.path}/.changesets').createSync();

          final result = Process.runSync(
            'dart',
            [
              'run',
              'tool/release_changeset.dart',
              'validate-release',
              '--tag=explicit_outcome/v0.5.0',
              '--workspace-root=${tempDir.path}',
              '--changesets-dir=${tempDir.path}/.changesets',
            ],
          );

          expect(
            result.exitCode,
            isNot(0),
            reason:
                'Manual version edit without provenance must fail '
                'closed.\nstdout: ${result.stdout}\n'
                'stderr: ${result.stderr}',
          );

          final stdoutStr = result.stdout.toString().trim();
          final decoded = jsonDecode(stdoutStr) as Map<String, dynamic>;
          expect(decoded['isValid'], isFalse);
          expect(
            (decoded['errors'] as List<dynamic>).any(
              (e) => e.toString().contains('provenance'),
            ),
            isTrue,
          );

          tempDir.deleteSync(recursive: true);
        },
      );
    });
  });
}
