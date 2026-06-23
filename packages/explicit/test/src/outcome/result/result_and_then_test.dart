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
  group('Result.andThen', () {
    final testCases = <_TestCase<int, int, String>>[
      (
        name: 'Ok aliases flatMap with chained Ok',
        input: const Ok<int, String>(40),
        chain: (value) => Ok<int, String>(value + 2),
        expectedValue: 42,
        expectedError: null,
        expectOk: true,
      ),
      (
        name: 'Ok with zero aliases flatMap with chained Err',
        input: const Ok<int, String>(0),
        chain: (value) => const Err<int, String>('zero rejected'),
        expectedValue: 0,
        expectedError: 'zero rejected',
        expectOk: false,
      ),
      (
        name: 'Err aliases flatMap short-circuit behavior',
        input: const Err<int, String>('blocked'),
        chain: (value) => throw StateError('must not run'),
        expectedValue: 0,
        expectedError: 'blocked',
        expectOk: false,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final result = tc.input.andThen(tc.chain);

        if (tc.expectOk) {
          expect(result.expect(), tc.expectedValue);
        } else {
          expect(result.expectError(), tc.expectedError);
        }
      });
    }
  });
}
