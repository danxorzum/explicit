import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E> = ({
  String name,
  Result<T, E> input,
  T? expected,
  bool throwsStateError,
});

void main() {
  group('Result.expect', () {
    final testCases = <_TestCase<int, String>>[
      (
        name: 'Ok returns the wrapped value',
        input: const Ok<int, String>(42),
        expected: 42,
        throwsStateError: false,
      ),
      (
        name: 'Ok with zero returns zero',
        input: const Ok<int, String>(0),
        expected: 0,
        throwsStateError: false,
      ),
      (
        name: 'Ok with negative returns negative',
        input: const Ok<int, String>(-1),
        expected: -1,
        throwsStateError: false,
      ),
      (
        name: 'Err throws StateError',
        input: const Err<int, String>('boom'),
        expected: null,
        throwsStateError: true,
      ),
      (
        name: 'Err with empty error throws StateError',
        input: const Err<int, String>(''),
        expected: null,
        throwsStateError: true,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        if (tc.throwsStateError) {
          expect(tc.input.expect, throwsA(isA<StateError>()));
        } else {
          expect(tc.input.expect(), tc.expected);
        }
      });
    }
  });
}
