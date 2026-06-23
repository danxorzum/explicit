import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase = ({
  String name,
  Future<(AsyncRes<int, String>, List<String>)> Function() build,
  Future<void> Function(AsyncRes<int, String>, List<String>) assertRow,
});

void main() {
  group('AsyncRes.andThen', () {
    final testCases = <_TestCase>[
      (
        name: 'aliases flatMap success composition',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('first');
                return const Ok(40);
              },
            ).andThen((value) {
              events.add('build second:$value');
              return AsyncRes<int, String>(
                () async {
                  events.add('second');
                  return Ok(value + 2);
                },
              );
            }),
            events,
          );
        },
        assertRow: (chained, events) async {
          expect(events, isEmpty);

          final result = await chained.run();

          expect(result.expect(), 42);
          expect(
            events,
            ['first', 'build second:40', 'second'],
          );
        },
      ),
      (
        name: 'aliases flatMap short-circuit behavior on Err',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('first');
                return const Err('blocked');
              },
            ).andThen<int>((value) {
              events.add('build second');
              return AsyncRes<int, String>(
                () async {
                  events.add('second');
                  return const Ok(0);
                },
              );
            }),
            events,
          );
        },
        assertRow: (chained, events) async {
          final result = await chained.run();

          expect(result.expectError(), 'blocked');
          expect(events, ['first']);
        },
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        final (chained, events) = await tc.build();
        await tc.assertRow(chained, events);
      });
    }
  });
}
