import 'package:explicit_example/src/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('demo', () {
    late Logger logger;
    late ExplicitExampleCommandRunner commandRunner;

    setUp(() {
      logger = _MockLogger();
      commandRunner = ExplicitExampleCommandRunner(logger: logger);
    });

    test('runs as the default command', () async {
      final exitCode = await commandRunner.run([]);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.info('== 1. Success and failure ==')).called(1);
      verify(() => logger.info('ping: reachable')).called(1);
    });

    test('runs as an explicit command', () async {
      final exitCode = await commandRunner.run(['demo']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.info('== 5. AsyncRes with retry ==')).called(1);
      verify(() => logger.info('payload: payload')).called(1);
    });
  });
}
