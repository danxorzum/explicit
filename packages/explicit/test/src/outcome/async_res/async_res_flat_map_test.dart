import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase = ({
  String name,
  Future<(AsyncRes<int, String>, List<String>)> Function() build,
  Future<void> Function(AsyncRes<int, String>, List<String>) assertRow,
});

void main() {
  group('AsyncRes.flatMap', () {
    final testCases = <_TestCase>[
      (
        name: 'runs operations in declaration order',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('first');
                return const Ok(20);
              },
            ).flatMap((value) {
              events.add('build second:$value');
              return AsyncRes<int, String>(
                () async {
                  events.add('second');
                  return Ok(value + 22);
                },
              );
            }),
            events,
          );
        },
        assertRow: (chained, events) async {
          // The chained AsyncRes defers both steps until run is called.
          expect(events, isEmpty);

          final result = await chained.run();

          expect(result.expect(), 42);
          expect(
            events,
            ['first', 'build second:20', 'second'],
          );
        },
      ),
      (
        name: 'chains Ok into another Ok with zero seed value',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('first');
                return const Ok(0);
              },
            ).flatMap((value) {
              events.add('build second:$value');
              return AsyncRes<int, String>(
                () async {
                  events.add('second');
                  return Ok(value + 1);
                },
              );
            }),
            events,
          );
        },
        assertRow: (chained, events) async {
          final result = await chained.run();

          expect(result.expect(), 1);
          expect(events, ['first', 'build second:0', 'second']);
        },
      ),
      (
        name: 'short-circuits Err without building the next AsyncRes',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('first');
                return const Err('boom');
              },
            ).flatMap<int>((value) {
              events.add('build second');
              return AsyncRes<int, String>(
                () async {
                  events.add('second');
                  // Returning Ok(0) proves the second op wasn't built: this
                  // success value would surface as the wrapped value if it ran.
                  return const Ok(0);
                },
              );
            }),
            events,
          );
        },
        assertRow: (chained, events) async {
          final result = await chained.run();

          expect(result.expectError(), 'boom');
          expect(events, ['first']);
        },
      ),
      (
        name: 'preserves Err payload when short-circuiting',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('first');
                return const Err('network:reset');
              },
            ).flatMap<int>((value) {
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

          expect(result.expectError(), 'network:reset');
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
