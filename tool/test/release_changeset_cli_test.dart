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
      test('returns not-implemented in slice one', () {
        final result = Process.runSync(
          'dart',
          ['run', 'tool/release_changeset.dart', 'version-pr'],
        );

        expect(result.exitCode, isNot(0));
        expect(
          result.stderr.toString().toLowerCase(),
          anyOf(
            contains('not implemented'),
            contains('slice two'),
          ),
        );
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
