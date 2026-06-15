import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E> = ({
  String name,
  Result<T, E> input,
  E? expected,
  bool throwsStateError,
});

void main() {
  group('Result.expectError', () {
    final testCases = <_TestCase<int, String>>[
      (
        name: 'Err returns the wrapped error',
        input: const Err<int, String>('boom'),
        expected: 'boom',
        throwsStateError: false,
      ),
      (
        name: 'Err with empty error returns empty string',
        input: const Err<int, String>(''),
        expected: '',
        throwsStateError: false,
      ),
      (
        name: 'Ok throws StateError',
        input: const Ok<int, String>(42),
        expected: null,
        throwsStateError: true,
      ),
      (
        name: 'Ok with zero throws StateError',
        input: const Ok<int, String>(0),
        expected: null,
        throwsStateError: true,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        if (tc.throwsStateError) {
          expect(tc.input.expectError, throwsA(isA<StateError>()));
        } else {
          expect(tc.input.expectError(), tc.expected);
        }
      });
    }
  });
}
