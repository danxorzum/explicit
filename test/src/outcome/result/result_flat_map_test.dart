import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, R, E> = ({
  String name,
  Result<T, E> input,
  Result<R, E> Function(T) chain,
  R expectedValue,
  E? expectedError,
  bool expectOk,
});

void main() {
  group('Result.flatMap', () {
    final testCases = <_TestCase<int, int, String>>[
      (
        name: 'Ok chains to another Ok',
        input: const Ok<int, String>(20),
        chain: (value) => Ok<int, String>(value + 22),
        expectedValue: 42,
        expectedError: null,
        expectOk: true,
      ),
      (
        name: 'Ok with zero chains to Err',
        input: const Ok<int, String>(0),
        chain: (value) => const Err<int, String>('zero is invalid'),
        expectedValue: 0,
        expectedError: 'zero is invalid',
        expectOk: false,
      ),
      (
        name: 'Ok chains to Ok with same value',
        input: const Ok<int, String>(7),
        chain: Ok<int, String>.new,
        expectedValue: 7,
        expectedError: null,
        expectOk: true,
      ),
      (
        name: 'Ok chains to Err from a non-trivial value',
        input: const Ok<int, String>(20),
        chain: (value) => const Err<int, String>('too small'),
        expectedValue: 0,
        expectedError: 'too small',
        expectOk: false,
      ),
      (
        name: 'Err short-circuits without calling next operation',
        input: const Err<int, String>('original'),
        chain: (value) => throw StateError('must not run'),
        expectedValue: 0,
        expectedError: 'original',
        expectOk: false,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final result = tc.input.flatMap(tc.chain);

        if (tc.expectOk) {
          expect(result.expect(), tc.expectedValue);
        } else {
          expect(result.expectError(), tc.expectedError);
        }
      });
    }
  });
}
