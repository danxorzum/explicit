import 'dart:io';

import 'package:test/test.dart';

import '../src/hook_installer.dart';

void main() {
  group('HookInstaller', () {
    group('generatePrePushHookContent', () {
      test('generates shell script with correct shebang', () {
        final content = HookInstaller.generatePrePushHookContent();
        expect(content, startsWith('#!/usr/bin/env bash'));
      });

      test('calls melos run quality:gate with pre-push mode', () {
        final content = HookInstaller.generatePrePushHookContent();
        expect(content, contains('melos run quality:gate -- --mode=pre-push'));
      });

      test('exits with the gate exit code', () {
        final content = HookInstaller.generatePrePushHookContent();
        expect(content, contains(r'exit $?'));
      });

      test('contains version marker for upgrade detection', () {
        final content = HookInstaller.generatePrePushHookContent();
        expect(content, contains(HookInstaller.hookVersion));
      });

      test('does not contain real publish commands', () {
        final content = HookInstaller.generatePrePushHookContent();
        expect(content, isNot(contains('pub publish --force')));
        expect(content, isNot(contains('--no-dry-run')));
      });

      test('uses set -e for fail-fast behavior', () {
        final content = HookInstaller.generatePrePushHookContent();
        expect(content, contains('set -e'));
      });

      test('contains install/uninstall usage hints', () {
        final content = HookInstaller.generatePrePushHookContent();
        expect(content, contains('hooks:install'));
        expect(content, contains('--uninstall'));
      });
    });

    group('parseHookAction', () {
      test('defaults to install when no args', () {
        final action = HookInstaller.parseHookAction([]);
        expect(action, HookAction.install);
      });

      test('parses --uninstall flag', () {
        final action = HookInstaller.parseHookAction(['--uninstall']);
        expect(action, HookAction.uninstall);
      });

      test('parses --install flag explicitly', () {
        final action = HookInstaller.parseHookAction(['--install']);
        expect(action, HookAction.install);
      });

      test('throws on unknown flag', () {
        expect(
          () => HookInstaller.parseHookAction(['--unknown']),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('resolveHookPath', () {
      test('returns .git/hooks/pre-push path', () {
        final path = HookInstaller.resolveHookPath('.git');
        expect(path, '.git/hooks/pre-push');
      });

      test('handles custom git dir', () {
        final path = HookInstaller.resolveHookPath('/custom/.git');
        expect(path, '/custom/.git/hooks/pre-push');
      });
    });

    group('isHookInstalled', () {
      test('returns false when hook file does not exist', () {
        final installed = HookInstaller.isHookInstalled(
          '/nonexistent/path/pre-push',
        );
        expect(installed, isFalse);
      });

      test('returns false when hook exists but lacks version marker', () {
        // Use a temp file with content that lacks the version marker
        final tempDir = Directory.systemTemp.createTempSync('hook_test_');
        final hookFile = File('${tempDir.path}/pre-push')
          ..writeAsStringSync('#!/usr/bin/env bash\necho old hook\n');

        final installed = HookInstaller.isHookInstalled(hookFile.path);
        expect(installed, isFalse);

        tempDir.deleteSync(recursive: true);
      });

      test('returns true when hook exists with version marker', () {
        final tempDir = Directory.systemTemp.createTempSync('hook_test_');
        final hookFile = File('${tempDir.path}/pre-push')
          ..writeAsStringSync(
            '#!/usr/bin/env bash\n'
            '# ${HookInstaller.hookVersion}\n'
            'melos run quality:gate -- --mode=pre-push\n',
          );

        final installed = HookInstaller.isHookInstalled(hookFile.path);
        expect(installed, isTrue);

        tempDir.deleteSync(recursive: true);
      });
    });

    group('isGitDirPresent', () {
      test('returns false for nonexistent directory', () {
        expect(HookInstaller.isGitDirPresent('/nonexistent'), isFalse);
      });

      test('returns true when .git directory exists', () {
        final tempDir = Directory.systemTemp.createTempSync('git_test_');
        Directory('${tempDir.path}/.git').createSync();

        expect(HookInstaller.isGitDirPresent(tempDir.path), isTrue);

        tempDir.deleteSync(recursive: true);
      });
    });
  });
}
