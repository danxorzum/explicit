import 'package:test/test.dart';

import '../src/quality_gate_config.dart';

void main() {
  group('QualityGateConfig', () {
    group('parse', () {
      test('parses --mode=all', () {
        final config = QualityGateConfig.parse(['--mode=all']);
        expect(config.mode, GateMode.all);
      });

      test('parses --mode=pr with --base and --head', () {
        final config = QualityGateConfig.parse([
          '--mode=pr',
          '--base=abc123',
          '--head=def456',
        ]);
        expect(config.mode, GateMode.pr);
        expect(config.base, 'abc123');
        expect(config.head, 'def456');
      });

      test('parses --mode=pre-push', () {
        final config = QualityGateConfig.parse(['--mode=pre-push']);
        expect(config.mode, GateMode.prePush);
      });

      test('defaults to all mode when no mode specified', () {
        final config = QualityGateConfig.parse([]);
        expect(config.mode, GateMode.all);
      });

      test('throws on invalid mode', () {
        expect(
          () => QualityGateConfig.parse(['--mode=invalid']),
          throwsA(isA<FormatException>()),
        );
      });

      test('pr mode requires base and head', () {
        expect(
          () => QualityGateConfig.parse(['--mode=pr']),
          throwsA(isA<FormatException>()),
        );
      });

      test('pr mode requires both base and head', () {
        expect(
          () => QualityGateConfig.parse(['--mode=pr', '--base=abc123']),
          throwsA(isA<FormatException>()),
        );
      });

      test('all mode does not require base/head', () {
        final config = QualityGateConfig.parse(['--mode=all']);
        expect(config.mode, GateMode.all);
        expect(config.base, isNull);
        expect(config.head, isNull);
      });

      test('prePush mode does not require base/head', () {
        final config = QualityGateConfig.parse(['--mode=pre-push']);
        expect(config.mode, GateMode.prePush);
      });

      test('parses --list-only flag', () {
        final config = QualityGateConfig.parse(['--list-only']);
        expect(config.listOnly, isTrue);
      });

      test('listOnly defaults to false', () {
        final config = QualityGateConfig.parse(['--mode=all']);
        expect(config.listOnly, isFalse);
      });

      test('list-only works with pr mode', () {
        final config = QualityGateConfig.parse([
          '--mode=pr',
          '--base=abc',
          '--head=def',
          '--list-only',
        ]);
        expect(config.listOnly, isTrue);
        expect(config.mode, GateMode.pr);
      });
    });

    group('requiresGitDiff', () {
      test('is true for pr mode', () {
        final config = QualityGateConfig.parse([
          '--mode=pr',
          '--base=abc',
          '--head=def',
        ]);
        expect(config.requiresGitDiff, isTrue);
      });

      test('is false for all mode', () {
        final config = QualityGateConfig.parse(['--mode=all']);
        expect(config.requiresGitDiff, isFalse);
      });

      test('is false for pre-push mode', () {
        final config = QualityGateConfig.parse(['--mode=pre-push']);
        expect(config.requiresGitDiff, isFalse);
      });
    });
  });
}
