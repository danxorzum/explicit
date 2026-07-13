import 'dart:io';

import 'package:explicit_outcome/explicit_outcome.dart';
import 'package:test/test.dart';

String get _packageRoot => Directory('packages/explicit_outcome').existsSync()
    ? 'packages/explicit_outcome'
    : '.';

typedef _ResultCase = ({
  String name,
  Result<int, String> input,
  bool isSuccess,
  bool isFailure,
  String folded,
  int fallbackValue,
});

typedef _TransformCase = ({
  String name,
  Result<int, String> input,
  Result<int, String> Function(Result<int, String>) act,
  int? expectedValue,
  String? expectedError,
});

typedef _AliasCase<T extends Object, E extends Object> = ({
  String name,
  Result<T, E> Function() build,
  bool isOk,
  T? expectedValue,
  E? expectedError,
});

typedef _StringCase = ({
  String name,
  Result<dynamic, dynamic> input,
  String expected,
});

typedef _EqualityCase<T extends Object, E extends Object> = ({
  String name,
  Result<T, E> left,
  Result<T, E> right,
  bool expected,
});

void main() {
  group('Result/Res', () {
    final resultCases = <_ResultCase>[
      (
        name: 'Ok reports success and returns the success branch value',
        input: const Ok<int, String>(42),
        isSuccess: true,
        isFailure: false,
        folded: 'success:42',
        fallbackValue: 42,
      ),
      (
        name: 'Ok with zero remains an explicit success',
        input: const Ok<int, String>(0),
        isSuccess: true,
        isFailure: false,
        folded: 'success:0',
        fallbackValue: 0,
      ),
      (
        name: 'Err reports failure and returns fallback from error',
        input: const Err<int, String>('missing'),
        isSuccess: false,
        isFailure: true,
        folded: 'error:missing',
        fallbackValue: 7,
      ),
      (
        name: 'Err with empty error remains an explicit failure',
        input: const Err<int, String>(''),
        isSuccess: false,
        isFailure: true,
        folded: 'error:',
        fallbackValue: -1,
      ),
    ];

    for (final tc in resultCases) {
      test(tc.name, () {
        expect(tc.input.isSuccess, tc.isSuccess);
        expect(tc.input.isFailure, tc.isFailure);
        expect(
          tc.input.fold(
            onSuccess: (value) => 'success:$value',
            onError: (error) => 'error:$error',
          ),
          tc.folded,
        );
        expect(
          tc.input.getOrElse((error) => error.isEmpty ? -1 : error.length),
          tc.fallbackValue,
        );
      });
    }

    test('when executes only the matching branch', () {
      final events = <String>[];

      const Ok<int, String>(7).when(
        onSuccess: (value) => events.add('success:$value'),
        onError: (error) => events.add('unexpected:$error'),
      );
      const Err<int, String>('boom').when(
        onSuccess: (value) => events.add('unexpected:$value'),
        onError: (error) => events.add('error:$error'),
      );

      expect(events, ['success:7', 'error:boom']);
    });

    final transformCases = <_TransformCase>[
      (
        name: 'map transforms Ok values',
        input: const Ok<int, String>(21),
        act: (result) => result.map((value) => value * 2),
        expectedValue: 42,
        expectedError: null,
      ),
      (
        name: 'map preserves Err values without running the callback',
        input: const Err<int, String>('boom'),
        act: (result) => result.map((_) => throw StateError('must not run')),
        expectedValue: null,
        expectedError: 'boom',
      ),
      (
        name: 'next chains Ok to another Ok',
        input: const Ok<int, String>(20),
        act: (result) => result.next((value) => Ok(value + 22)),
        expectedValue: 42,
        expectedError: null,
      ),
      (
        name: 'next can chain Ok to Err',
        input: const Ok<int, String>(0),
        act: (result) => result.next(
              (_) => const Err<int, String>('zero is invalid'),
            ),
        expectedValue: null,
        expectedError: 'zero is invalid',
      ),
      (
        name: 'next short-circuits Err without running the callback',
        input: const Err<int, String>('original'),
        act: (result) => result.next(
              (_) => throw StateError('must not run'),
            ),
        expectedValue: null,
        expectedError: 'original',
      ),
      (
        name: 'mapError preserves Ok values without running the callback',
        input: const Ok<int, String>(42),
        act: (result) => result.mapError(
              (_) => throw StateError('must not run'),
            ),
        expectedValue: 42,
        expectedError: null,
      ),
      (
        name: 'mapError transforms Err values',
        input: const Err<int, String>('timeout'),
        act: (result) => result.mapError((error) => 'network:$error'),
        expectedValue: null,
        expectedError: 'network:timeout',
      ),
    ];

    for (final tc in transformCases) {
      test(tc.name, () {
        final result = tc.act(tc.input);

        if (tc.expectedError == null) {
          expect(
            result.fold(onSuccess: (v) => v, onError: (_) => null),
            tc.expectedValue,
          );
        } else {
          expect(
            result.fold(onSuccess: (_) => null, onError: (e) => e),
            tc.expectedError,
          );
        }
      });
    }

    test('next only runs callback for Ok and short-circuits Err', () {
      final events = <String>[];

      final success = const Ok<int, String>(20).next((value) {
        events.add('next:$value');
        return Ok(value + 22);
      });
      final failure = const Err<int, String>('blocked').next((value) {
        events.add('unexpected:$value');
        return Ok(value + 22);
      });

      expect(
        success.fold(onSuccess: (v) => v, onError: (_) => null),
        42,
      );
      expect(
        failure.fold(onSuccess: (_) => null, onError: (e) => e),
        'blocked',
      );
      expect(events, ['next:20']);
    });

    test('or preserves Ok without calling fallback', () {
      var fallbackCalled = false;

      final result = const Ok<int, String>(42).or((error) {
        fallbackCalled = true;
        return Ok(error.length);
      });

      expect(fallbackCalled, isFalse);
      expect(result, isA<Ok<int, String>>());
      expect(
        result.fold(onSuccess: (v) => v, onError: (_) => null),
        42,
      );
    });

    test('or calls fallback on Err and can recover to Ok', () {
      final result = const Err<int, String>('timeout').or((error) {
        return Ok(error.length);
      });

      expect(result, isA<Ok<int, String>>());
      expect(
        result.fold(onSuccess: (v) => v, onError: (_) => null),
        7,
      );
    });

    test('or calls fallback on Err and can remain Err', () {
      final result = const Err<int, String>('timeout').or((error) {
        return Err<int, String>('recovered:$error');
      });

      expect(result, isA<Err<int, String>>());
      expect(
        result.fold(onSuccess: (_) => null, onError: (e) => e),
        'recovered:timeout',
      );
    });

    final aliasCases = <_AliasCase<int, String>>[
      (
        name: 'Res remains a public short alias for Result',
        build: () => const Ok<int, String>(42) as Res<int, String>,
        isOk: true,
        expectedValue: 42,
        expectedError: null,
      ),
      (
        name: 'Success constructs an Ok-compatible success result',
        build: () => const Success<int, String>(0),
        isOk: true,
        expectedValue: 0,
        expectedError: null,
      ),
      (
        name: 'Failure constructs an Err-compatible failure result',
        build: () => const Failure<int, String>('boom'),
        isOk: false,
        expectedValue: null,
        expectedError: 'boom',
      ),
      (
        name: 'Failure preserves empty error values',
        build: () => const Failure<int, String>(''),
        isOk: false,
        expectedValue: null,
        expectedError: '',
      ),
    ];

    for (final tc in aliasCases) {
      test(tc.name, () {
        final result = tc.build();

        if (tc.isOk) {
          expect(result, isA<Ok<int, String>>());
          expect(
            result.fold(onSuccess: (v) => v, onError: (_) => null),
            tc.expectedValue,
          );
        } else {
          expect(result, isA<Err<int, String>>());
          expect(
            result.fold(onSuccess: (_) => null, onError: (e) => e),
            tc.expectedError,
          );
        }
      });
    }

    test('analyzer rejects nullable generic contracts', () async {
      final fixture = File(
        '$_packageRoot/test/src/result/.nullable_contract_fixture.dart',
      );
      addTearDown(() async {
        if (fixture.existsSync()) await fixture.delete();
      });

      const source = '''
// ignore_for_file: avoid_print, file_names, prefer_const_constructors

import 'package:explicit_outcome/explicit_outcome.dart';

void main() {
  final result = <Result<int?, String>?>[];
  final res = <Res<int, String?>?>[];
  final ok = Ok(null);
  final err = Err(null);

  print((result, res, ok, err));
}
''';
      await fixture.writeAsString(source);

      final result = await Process.run(
        'dart',
        ['analyze', fixture.path],
        workingDirectory: Directory.current.path,
      );
      final output = '${result.stdout}\n${result.stderr}';

      expect(result.exitCode, isNot(0));
      expect(source, contains('Ok(null)'));
      expect(source, contains('Err(null)'));
      expect(output, contains('Result<int?, String>'));
      expect(output, contains('Res<int, String?>'));
      expect(output, contains('type_argument_not_matching_bounds'));
      expect(output, contains("'Null' doesn't conform to the bound 'Object'"));
    });
  });

  group('Result equality and display', () {
    final stringCases = <_StringCase>[
      (
        name: 'Ok renders as Ok(<value>)',
        input: const Ok<int, String>(42),
        expected: 'Ok(42)',
      ),
      (
        name: 'Ok renders zero as Ok(0)',
        input: const Ok<int, String>(0),
        expected: 'Ok(0)',
      ),
      (
        name: 'Err renders as Err(<error>)',
        input: const Err<int, String>('boom'),
        expected: 'Err(boom)',
      ),
      (
        name: 'Err renders empty error as Err()',
        input: const Err<int, String>(''),
        expected: 'Err()',
      ),
    ];

    for (final tc in stringCases) {
      test(tc.name, () {
        expect(tc.input.toString(), tc.expected);
      });
    }

    final equalityCases = <_EqualityCase<int, String>>[
      (
        name: 'two Ok with the same value are equal',
        left: const Ok<int, String>(42),
        right: const Ok<int, String>(42),
        expected: true,
      ),
      (
        name: 'two Ok with different values are not equal',
        left: const Ok<int, String>(42),
        right: const Ok<int, String>(7),
        expected: false,
      ),
      (
        name: 'Ok and Err with equivalent payload text are not equal',
        left: const Ok<int, String>(1),
        right: const Err<int, String>('1'),
        expected: false,
      ),
      (
        name: 'two Err with the same error are equal',
        left: const Err<int, String>('boom'),
        right: const Err<int, String>('boom'),
        expected: true,
      ),
      (
        name: 'two Err with different errors are not equal',
        left: const Err<int, String>('boom'),
        right: const Err<int, String>('other'),
        expected: false,
      ),
      (
        name: 'Err and Ok with equivalent payload text are not equal',
        left: const Err<int, String>('1'),
        right: const Ok<int, String>(1),
        expected: false,
      ),
    ];

    for (final tc in equalityCases) {
      test(tc.name, () {
        expect(tc.left == tc.right, tc.expected);
      });
    }

    test('Ok equality handles identity, non-Ok objects, and hashCode', () {
      const ok = Ok<int, String>(42);

      expect(identical(ok, ok), isTrue);
      expect(ok == ok, isTrue);
      expect(ok == const Object(), isFalse);
      expect(ok.hashCode, const Ok<int, String>(42).hashCode);
      expect(const Ok<int, String>(0).hashCode, isA<int>());
      expect(const Ok<int, String>(-1).hashCode, isA<int>());
    });

    test('Err equality handles identity, non-Err objects, and hashCode', () {
      const err = Err<int, String>('boom');

      expect(identical(err, err), isTrue);
      expect(err == err, isTrue);
      expect(err == const Object(), isFalse);
      expect(err.hashCode, const Err<int, String>('boom').hashCode);
      expect(const Err<int, String>('').hashCode, isA<int>());
      expect(const Err<int, String>('boom').hashCode, isA<int>());
    });
  });
}
