import 'package:test/test.dart';

import '../src/quality_gate_commands.dart';

void main() {
  group('quality gate commands', () {
    test(
      'format command args match the package working-directory contract',
      () {
        expect(dartExecutable, 'dart');
        expect(packageWorkingDirectory('explicit'), 'packages/explicit');
        expect(qualityGateFormatArgs, [
          'format',
          '--output=none',
          '--set-exit-if-changed',
          '.',
        ]);
      },
    );

    test(
      'test command collects coverage and guards skipped/focused subsets',
      () {
        expect(qualityGateTestArgs, [
          'test',
          '--coverage=coverage',
          '--run-skipped',
        ]);

        const focusedSelectionFlags = {
          '-n',
          '--name',
          '-N',
          '--plain-name',
          '-t',
          '--tags',
          '-x',
          '--exclude-tags',
        };

        for (final flag in focusedSelectionFlags) {
          expect(qualityGateTestArgs, isNot(contains(flag)));
        }
      },
    );

    test('LCOV command uses package-relative package config path', () {
      expect(qualityGateLcovArgs, [
        'run',
        'coverage:format_coverage',
        '--lcov',
        '--in=coverage',
        '--out=coverage/lcov.info',
        '--report-on=lib',
        '--packages=../../.dart_tool/package_config.json',
      ]);
    });
  });
}
