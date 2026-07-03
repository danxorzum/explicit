// Coverage gate CLI: enforces 100% line coverage per package.
//
// Usage:
//   dart run tool/coverage_gate.dart --package=explicit
//   dart run tool/coverage_gate.dart --package=explicit_outcome
//   dart run tool/coverage_gate.dart --all
//
// Reads coverage/lcov.info from each package directory.
// Exits non-zero if any package is below 100% coverage.

import 'dart:io';

import 'src/affected_detector.dart';
import 'src/coverage_parser.dart';

Future<void> main(List<String> args) async {
  final packages = <String>[];

  for (final arg in args) {
    if (arg == '--all') {
      packages.addAll(AffectedDetector.allPackages);
    } else if (arg.startsWith('--package=')) {
      packages.add(arg.substring('--package='.length));
    }
  }

  if (packages.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/coverage_gate.dart '
      '--package=<name> | --all',
    );
    exit(64);
  }

  var allPassed = true;

  for (final package in packages) {
    final lcovPath = 'packages/$package/coverage/lcov.info';
    final lcovFile = File(lcovPath);

    if (!lcovFile.existsSync()) {
      stderr.writeln(
        'ERROR: $lcovPath not found. '
        'Run "dart test --coverage=coverage" in packages/$package first.',
      );
      allPassed = false;
      continue;
    }

    final content = lcovFile.readAsStringSync();
    final result = CoverageParser.parseLcov(content);

    stdout.writeln(
      '$package: ${result.linesHit}/${result.linesFound} '
      '(${result.coveragePercent.toStringAsFixed(1)}%)',
    );

    if (!result.isFullCoverage) {
      stderr.writeln(
        'FAIL: $package is at ${result.coveragePercent.toStringAsFixed(1)}% '
        '(requires 100%)',
      );
      allPassed = false;
    }
  }

  if (!allPassed) {
    stderr.writeln('\nCoverage gate FAILED.');
    exit(1);
  }

  stdout.writeln('\n✅ Coverage gate passed (100% per package).');
}
