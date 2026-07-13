// Pana gate CLI: runs Pana per package and checks for max score.
//
// Usage:
//   dart run tool/pana_gate.dart --package=explicit_outcome
//   dart run tool/pana_gate.dart --package=explicit
//   dart run tool/pana_gate.dart --all
//
// Pass condition: grantedPoints == maxPoints (NOT a hardcoded score), or a
// narrow format-only Pana exception when format/analyze are checked separately.
// Exits non-zero if any package does not achieve max score.

import 'dart:io';

import 'src/affected_detector.dart';
import 'src/pana_parser.dart';

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
      'Usage: dart run tool/pana_gate.dart '
      '--package=<name> | --all',
    );
    exit(64);
  }

  var allPassed = true;

  for (final package in packages) {
    final packageDir = 'packages/$package';

    stdout.writeln('\n--- Pana: $package ---');

    // Run Pana from the workspace root with JSON output. Pana is a root
    // dev_dependency so CI and local runs do not depend on global activation.
    final panaResult = await Process.run('dart', [
      'run',
      'pana',
      '--json',
      packageDir,
    ]);

    if (panaResult.exitCode != 0) {
      stderr
        ..writeln(
          'FAIL: pana execution failed for $package '
          '(exit code: ${panaResult.exitCode})',
        )
        ..writeln(panaResult.stderr);
      allPassed = false;
      continue;
    }

    final jsonOutput = panaResult.stdout as String;

    final PanaResult result;
    try {
      result = PanaParser.parsePanaJson(jsonOutput);
    } on FormatException catch (e) {
      stderr.writeln('FAIL: could not parse pana output for $package: $e');
      allPassed = false;
      continue;
    }

    stdout.writeln(
      '$package: ${result.grantedPoints}/${result.maxPoints} '
      '(${result.scorePercent.toStringAsFixed(1)}%)',
    );

    if (!result.isAcceptable) {
      stderr.writeln(
        'FAIL: $package scored ${result.grantedPoints}/${result.maxPoints} '
        '(requires max score or a format-only Pana exception)',
      );
      allPassed = false;
    } else if (result.hasFormatOnlyException) {
      stdout.writeln(
        'WARN: $package has a Pana format-only exception. '
        'Accepted because format/analyze are checked separately.',
      );
    } else {
      stdout.writeln('PASS: $package achieved max Pana score');
    }
  }

  if (!allPassed) {
    stderr.writeln('\nPana gate FAILED.');
    exit(1);
  }

  stdout.writeln('\n✅ Pana gate passed.');
}
