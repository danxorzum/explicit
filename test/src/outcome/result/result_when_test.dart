import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E> = ({
  String name,
  Result<T, E> input,
  List<String> expectedEvents,
});

void main() {
  group('Result.when', () {
    final testCases = <_TestCase<int, String>>[
      (
        name: 'Ok runs only onSuccess',
        input: const Ok<int, String>(42),
        expectedEvents: ['success:42'],
      ),
      (
        name: 'Ok with zero runs only onSuccess',
        input: const Ok<int, String>(0),
        expectedEvents: ['success:0'],
      ),
      (
        name: 'Ok with negative runs only onSuccess',
        input: const Ok<int, String>(-3),
        expectedEvents: ['success:-3'],
      ),
      (
        name: 'Err runs only onError',
        input: const Err<int, String>('boom'),
        expectedEvents: ['error:boom'],
      ),
      (
        name: 'Err with empty error runs only onError',
        input: const Err<int, String>(''),
        expectedEvents: ['error:'],
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final events = <String>[];

        tc.input.when(
          onSuccess: (value) => events.add('success:$value'),
          onError: (error) => events.add('error:$error'),
        );

        expect(events, tc.expectedEvents);
      });
    }
  });
}
