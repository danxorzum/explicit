// Quality gate CLI: affected detection → format → analyze → test/coverage.
//
// Usage:
//   dart run tool/quality_gate.dart --mode=pr --base=<sha> --head=<sha>
//   dart run tool/quality_gate.dart --mode=all
//   dart run tool/quality_gate.dart --mode=pre-push
//
// Exits non-zero on first failure (fail-fast).

import 'dart:io';

import 'src/affected_detector.dart';
import 'src/coverage_parser.dart';
import 'src/quality_gate_config.dart';

Future<void> main(List<String> args) async {
  final QualityGateConfig config;
  try {
    config = QualityGateConfig.parse(args);
  } on FormatException catch (e) {
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln(
        'Usage: dart run tool/quality_gate.dart '
        '--mode=pr|all|pre-push [--base=<sha>] [--head=<sha>]',
      );
    exit(64); // EX_USAGE
  }

  stdout.writeln('Quality gate: mode=${config.mode.name}');

  // Determine affected packages
  final List<String> packages;
  if (config.mode == GateMode.all) {
    packages = AffectedDetector.allPackages.toList();
    stdout.writeln('Validating all packages: ${packages.join(', ')}');
  } else {
    final changedFiles = await _getChangedFiles(config);
    packages = AffectedDetector.detectAffectedPackages(changedFiles);
    if (packages.isEmpty) {
      stdout.writeln('No affected packages detected. Skipping gates.');
      exit(0);
    }
    stdout.writeln('Affected packages: ${packages.join(', ')}');
  }

  // If --list-only, print packages and exit
  if (config.listOnly) {
    packages.forEach(stdout.writeln);
    exit(0);
  }

  // Run ordered gates: format → analyze → test/coverage
  for (final package in packages) {
    final packageDir = 'packages/$package';

    // Gate 1: Format
    stdout.writeln('\n--- Format: $package ---');
    final formatResult = await _runProcess(
      'dart',
      ['format', '--output=none', '--set-exit-if-changed', '.'],
      workingDirectory: packageDir,
    );
    if (formatResult != 0) {
      stderr.writeln('FAIL: format check failed for $package');
      exit(1);
    }
    stdout
      ..writeln('PASS: format $package')
      // Gate 2: Analyze
      ..writeln('\n--- Analyze: $package ---');
    final analyzeResult = await _runProcess(
      'dart',
      ['analyze', '--fatal-infos', '.'],
      workingDirectory: packageDir,
    );
    if (analyzeResult != 0) {
      stderr.writeln('FAIL: analyze failed for $package');
      exit(1);
    }
    stdout
      ..writeln('PASS: analyze $package')
      // Gate 3: Test with coverage
      ..writeln('\n--- Test + Coverage: $package ---');
    final testResult = await _runProcess(
      'dart',
      ['test', '--coverage=coverage'],
      workingDirectory: packageDir,
    );
    if (testResult != 0) {
      stderr.writeln('FAIL: tests failed for $package');
      exit(1);
    }
    stdout
      ..writeln('PASS: tests $package')
      // Gate 4: Coverage gate (100% per package)
      ..writeln('\n--- Coverage Gate: $package ---');
    final coverageFile = File('$packageDir/coverage/lcov.info');
    if (!coverageFile.existsSync()) {
      stderr.writeln(
        'FAIL: coverage/lcov.info not found for $package. '
        'Run tests with --coverage first.',
      );
      exit(1);
    }

    final lcovContent = coverageFile.readAsStringSync();
    final coverage = CoverageParser.parseLcov(lcovContent);
    stdout.writeln(
      'Coverage: ${coverage.linesHit}/${coverage.linesFound} '
      '(${coverage.coveragePercent.toStringAsFixed(1)}%)',
    );

    if (!coverage.isFullCoverage) {
      final pct = coverage.coveragePercent.toStringAsFixed(1);
      stderr.writeln('FAIL: $package coverage is $pct% (requires 100%)');
      exit(1);
    }
    stdout.writeln('PASS: coverage $package (100%)');
  }

  stdout.writeln('\n✅ All quality gates passed for: ${packages.join(', ')}');
}

/// Gets changed files based on the config mode.
Future<List<String>> _getChangedFiles(QualityGateConfig config) async {
  if (config.mode == GateMode.pr) {
    return _getGitDiffFiles(config.base!, config.head!);
  }

  // pre-push mode: diff against remote tracking branch
  if (config.mode == GateMode.prePush) {
    return _getPrePushFiles();
  }

  // all mode shouldn't reach here, but fallback to all
  return <String>[];
}

/// Gets files changed between two git commits.
Future<List<String>> _getGitDiffFiles(String base, String head) async {
  final result = await Process.run(
    'git',
    ['diff', '--name-only', '$base...$head'],
  );
  if (result.exitCode != 0) {
    stderr.writeln(
      'Warning: git diff failed, falling back to validate-all',
    );
    return ['pubspec.yaml']; // triggers validate-all
  }
  final output = (result.stdout as String).trim();
  if (output.isEmpty) return <String>[];
  return output.split('\n');
}

/// Gets files changed for pre-push (HEAD vs remote tracking branch).
Future<List<String>> _getPrePushFiles() async {
  // Get the current branch name
  final branchResult = await Process.run(
    'git',
    ['rev-parse', '--abbrev-ref', 'HEAD'],
  );
  if (branchResult.exitCode != 0) {
    stderr.writeln(
      'Warning: could not detect branch, '
      'falling back to validate-all',
    );
    return ['pubspec.yaml'];
  }

  final branch = (branchResult.stdout as String).trim();
  final remote = 'origin/$branch';

  // Check if remote tracking branch exists
  final checkResult = await Process.run(
    'git',
    ['rev-parse', '--verify', remote],
  );
  if (checkResult.exitCode != 0) {
    // No remote tracking branch — validate all
    stdout.writeln(
      'No remote tracking branch found. Validating all packages.',
    );
    return ['pubspec.yaml']; // triggers validate-all
  }

  return _getGitDiffFiles(remote, 'HEAD');
}

/// Runs a process and streams its output to stdout/stderr.
/// Returns the exit code.
Future<int> _runProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );

  await Future.wait([
    process.stdout.forEach(stdout.add),
    process.stderr.forEach(stderr.add),
  ]);

  return process.exitCode;
}
