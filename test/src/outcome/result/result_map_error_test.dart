import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E, R> = ({
  String name,
  Result<T, E> input,
  R Function(E) transform,
  T expectedValue,
  R? expectedError,
  bool expectOk,
});

void main() {
  group('Result.mapError', () {
    final testCases = <_TestCase<int, String, String>>[
      (
        name: 'Ok case',
        input: const Ok<int, String>(42),
        transform: (error) => throw StateError('must not run'),
        expectedValue: 42,
        expectedError: null,
        expectOk: true,
      ),
      (
        name: 'Ok with zero value',
        input: const Ok<int, String>(0),
        transform: (error) => throw StateError('must not run'),
        expectedValue: 0,
        expectedError: null,
        expectOk: true,
      ),
      (
        name: 'Err case',
        input: const Err<int, String>('timeout'),
        transform: (error) => 'network:$error',
        expectedValue: 0,
        expectedError: 'network:timeout',
        expectOk: false,
      ),
      (
        name: 'Err with empty error',
        input: const Err<int, String>(''),
        transform: (error) => '[$error]',
        expectedValue: 0,
        expectedError: '[]',
        expectOk: false,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final result = tc.input.mapError(tc.transform);

        if (tc.expectOk) {
          expect(result.expect(), tc.expectedValue);
        } else {
          expect(result.expectError(), tc.expectedError);
        }
      });
    }
  });
}
