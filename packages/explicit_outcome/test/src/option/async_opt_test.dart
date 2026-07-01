import 'package:explicit_outcome/explicit_outcome.dart';
import 'package:test/test.dart';

typedef _AsyncOptCase = ({
  String name,
  Future<(AsyncOpt<int>, List<String>)> Function() build,
  Future<void> Function(AsyncOpt<int>, List<String>) assertRow,
});

void main() {
  group('AsyncOpt.run', () {
    final testCases = <_AsyncOptCase>[
      (
        name: 'does not run operation before run is called',
        build: () async {
          final events = <String>[];
          return (
            AsyncOpt<int>(() async {
              events.add('operation');
              return const Val(42);
            }),
            events,
          );
        },
        assertRow: (option, events) async {
          expect(events, isEmpty);

          final result = await option.run();

          expect(result, const Val(42));
          expect(events, ['operation']);
        },
      ),
      (
        name: 'runs the underlying operation each time run is called',
        build: () async {
          final events = <String>[];
          var calls = 0;
          return (
            AsyncOpt<int>(() async {
              calls++;
              events.add('operation:$calls');
              return Val(calls);
            }),
            events,
          );
        },
        assertRow: (option, events) async {
          expect(events, isEmpty);

          final first = await option.run();
          final second = await option.run();

          expect(first, const Val(1));
          expect(second, const Val(2));
          expect(events, ['operation:1', 'operation:2']);
        },
      ),
      (
        name: 'propagates exceptions thrown by the source operation',
        build: () async {
          final events = <String>[];
          final error = StateError('source failed');
          return (
            AsyncOpt<int>(() async {
              events.add('operation');
              throw error;
            }),
            events,
          );
        },
        assertRow: (option, events) async {
          await expectLater(option.run(), throwsA(isA<StateError>()));

          expect(events, ['operation']);
        },
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        final (option, events) = await tc.build();
        await tc.assertRow(option, events);
      });
    }
  });

  group('AsyncOpt.map', () {
    test(
      'is lazy and transforms present values in declaration order',
      () async {
        final events = <String>[];
        final mapped =
            AsyncOpt<int>(() async {
              events.add('operation');
              return const Val(20);
            }).map((value) {
              events.add('map');
              return value + 22;
            });

        expect(events, isEmpty);

        final result = await mapped.run();

        expect(result, const Val(42));
        expect(events, ['operation', 'map']);
      },
    );

    test('preserves nil and propagates transform exceptions', () async {
      final nilEvents = <String>[];
      final absent =
          AsyncOpt<int>(() async {
            nilEvents.add('operation');
            return const Nil<int>();
          }).map((value) {
            nilEvents.add('unexpected:$value');
            return value + 1;
          });

      expect(await absent.run(), const Nil<int>());
      expect(nilEvents, ['operation']);

      final error = StateError('map failed');
      final throwing = AsyncOpt<int>(() async => const Val(1)).map<int>((_) {
        throw error;
      });

      await expectLater(throwing.run(), throwsA(same(error)));
    });
  });

  group('AsyncOpt.next', () {
    test('chains present values lazily in declaration order', () async {
      final events = <String>[];
      final chained =
          AsyncOpt<int>(() async {
            events.add('first');
            return const Val(20);
          }).next((value) {
            events.add('build second:$value');
            return AsyncOpt<int>(() async {
              events.add('second');
              return Val(value + 22);
            });
          });

      expect(events, isEmpty);

      final result = await chained.run();

      expect(result, const Val(42));
      expect(events, ['first', 'build second:20', 'second']);
    });

    test('short-circuits nil and propagates callback exceptions', () async {
      final events = <String>[];
      final absent =
          AsyncOpt<int>(() async {
            events.add('first');
            return const Nil<int>();
          }).next((value) {
            events.add('unexpected:$value');
            return AsyncOpt<int>(() async => const Val(0));
          });

      expect(await absent.run(), const Nil<int>());
      expect(events, ['first']);

      final error = StateError('next failed');
      final throwing = AsyncOpt<int>(() async => const Val(1)).next<int>((_) {
        throw error;
      });

      await expectLater(throwing.run(), throwsA(same(error)));
    });
  });

  group('AsyncOpt.or', () {
    test('returns present values without evaluating fallback', () async {
      final events = <String>[];
      final option =
          AsyncOpt<int>(() async {
            events.add('operation');
            return const Val(42);
          }).or(() {
            events.add('unexpected');
            return AsyncOpt<int>(() async => const Val(0));
          });

      final result = await option.run();

      expect(result, const Val(42));
      expect(events, ['operation']);
    });

    test(
      'evaluates fallback for nil and propagates fallback exceptions',
      () async {
        final events = <String>[];
        final option =
            AsyncOpt<int>(() async {
              events.add('operation');
              return const Nil<int>();
            }).or(() {
              events.add('build fallback');
              return AsyncOpt<int>(() async {
                events.add('fallback');
                return const Val(7);
              });
            });

        expect(await option.run(), const Val(7));
        expect(events, ['operation', 'build fallback', 'fallback']);

        final error = StateError('fallback failed');
        final throwing = AsyncOpt<int>(() async => const Nil<int>()).or(() {
          throw error;
        });

        await expectLater(throwing.run(), throwsA(same(error)));
      },
    );
  });

  group('AsyncOpt conveniences', () {
    test('delegate to the option produced after run', () async {
      final present = AsyncOpt<int>(() async => const Val(42));
      final absent = AsyncOpt<int>(() async => const Nil<int>());
      final events = <String>[];

      expect(
        await present.fold(
          onVal: (value) => 'value:$value',
          onNil: () => 'nil',
        ),
        'value:42',
      );
      expect(
        await absent.fold(
          onVal: (value) => 'value:$value',
          onNil: () => 'nil',
        ),
        'nil',
      );
      await present.when(
        onVal: (value) => events.add('value:$value'),
        onNil: () => events.add('nil'),
      );
      await absent.when(
        onVal: (value) => events.add('unexpected:$value'),
        onNil: () => events.add('nil'),
      );

      expect(await present.getOrElse(() => -1), 42);
      expect(await absent.getOrElse(() => -1), -1);
      expect(await present.hasValue, isTrue);
      expect(await present.isNil, isFalse);
      expect(await absent.hasValue, isFalse);
      expect(await absent.isNil, isTrue);
      expect(events, ['value:42', 'nil']);
    });
  });
}
