import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase = ({
  String name,
  // Optional sync-throw verifier for invalid `maxAttempts` rows.
  void Function()? assertSyncThrow,
  // Optional async path verifier for valid `maxAttempts` rows.
  Future<void> Function()? assertAsync,
});

void main() {
  group('retry', () {
    final testCases = <_TestCase>[
      (
        name: 'throws ArgumentError for zero attempts',
        assertSyncThrow: () {
          expect(
            () => retry<int, String>(
              () async => const Ok(42),
              maxAttempts: 0,
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
        assertAsync: null,
      ),
      (
        name: 'throws ArgumentError for negative attempts',
        assertSyncThrow: () {
          expect(
            () => retry<int, String>(
              () async => const Ok(42),
              maxAttempts: -1,
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
        assertAsync: null,
      ),
      (
        name: 'throws ArgumentError for very negative attempts',
        assertSyncThrow: () {
          expect(
            () => retry<int, String>(
              () async => const Ok(42),
              maxAttempts: -100,
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
        assertAsync: null,
      ),
      (
        name: 'returns success on the first attempt',
        assertSyncThrow: null,
        assertAsync: () async {
          var calls = 0;
          final result = await retry<int, String>(() async {
            calls++;
            return const Ok(42);
          });
          expect(result.expect(), 42);
          expect(calls, 1);
        },
      ),
      (
        name: 'returns success on the only attempt (maxAttempts: 1)',
        assertSyncThrow: null,
        assertAsync: () async {
          var calls = 0;
          final result = await retry<int, String>(
            () async {
              calls++;
              return const Ok(42);
            },
            maxAttempts: 1,
          );
          expect(result.expect(), 42);
          expect(calls, 1);
        },
      ),
      (
        name: 'returns eventual success and stops retrying',
        assertSyncThrow: null,
        assertAsync: () async {
          var calls = 0;
          final result = await retry<int, String>(
            () async {
              calls++;
              if (calls < 3) return Err<int, String>('attempt:$calls');
              return const Ok(42);
            },
            maxAttempts: 5,
          );
          expect(result.expect(), 42);
          expect(calls, 3);
        },
      ),
      (
        name: 'returns last failure after exhausting attempts',
        assertSyncThrow: null,
        assertAsync: () async {
          var calls = 0;
          final result = await retry<int, String>(
            () async {
              calls++;
              return Err<int, String>('attempt:$calls');
            },
          );
          expect(result.expectError(), 'attempt:3');
          expect(calls, 3);
        },
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        if (tc.assertSyncThrow != null) {
          tc.assertSyncThrow!();
          return;
        }
        await tc.assertAsync!();
      });
    }
  });
}
