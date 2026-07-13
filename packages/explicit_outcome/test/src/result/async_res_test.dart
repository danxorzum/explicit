import 'package:explicit_outcome/explicit_outcome.dart';
import 'package:test/test.dart';

typedef _AsyncResCase = ({
  String name,
  Future<(AsyncRes<int, String>, List<String>)> Function() build,
  Future<void> Function(AsyncRes<int, String>, List<String>) assertRow,
});

void main() {
  group('AsyncRes.run', () {
    final testCases = <_AsyncResCase>[
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
          expect(events, isEmpty);

          final result = await res.run();

          expect(result, const Ok<int, String>(42));
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
          expect(events, isEmpty);

          final first = await res.run();
          final second = await res.run();

          expect(first, const Ok<int, String>(1));
          expect(second, const Ok<int, String>(2));
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

          expect(result, const Err<int, String>('boom'));
          expect(events, ['operation']);
        },
      ),
      (
        name: 'propagates exceptions thrown by the source operation',
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

  group('AsyncRes.map', () {
    test('is lazy and transforms Ok values in declaration order', () async {
      final events = <String>[];
      final mapped = AsyncRes<int, String>(() async {
        events.add('operation');
        return const Ok(20);
      }).map((value) {
        events.add('map');
        return value + 22;
      });

      expect(events, isEmpty);

      final result = await mapped.run();

      expect(result, const Ok<int, String>(42));
      expect(events, ['operation', 'map']);
    });

    test('composes multiple map steps in declaration order', () async {
      final events = <String>[];
      final mapped = AsyncRes<int, String>(() async {
        events.add('operation');
        return const Ok(10);
      }).map((value) {
        events.add('map:double');
        return value * 2;
      }).map((value) {
        events.add('map:add');
        return value + 22;
      });

      final result = await mapped.run();

      expect(result, const Ok<int, String>(42));
      expect(events, ['operation', 'map:double', 'map:add']);
    });

    test('short-circuits Err without calling transform', () async {
      final events = <String>[];
      final mapped = AsyncRes<int, String>(() async {
        events.add('operation');
        return const Err('boom');
      }).map<int>((value) {
        events.add('map');
        return -1;
      });

      final result = await mapped.run();

      expect(result, const Err<int, String>('boom'));
      expect(events, ['operation']);
    });

    test('propagates exceptions thrown by the transform', () async {
      final error = StateError('map failed');
      final throwing = AsyncRes<int, String>(() async => const Ok(1)).map<int>((
        _,
      ) {
        throw error;
      });

      await expectLater(throwing.run(), throwsA(same(error)));
    });
  });

  group('AsyncRes.next', () {
    test('chains Ok values lazily in declaration order', () async {
      final events = <String>[];
      final chained = AsyncRes<int, String>(() async {
        events.add('first');
        return const Ok(20);
      }).next((value) {
        events.add('build second:$value');
        return AsyncRes<int, String>(() async {
          events.add('second');
          return Ok(value + 22);
        });
      });

      expect(events, isEmpty);

      final result = await chained.run();

      expect(result, const Ok<int, String>(42));
      expect(events, ['first', 'build second:20', 'second']);
    });

    test('chains Ok to Err through next callback', () async {
      final events = <String>[];
      final chained = AsyncRes<int, String>(() async {
        events.add('first');
        return const Ok(0);
      }).next((value) {
        events.add('build second:$value');
        return AsyncRes<int, String>(
          () async => const Err('zero is invalid'),
        );
      });

      final result = await chained.run();

      expect(result, const Err<int, String>('zero is invalid'));
      expect(events, ['first', 'build second:0']);
    });

    test('short-circuits Err without building the next AsyncRes', () async {
      final events = <String>[];
      final chained = AsyncRes<int, String>(() async {
        events.add('first');
        return const Err('boom');
      }).next<int>((value) {
        events.add('build second');
        return AsyncRes<int, String>(() async {
          events.add('second');
          return const Ok(0);
        });
      });

      final result = await chained.run();

      expect(result, const Err<int, String>('boom'));
      expect(events, ['first']);
    });

    test('propagates exceptions thrown by the next callback', () async {
      final error = StateError('next failed');
      final throwing = AsyncRes<int, String>(
        () async => const Ok(1),
      ).next<int>((_) {
        throw error;
      });

      await expectLater(throwing.run(), throwsA(same(error)));
    });
  });

  group('AsyncRes.mapError', () {
    test('preserves Ok values without running the callback', () async {
      final events = <String>[];
      final mapped = AsyncRes<int, String>(() async {
        events.add('operation');
        return const Ok(42);
      }).mapError((error) {
        events.add('unexpected:$error');
        return error.length;
      });

      final result = await mapped.run();

      expect(result, const Ok<int, int>(42));
      expect(events, ['operation']);
    });

    test('transforms Err error values', () async {
      final events = <String>[];
      final mapped = AsyncRes<int, String>(() async {
        events.add('operation');
        return const Err('timeout');
      }).mapError((error) {
        events.add('mapError:$error');
        return 'network:$error';
      });

      final result = await mapped.run();

      expect(result, const Err<int, String>('network:timeout'));
      expect(events, ['operation', 'mapError:timeout']);
    });

    test('propagates exceptions thrown by the error transform', () async {
      final error = StateError('mapError failed');
      final throwing = AsyncRes<int, String>(
        () async => const Err('boom'),
      ).mapError<String>((_) {
        throw error;
      });

      await expectLater(throwing.run(), throwsA(same(error)));
    });
  });

  group('AsyncRes.or', () {
    test('returns Ok without evaluating fallback', () async {
      final events = <String>[];
      final res = AsyncRes<int, String>(() async {
        events.add('operation');
        return const Ok(42);
      }).or((error) {
        events.add('unexpected:$error');
        return AsyncRes<int, String>(() async => Ok(error.length));
      });

      final result = await res.run();

      expect(result, const Ok<int, String>(42));
      expect(events, ['operation']);
    });

    test('evaluates fallback for Err and can recover to Ok', () async {
      final events = <String>[];
      final res = AsyncRes<int, String>(() async {
        events.add('operation');
        return const Err('timeout');
      }).or((error) {
        events.add('build fallback:$error');
        return AsyncRes<int, String>(() async {
          events.add('fallback');
          return Ok(error.length);
        });
      });

      final result = await res.run();

      expect(result, const Ok<int, String>(7));
      expect(events, ['operation', 'build fallback:timeout', 'fallback']);
    });

    test('evaluates fallback for Err and can remain Err', () async {
      final events = <String>[];
      final res = AsyncRes<int, String>(() async {
        events.add('operation');
        return const Err('timeout');
      }).or((error) {
        events.add('build fallback:$error');
        return AsyncRes<int, String>(
          () async => Err('recovered:$error'),
        );
      });

      final result = await res.run();

      expect(result, const Err<int, String>('recovered:timeout'));
      expect(events, ['operation', 'build fallback:timeout']);
    });

    test('propagates exceptions thrown by the fallback', () async {
      final error = StateError('fallback failed');
      final throwing = AsyncRes<int, String>(
        () async => const Err('boom'),
      ).or((_) {
        throw error;
      });

      await expectLater(throwing.run(), throwsA(same(error)));
    });
  });

  group('ResultAsync typedef', () {
    test('resolves to Future<Res<T, E>>', () async {
      // Explicit type proves the ResultAsync typedef resolves correctly.
      // ignore: omit_local_variable_types
      final ResultAsync<int, String> future = Future.value(
        const Ok<int, String>(42),
      );

      final result = await future;

      expect(result, const Ok<int, String>(42));
    });

    test('AsyncRes.run returns a ResultAsync', () async {
      final res = AsyncRes<int, String>(() async => const Ok(7));

      // Explicit type proves run() returns the ResultAsync typedef.
      // ignore: omit_local_variable_types
      final ResultAsync<int, String> future = res.run();
      final result = await future;

      expect(result, const Ok<int, String>(7));
    });
  });
}
