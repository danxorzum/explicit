import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E> = ({
  String name,
  Result<T, E> input,
  T Function(E) fallback,
  T expected,
});

void main() {
  group('Result.getOrElse', () {
    final testCases = <_TestCase<int, String>>[
      (
        name: 'Ok returns value without calling fallback',
        input: const Ok<int, String>(42),
        fallback: (error) => throw StateError('must not run'),
        expected: 42,
      ),
      (
        name: 'Ok with zero returns zero',
        input: const Ok<int, String>(0),
        fallback: (error) => throw StateError('must not run'),
        expected: 0,
      ),
      (
        name: 'Ok with negative returns negative',
        input: const Ok<int, String>(-7),
        fallback: (error) => throw StateError('must not run'),
        expected: -7,
      ),
      (
        name: 'Err returns fallback computed from error',
        input: const Err<int, String>('missing'),
        fallback: (error) => error.length,
        expected: 7,
      ),
      (
        name: 'Err with empty error returns fallback from empty input',
        input: const Err<int, String>(''),
        fallback: (error) => -1,
        expected: -1,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final value = tc.input.getOrElse(tc.fallback);

        expect(value, tc.expected);
      });
    }
  });
}
