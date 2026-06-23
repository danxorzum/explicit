import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase = ({
  String name,
  Future<(AsyncRes<int, String>, List<String>)> Function() build,
  Future<void> Function(AsyncRes<int, String>, List<String>) assertRow,
});

void main() {
  group('AsyncRes.run', () {
    final testCases = <_TestCase>[
      (
        name: 'does not run operation before run is called',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(() async {
              events.add('operation');
              return const Ok(42);
            }),
            events,
          );
        },
        assertRow: (res, events) async {
          // Laziness: constructing the AsyncRes must not execute the op.
          expect(events, isEmpty);

          final result = await res.run();

          expect(result.expect(), 42);
          expect(events, ['operation']);
        },
      ),
      (
        name: 'runs the underlying operation each time run is called',
        build: () async {
          final events = <String>[];
          var calls = 0;
          return (
            AsyncRes<int, String>(() async {
              calls++;
              events.add('operation:$calls');
              return Ok(calls);
            }),
            events,
          );
        },
        assertRow: (res, events) async {
          // Laziness before the first run.
          expect(events, isEmpty);

          final first = await res.run();
          final second = await res.run();

          expect(first.expect(), 1);
          expect(second.expect(), 2);
          expect(events, ['operation:1', 'operation:2']);
        },
      ),
      (
        name: 'propagates Err from the underlying operation',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(() async {
              events.add('operation');
              return const Err('boom');
            }),
            events,
          );
        },
        assertRow: (res, events) async {
          final result = await res.run();

          expect(result.expectError(), 'boom');
          expect(events, ['operation']);
        },
      ),
      (
        name: 'propagates exceptions thrown by the underlying operation',
        build: () async {
          final events = <String>[];
          return (
            AsyncRes<int, String>(() async {
              events.add('operation');
              throw StateError('unexpected throw');
            }),
            events,
          );
        },
        assertRow: (res, events) async {
          await expectLater(res.run(), throwsA(isA<StateError>()));

          // The op did start before throwing, so the marker is recorded.
          expect(events, ['operation']);
        },
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        final (res, events) = await tc.build();
        await tc.assertRow(res, events);
      });
    }
  });
}
