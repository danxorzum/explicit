import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase = ({
  String name,
  Future<(AsyncRes<int, String>, List<String>)> Function() build,
  Future<void> Function(AsyncRes<int, String>, List<String>) assertRow,
});

void main() {
  group('AsyncRes.map', () {
    final testCases = <_TestCase>[
      (
        name: 'is lazy while composing',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('operation');
                return const Ok(20);
              },
            ).map((value) {
              events.add('map');
              return value + 22;
            }),
            events,
          );
        },
        assertRow: (mapped, events) async {
          // The operation is deferred until run is called.
          expect(events, isEmpty);

          final result = await mapped.run();

          expect(result.expect(), 42);
          expect(events, ['operation', 'map']);
        },
      ),
      (
        name: 'composes multiple map steps in declaration order',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
                  () async {
                    events.add('operation');
                    return const Ok(10);
                  },
                )
                .map((value) {
                  events.add('map:double');
                  return value * 2;
                })
                .map((value) {
                  events.add('map:add');
                  return value + 22;
                }),
            events,
          );
        },
        assertRow: (mapped, events) async {
          final result = await mapped.run();

          expect(result.expect(), 42);
          expect(
            events,
            ['operation', 'map:double', 'map:add'],
          );
        },
      ),
      (
        name: 'short-circuits Err without calling transform',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('operation');
                return const Err('boom');
              },
            ).map<int>((value) {
              events.add('map');
              // Returning -1 proves transform wasn't called: it would surface
              // as the wrapped value if it ran.
              return -1;
            }),
            events,
          );
        },
        assertRow: (mapped, events) async {
          final result = await mapped.run();

          expect(result.expectError(), 'boom');
          expect(events, ['operation']);
        },
      ),
      (
        name: 'preserves the error payload when Err short-circuits',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(
              () async {
                events.add('operation');
                return const Err('network:timeout');
              },
            ).map<int>((value) {
              events.add('map');
              return 0;
            }),
            events,
          );
        },
        assertRow: (mapped, events) async {
          final result = await mapped.run();

          expect(result.expectError(), 'network:timeout');
          expect(events, ['operation']);
        },
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        final (mapped, events) = await tc.build();
        await tc.assertRow(mapped, events);
      });
    }
  });
}
