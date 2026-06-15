// Deprecated aliases are the behavior under test in this file.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E> = ({
  String name,
  Result<T, E> Function() build,
  bool isOk,
  T? expectedValue,
  E? expectedError,
});

void main() {
  group('deprecated compatibility aliases', () {
    final testCases = <_TestCase<int, String>>[
      (
        name: 'Success constructs an Ok-compatible success result',
        build: () => const Success<int, String>(42),
        isOk: true,
        expectedValue: 42,
        expectedError: null,
      ),
      (
        name: 'Success with zero constructs an Ok-compatible success result',
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
        name: 'Failure with empty error constructs an Err-compatible result',
        build: () => const Failure<int, String>(''),
        isOk: false,
        expectedValue: null,
        expectedError: '',
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final result = tc.build();

        if (tc.isOk) {
          expect(result, isA<Ok<int, String>>());
          expect(result.expect(), tc.expectedValue);
        } else {
          expect(result, isA<Err<int, String>>());
          expect(result.expectError(), tc.expectedError);
        }
      });
    }
  });
}
