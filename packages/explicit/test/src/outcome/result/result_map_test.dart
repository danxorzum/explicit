import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E, R> = ({
  String name,
  Result<T, E> input,
  R Function(T) transform,
  R expectedValue,
  String? expectedError,
  bool expectErr,
});

void main() {
  group('Result.map', () {
    final testCases = <_TestCase<int, String, int>>[
      (
        name: 'Ok case',
        input: const Ok<int, String>(21),
        transform: (value) => value * 2,
        expectedValue: 42,
        expectedError: null,
        expectErr: false,
      ),
      (
        name: 'Ok with zero value',
        input: const Ok<int, String>(0),
        transform: (value) => value + 1,
        expectedValue: 1,
        expectedError: null,
        expectErr: false,
      ),
      (
        name: 'Ok with negative value',
        input: const Ok<int, String>(-5),
        transform: (value) => value.abs(),
        expectedValue: 5,
        expectedError: null,
        expectErr: false,
      ),
      (
        name: 'Err case',
        input: const Err<int, String>('boom'),
        transform: (value) => throw StateError('must not run'),
        expectedValue: 0,
        expectedError: 'boom',
        expectErr: true,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final result = tc.input.map(tc.transform);

        if (tc.expectErr) {
          expect(result.expectError(), tc.expectedError);
        } else {
          expect(result.expect(), tc.expectedValue);
        }
      });
    }
  });
}
