// Hook installer CLI: installs or removes the pre-push quality gate hook.
//
// Usage:
//   melos run hooks:install
//   melos run hooks:install -- --uninstall
//   dart run tool/install_hooks.dart
//   dart run tool/install_hooks.dart --uninstall
//
// The installed hook calls the same quality gate as CI (no divergent logic).

import 'dart:io';

import 'src/hook_installer.dart';

Future<void> main(List<String> args) async {
  final HookAction action;
  try {
    action = HookInstaller.parseHookAction(args);
  } on FormatException catch (e) {
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln('Usage: dart run tool/install_hooks.dart [--uninstall]');
    exit(64); // EX_USAGE
  }

  const gitDir = '.git';

  // Validate git directory exists
  if (!HookInstaller.isGitDirPresent('.')) {
    stderr.writeln(
      'Error: .git directory not found. '
      'Run this from the repository root.',
    );
    exit(1);
  }

  final hookPath = HookInstaller.resolveHookPath(gitDir);

  switch (action) {
    case HookAction.install:
      await _installHook(hookPath);
    case HookAction.uninstall:
      _uninstallHook(hookPath);
  }
}

Future<void> _installHook(String hookPath) async {
  final hookDir = File(hookPath).parent;
  if (!hookDir.existsSync()) {
    hookDir.createSync(recursive: true);
  }

  final hookFile = File(hookPath);
  final alreadyInstalled = HookInstaller.isHookInstalled(hookPath);

  final content = HookInstaller.generatePrePushHookContent();
  hookFile.writeAsStringSync(content);

  // Make executable on Unix-like systems
  if (!Platform.isWindows) {
    final result = await Process.run('chmod', ['+x', hookPath]);
    if (result.exitCode != 0) {
      stderr.writeln('Warning: could not make hook executable');
    }
  }

  if (alreadyInstalled) {
    stdout.writeln('✅ Pre-push hook updated at $hookPath');
  } else {
    stdout.writeln('✅ Pre-push hook installed at $hookPath');
  }
  stdout.writeln(
    'The hook runs: melos run quality:gate -- --mode=pre-push\n'
    'Uninstall with: melos run hooks:install -- --uninstall',
  );
}

void _uninstallHook(String hookPath) {
  final hookFile = File(hookPath);

  if (!hookFile.existsSync()) {
    stdout.writeln('No pre-push hook found at $hookPath');
    return;
  }

  // Only remove if it's our managed hook
  if (!HookInstaller.isHookInstalled(hookPath)) {
    stderr.writeln(
      'Warning: existing pre-push hook at $hookPath is not managed '
      'by this installer. Leaving it untouched.',
    );
    return;
  }

  hookFile.deleteSync();
  stdout.writeln('✅ Pre-push hook removed from $hookPath');
}
