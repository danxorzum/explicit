import 'dart:io';

/// Action to perform on the hook.
enum HookAction {
  /// Install or update the pre-push hook.
  install,

  /// Remove the pre-push hook.
  uninstall,
}

/// Pure logic for hook installation and management.
///
/// Generates pre-push hook content that calls the shared CI gate
/// via `melos run quality:gate -- --mode=pre-push`.
class HookInstaller {
  /// Version marker embedded in generated hooks for upgrade detection.
  static const String hookVersion = 'explicit-hook-v1';

  /// Generates the pre-push hook shell script content.
  ///
  /// The generated script:
  /// - Has correct bash shebang
  /// - Calls `melos run quality:gate -- --mode=pre-push`
  /// - Exits with the gate's exit code
  /// - Contains a version marker for upgrade detection
  static String generatePrePushHookContent() {
    return '''
#!/usr/bin/env bash
# $hookVersion
# Pre-push quality gate — installed by `melos run hooks:install`
# Uninstall with `melos run hooks:install -- --uninstall`

set -e

echo "Running pre-push quality gate..."
melos run quality:gate -- --mode=pre-push
exit \$?
''';
  }

  /// Parses CLI arguments to determine the hook action.
  ///
  /// Defaults to [HookAction.install] when no args provided.
  /// Throws [FormatException] on unknown flags.
  static HookAction parseHookAction(List<String> args) {
    for (final arg in args) {
      if (arg == '--uninstall') return HookAction.uninstall;
      if (arg == '--install') return HookAction.install;
      throw FormatException(
        'Unknown flag: $arg. Use --install or --uninstall.',
      );
    }
    return HookAction.install;
  }

  /// Returns the path to the pre-push hook file.
  static String resolveHookPath(String gitDir) {
    return '$gitDir/hooks/pre-push';
  }

  /// Checks if the hook is installed with the correct version.
  ///
  /// Returns true only if the hook file exists AND contains the
  /// current [hookVersion] marker.
  static bool isHookInstalled(String hookPath) {
    final file = File(hookPath);
    if (!file.existsSync()) return false;
    final content = file.readAsStringSync();
    return content.contains(hookVersion);
  }

  /// Checks if a `.git` directory exists at [projectRoot].
  static bool isGitDirPresent(String projectRoot) {
    return Directory('$projectRoot/.git').existsSync();
  }
}
