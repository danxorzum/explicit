// The deprecated toRecord API is intentionally covered for compatibility.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E> = ({
  String name,
  Result<T, E> input,
  (T?, E?) expected,
});

void main() {
  group('Result.toRecord', () {
    final testCases = <_TestCase<int, String>>[
      (
        name: 'Ok with value returns value and null error',
        input: const Ok<int, String>(42),
        expected: (42, null),
      ),
      (
        name: 'Ok with zero returns zero and null error',
        input: const Ok<int, String>(0),
        expected: (0, null),
      ),
      (
        name: 'Ok with negative returns negative and null error',
        input: const Ok<int, String>(-1),
        expected: (-1, null),
      ),
      (
        name: 'Err with error returns null value and error',
        input: const Err<int, String>('failure'),
        expected: (null, 'failure'),
      ),
      (
        name: 'Err with empty error returns null value and empty error',
        input: const Err<int, String>(''),
        expected: (null, ''),
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final record = tc.input.toRecord();

        expect(record, tc.expected);
      });
    }
  });
}
