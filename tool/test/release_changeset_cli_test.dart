import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

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
      test('renders markdown plan from changesets', () {
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

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('explicit_outcome'));
        expect(result.stdout.toString(), contains('minor'));

        tempDir.deleteSync(recursive: true);
      });

      test('renders json plan from changesets', () {
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
            '--changesets-dir=${changesetsDir.path}',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('"candidates"'));
        expect(result.stdout.toString(), contains('"explicit"'));

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

      test('default docs produce no candidates', () {
        final result = Process.runSync(
          'dart',
          ['run', 'tool/release_changeset.dart', 'plan', '--format=markdown'],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('No release candidates'));
      });
    });

    group('version-pr subcommand', () {
      test('applies version edits from changesets to workspace', () {
        final tempDir =
            Directory.systemTemp.createTempSync('version_pr_test_');

        // Create workspace structure.
        Directory('${tempDir.path}/packages/explicit_outcome')
            .createSync(recursive: true);
        Directory('${tempDir.path}/packages/explicit')
            .createSync(recursive: true);

        File('${tempDir.path}/packages/explicit_outcome/pubspec.yaml')
            .writeAsStringSync('''
name: explicit_outcome
version: 0.0.1
description: Dart typed outcomes.
''');
        File('${tempDir.path}/packages/explicit_outcome/CHANGELOG.md')
            .writeAsStringSync('''
# Changelog

## 0.0.1

- Initial release.
''');
        File('${tempDir.path}/packages/explicit/pubspec.yaml')
            .writeAsStringSync('''
name: explicit
version: 0.0.1
description: Declarative Dart utilities.
dependencies:
  explicit_outcome: ^0.0.1
''');
        File('${tempDir.path}/packages/explicit/CHANGELOG.md')
            .writeAsStringSync('''
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

      test('exits zero with no-candidates message when no changesets', () {
        final tempDir =
            Directory.systemTemp.createTempSync('version_pr_test_');
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();

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

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString().toLowerCase(),
          contains('no release candidates'),
        );

        tempDir.deleteSync(recursive: true);
      });

      test('logs edits with package names and versions', () {
        final tempDir =
            Directory.systemTemp.createTempSync('version_pr_test_');

        Directory('${tempDir.path}/packages/explicit_outcome')
            .createSync(recursive: true);
        File('${tempDir.path}/packages/explicit_outcome/pubspec.yaml')
            .writeAsStringSync('''
name: explicit_outcome
version: 0.0.1
description: Dart typed outcomes.
''');
        File('${tempDir.path}/packages/explicit_outcome/CHANGELOG.md')
            .writeAsStringSync('''
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
        final tempDir =
            Directory.systemTemp.createTempSync('validate_release_');

        // Create workspace.
        Directory('${tempDir.path}/packages/explicit_outcome')
            .createSync(recursive: true);

        File('${tempDir.path}/packages/explicit_outcome/pubspec.yaml')
            .writeAsStringSync('''
name: explicit_outcome
version: 0.1.0
description: Dart typed outcomes.
''');

        File('${tempDir.path}/packages/explicit_outcome/CHANGELOG.md')
            .writeAsStringSync('''
# Changelog

## 0.1.0 (2026-07-09)

- Add typed outcome API.

## 0.0.1

- Initial release.
''');

        // Create provenance manifest.
        final releasesDir =
            Directory('${tempDir.path}/.changesets/releases')
              ..createSync(recursive: true);
        File('${releasesDir.path}/explicit_outcome-0.1.0.json')
            .writeAsStringSync('''
{
  "package": "explicit_outcome",
  "version": "0.1.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''');

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
        final tempDir =
            Directory.systemTemp.createTempSync('validate_release_');

        Directory('${tempDir.path}/packages/explicit_outcome')
            .createSync(recursive: true);

        File('${tempDir.path}/packages/explicit_outcome/pubspec.yaml')
            .writeAsStringSync('''
name: explicit_outcome
version: 0.1.0
description: Dart typed outcomes.
''');

        File('${tempDir.path}/packages/explicit_outcome/CHANGELOG.md')
            .writeAsStringSync('''
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
        final tempDir =
            Directory.systemTemp.createTempSync('validate_release_');

        Directory('${tempDir.path}/packages/explicit_outcome')
            .createSync(recursive: true);

        File('${tempDir.path}/packages/explicit_outcome/pubspec.yaml')
            .writeAsStringSync('''
name: explicit_outcome
version: 0.1.0
description: Dart typed outcomes.
''');

        File('${tempDir.path}/packages/explicit_outcome/CHANGELOG.md')
            .writeAsStringSync('''
# Changelog

## 0.1.0 (2026-07-09)

- Add typed outcome API.

## 0.0.1

- Initial release.
''');

        final releasesDir =
            Directory('${tempDir.path}/.changesets/releases')
              ..createSync(recursive: true);
        File('${releasesDir.path}/explicit_outcome-0.1.0.json')
            .writeAsStringSync('''
{
  "package": "explicit_outcome",
  "version": "0.1.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''');

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
        final tempDir =
            Directory.systemTemp.createTempSync('validate_release_');

        Directory('${tempDir.path}/packages/explicit_outcome')
            .createSync(recursive: true);

        File('${tempDir.path}/packages/explicit_outcome/pubspec.yaml')
            .writeAsStringSync('''
name: explicit_outcome
version: 0.1.0
description: Dart typed outcomes.
''');

        File('${tempDir.path}/packages/explicit_outcome/CHANGELOG.md')
            .writeAsStringSync('''
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
  });
}
