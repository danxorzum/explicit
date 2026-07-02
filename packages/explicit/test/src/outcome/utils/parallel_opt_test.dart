// Tests use experimental AsyncOpt types and the experimental ParallelOpt*
// class combinators.
// ignore_for_file: experimental_member_use

import 'dart:io';

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

void main() {
  group('ParallelOpt2', () {
    test('no eager execution before run()', () {
      var countA = 0;
      var countB = 0;

      final a = AsyncOpt<int>(() async {
        countA++;
        return const Val(1);
      });
      final b = AsyncOpt<String>(() async {
        countB++;
        return const Val('x');
      });

      // Constructing the class must NOT run recipes.
      final combinator = ParallelOpt2(a, b);

      expect(countA, 0, reason: 'recipe A must not run before run()');
      expect(countB, 0, reason: 'recipe B must not run before run()');
      expect(combinator, isA<ParallelOpt2<int, String>>());
    });

    test('all Val produces Val record with typed fields', () async {
      final a = AsyncOpt<int>(() async => const Val(42));
      final b = AsyncOpt<String>(() async => const Val('hello'));

      final result = await ParallelOpt2(a, b).run();

      expect(result, isA<Val<(int, String)>>());
      expect(
        result.fold(
          onVal: (r) => r.$1,
          onNil: () => -1,
        ),
        42,
      );
      expect(
        result.fold(
          onVal: (r) => r.$2,
          onNil: () => 'fallback',
        ),
        'hello',
      );
    });

    test('Nil in first recipe produces Nil', () async {
      final a = AsyncOpt<int>(() async => const Nil());
      final b = AsyncOpt<String>(() async => const Val('hello'));

      final result = await ParallelOpt2(a, b).run();

      expect(result, isA<Nil<(int, String)>>());
      expect(result.isNil, isTrue);
    });

    test('Nil in second recipe produces Nil', () async {
      final a = AsyncOpt<int>(() async => const Val(42));
      final b = AsyncOpt<String>(() async => const Nil());

      final result = await ParallelOpt2(a, b).run();

      expect(result, isA<Nil<(int, String)>>());
      expect(result.isNil, isTrue);
    });

    test('recipes start concurrently on run()', () async {
      final startTimes = <String, int>{};
      final stopwatch = Stopwatch()..start();

      final a = AsyncOpt<int>(() async {
        startTimes['a'] = stopwatch.elapsedMilliseconds;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Val(1);
      });
      final b = AsyncOpt<String>(() async {
        startTimes['b'] = stopwatch.elapsedMilliseconds;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Val('x');
      });

      await ParallelOpt2(a, b).run();

      // Both recipes should start within a small window of each other.
      final diff = (startTimes['a']! - startTimes['b']!).abs();
      expect(diff, lessThan(40), reason: 'recipes must start concurrently');
    });

    test('repeated run() re-executes all recipes', () async {
      var countA = 0;
      var countB = 0;

      final a = AsyncOpt<int>(() async {
        countA++;
        return Val(countA);
      });
      final b = AsyncOpt<String>(() async {
        countB++;
        return Val('run$countB');
      });

      final combinator = ParallelOpt2(a, b);

      final first = await combinator.run();
      final second = await combinator.run();

      expect(countA, 2);
      expect(countB, 2);
      expect(
        first.fold(onVal: (r) => (r.$1, r.$2), onNil: () => (-1, 'nil')),
        (1, 'run1'),
      );
      expect(
        second.fold(onVal: (r) => (r.$1, r.$2), onNil: () => (-1, 'nil')),
        (2, 'run2'),
      );
    });
  });

  group('ParallelOpt3', () {
    test('all Val produces Val record with 3 typed fields', () async {
      final a = AsyncOpt<int>(() async => const Val(1));
      final b = AsyncOpt<String>(() async => const Val('two'));
      final c = AsyncOpt<double>(() async => const Val(3.14));

      final result = await ParallelOpt3(a, b, c).run();

      expect(result, isA<Val<(int, String, double)>>());
      expect(
        result.fold(
          onVal: (r) => (r.$1, r.$2, r.$3),
          onNil: () => (-1, 'nil', -1.0),
        ),
        (1, 'two', 3.14),
      );
    });

    test('Nil in any recipe produces Nil', () async {
      final a = AsyncOpt<int>(() async => const Val(1));
      final b = AsyncOpt<String>(() async => const Nil());
      final c = AsyncOpt<double>(() async => const Val(3.14));

      final result = await ParallelOpt3(a, b, c).run();

      expect(result, isA<Nil<(int, String, double)>>());
      expect(result.isNil, isTrue);
    });

    test('no eager execution before run()', () {
      var callCount = 0;

      final a = AsyncOpt<int>(() async {
        callCount++;
        return const Val(1);
      });
      final b = AsyncOpt<String>(() async {
        callCount++;
        return const Val('x');
      });
      final c = AsyncOpt<double>(() async {
        callCount++;
        return const Val(1.5);
      });

      ParallelOpt3(a, b, c);

      expect(callCount, 0);
    });
  });

  group('ParallelOpt4', () {
    test('all Val produces Val record with 4 typed fields', () async {
      final a = AsyncOpt<int>(() async => const Val(1));
      final b = AsyncOpt<String>(() async => const Val('two'));
      final c = AsyncOpt<double>(() async => const Val(3.14));
      final d = AsyncOpt<bool>(() async => const Val(true));

      final result = await ParallelOpt4(a, b, c, d).run();

      expect(result, isA<Val<(int, String, double, bool)>>());
      expect(
        result.fold(
          onVal: (r) => (r.$1, r.$2, r.$3, r.$4),
          onNil: () => (-1, 'nil', -1.0, false),
        ),
        (1, 'two', 3.14, true),
      );
    });

    test('Nil in any recipe produces Nil', () async {
      final a = AsyncOpt<int>(() async => const Val(1));
      final b = AsyncOpt<String>(() async => const Val('two'));
      final c = AsyncOpt<double>(() async => const Nil());
      final d = AsyncOpt<bool>(() async => const Val(true));

      final result = await ParallelOpt4(a, b, c, d).run();

      expect(result.isNil, isTrue);
    });

    test('repeated run() re-executes all recipes', () async {
      var totalCalls = 0;

      AsyncOpt<int> makeRecipe() => AsyncOpt<int>(() async {
        totalCalls++;
        return Val(totalCalls);
      });

      final combinator = ParallelOpt4(
        makeRecipe(),
        makeRecipe(),
        makeRecipe(),
        makeRecipe(),
      );

      await combinator.run();
      await combinator.run();

      expect(totalCalls, 8, reason: '4 recipes × 2 runs = 8 calls');
    });
  });

  group('ParallelOpt5', () {
    test('all Val produces Val record with 5 typed fields', () async {
      final a = AsyncOpt<int>(() async => const Val(1));
      final b = AsyncOpt<String>(() async => const Val('two'));
      final c = AsyncOpt<double>(() async => const Val(3.14));
      final d = AsyncOpt<bool>(() async => const Val(true));
      final e = AsyncOpt<List<int>>(() async => const Val([4, 5]));

      final result = await ParallelOpt5(a, b, c, d, e).run();

      expect(result, isA<Val<(int, String, double, bool, List<int>)>>());
      result.fold(
        onVal: (r) {
          expect(r.$1, 1);
          expect(r.$2, 'two');
          expect(r.$3, 3.14);
          expect(r.$4, isTrue);
          expect(r.$5, [4, 5]);
        },
        onNil: () => fail('expected Val, got Nil'),
      );
    });

    test('Nil in any recipe produces Nil', () async {
      final a = AsyncOpt<int>(() async => const Val(1));
      final b = AsyncOpt<String>(() async => const Val('two'));
      final c = AsyncOpt<double>(() async => const Val(3.14));
      final d = AsyncOpt<bool>(() async => const Nil());
      final e = AsyncOpt<List<int>>(() async => const Val([4, 5]));

      final result = await ParallelOpt5(a, b, c, d, e).run();

      expect(result.isNil, isTrue);
    });

    test('no eager execution before run()', () {
      var callCount = 0;

      AsyncOpt<int> makeRecipe() => AsyncOpt<int>(() async {
        callCount++;
        return const Val(1);
      });

      ParallelOpt5(
        makeRecipe(),
        makeRecipe(),
        makeRecipe(),
        makeRecipe(),
        makeRecipe(),
      );

      expect(callCount, 0);
    });
  });

  group('Static analysis contracts', () {
    test('analyzer rejects function-style parallelOpt2..5 calls', () async {
      final fixture = File(
        '${Directory.current.path}/test/src/outcome/utils/.parallel_opt_function_style_fixture.dart',
      );
      addTearDown(() async {
        if (fixture.existsSync()) await fixture.delete();
      });

      const source = '''
// ignore_for_file: avoid_print, file_names, unused_local_variable

import 'package:explicit/explicit.dart';

void main() {
  final a = AsyncOpt<int>(() async => const Val(1));
  final b = AsyncOpt<String>(() async => const Val('x'));

  // These must all fail: function-style helpers do not exist.
  final r2 = parallelOpt2(a, b);
  final r3 = parallelOpt3(a, b, a);
  final r4 = parallelOpt4(a, b, a, b);
  final r5 = parallelOpt5(a, b, a, b, a);

  print((r2, r3, r4, r5));
}
''';
      await fixture.writeAsString(source);

      final result = await Process.run(
        'dart',
        ['analyze', fixture.path],
        workingDirectory: Directory.current.path,
      );
      final output = '${result.stdout}\n${result.stderr}';

      expect(
        result.exitCode,
        isNot(0),
        reason: 'Analyzer must reject undefined parallelOpt* functions',
      );
      expect(
        output,
        contains('undefined_function'),
        reason: 'Error must indicate parallelOpt* functions are undefined',
      );
    });

    test(
      'analyzer rejects eager Future passed to ParallelOpt2 constructor',
      () async {
        final fixture = File(
          '${Directory.current.path}/test/src/outcome/utils/.parallel_opt_eager_future_fixture.dart',
        );
        addTearDown(() async {
          if (fixture.existsSync()) await fixture.delete();
        });

        const source = '''
// ignore_for_file: avoid_print, file_names, unused_local_variable

import 'package:explicit/explicit.dart';

void main() {
  // An already-started Future<Opt<int>> — NOT an AsyncOpt<int>.
  final Future<Opt<int>> eagerFuture = Future.value(const Val(42));

  final asyncOpt = AsyncOpt<String>(() async => const Val('x'));

  // This must fail: ParallelOpt2 requires AsyncOpt, not Future<Opt>.
  final combinator = ParallelOpt2(eagerFuture, asyncOpt);

  print(combinator);
}
''';
        await fixture.writeAsString(source);

        final result = await Process.run(
          'dart',
          ['analyze', fixture.path],
          workingDirectory: Directory.current.path,
        );
        final output = '${result.stdout}\n${result.stderr}';

        expect(
          result.exitCode,
          isNot(0),
          reason: 'Analyzer must reject Future<Opt<T>> '
              'where AsyncOpt<T> is required',
        );
        expect(
          output,
          contains('argument_type_not_assignable'),
          reason:
              'Error must indicate type mismatch between Future and AsyncOpt',
        );
      },
    );
  });
}
