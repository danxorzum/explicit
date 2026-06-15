// Covers the `toString()` and `operator ==` members of `Ok` and `Err` that
// are not exercised by the behavior tests. Kept in TCT style to match the
// rest of the suite.

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _StringCase = ({
  String name,
  Result<dynamic, dynamic> input,
  String expected,
});

typedef _EqualityCase<T, E> = ({
  String name,
  Result<T, E> left,
  Result<T, E> right,
  bool expected,
});

void main() {
  group('Result.toString', () {
    final testCases = <_StringCase>[
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
        name: 'Ok renders negative as Ok(-1)',
        input: const Ok<int, String>(-1),
        expected: 'Ok(-1)',
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

    for (final tc in testCases) {
      test(tc.name, () {
        expect(tc.input.toString(), tc.expected);
      });
    }
  });

  group('Ok equality', () {
    final testCases = <_EqualityCase<int, String>>[
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
        name: 'Ok with zero and Ok with zero are equal',
        left: const Ok<int, String>(0),
        right: const Ok<int, String>(0),
        expected: true,
      ),
      (
        name: 'Ok and Err with the same payload are not equal',
        left: const Ok<int, String>(1),
        right: const Err<int, String>('1'),
        expected: false,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        expect(tc.left == tc.right, tc.expected);
      });
    }

    test('Ok is equal to itself (identical)', () {
      const ok = Ok<int, String>(99);
      expect(identical(ok, ok), isTrue);
      expect(ok == ok, isTrue);
    });

    test('Ok is not equal to a non-Ok object', () {
      const ok = Ok<int, String>(1);
      const Object notAResult = 'not a result';
      const Object notAResultInt = 1;
      expect(ok == notAResult, isFalse);
      expect(ok == notAResultInt, isFalse);
    });
  });

  group('Ok hashCode', () {
    test('equal Ok instances produce the same hashCode', () {
      const a = Ok<int, String>(42);
      const b = Ok<int, String>(42);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('Ok hashCode runs without throwing for zero and negative values', () {
      const zero = Ok<int, String>(0);
      const negative = Ok<int, String>(-1);
      expect(zero.hashCode, isA<int>());
      expect(negative.hashCode, isA<int>());
    });
  });
}
