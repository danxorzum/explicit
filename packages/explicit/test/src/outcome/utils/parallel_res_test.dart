// Tests use experimental AsyncRes types and the experimental ParallelRes*
// class combinators.
// ignore_for_file: experimental_member_use

import 'dart:io';

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

void main() {
  group('ParallelRes2', () {
    test('no eager execution before run()', () {
      var countA = 0;
      var countB = 0;

      final a = AsyncRes<int, String>(() async {
        countA++;
        return const Ok(1);
      });
      final b = AsyncRes<String, String>(() async {
        countB++;
        return const Ok('x');
      });

      // Constructing the class must NOT run recipes.
      final combinator = ParallelRes2(a, b);

      expect(countA, 0, reason: 'recipe A must not run before run()');
      expect(countB, 0, reason: 'recipe B must not run before run()');
      expect(combinator, isA<ParallelRes2<int, String, String>>());
    });

    test('all Ok produces Ok record with typed fields', () async {
      final a = AsyncRes<int, String>(() async => const Ok(42));
      final b = AsyncRes<String, String>(() async => const Ok('hello'));

      final result = await ParallelRes2(a, b).run();

      expect(result, isA<Ok<(int, String), String>>());
      expect(
        result.fold(
          onSuccess: (r) => r.$1,
          onError: (e) => -1,
        ),
        42,
      );
      expect(
        result.fold(
          onSuccess: (r) => r.$2,
          onError: (e) => 'fallback',
        ),
        'hello',
      );
    });

    test('Err in first recipe produces Err', () async {
      final a = AsyncRes<int, String>(() async => const Err('error-a'));
      final b = AsyncRes<String, String>(() async => const Ok('hello'));

      final result = await ParallelRes2(a, b).run();

      expect(result, isA<Err<(int, String), String>>());
      expect(
        result.fold(
          onSuccess: (_) => 'ok',
          onError: (e) => e,
        ),
        'error-a',
      );
    });

    test('Err in second recipe produces Err', () async {
      final a = AsyncRes<int, String>(() async => const Ok(42));
      final b = AsyncRes<String, String>(() async => const Err('error-b'));

      final result = await ParallelRes2(a, b).run();

      expect(result, isA<Err<(int, String), String>>());
      expect(
        result.fold(
          onSuccess: (_) => 'ok',
          onError: (e) => e,
        ),
        'error-b',
      );
    });

    test('deterministic first error by parameter order', () async {
      final a = AsyncRes<int, String>(() async => const Err('error-a'));
      final b = AsyncRes<String, String>(() async => const Err('error-b'));

      final result = await ParallelRes2(a, b).run();

      expect(result, isA<Err<(int, String), String>>());
      expect(
        result.fold(
          onSuccess: (_) => 'ok',
          onError: (e) => e,
        ),
        'error-a',
        reason: 'first error by parameter order must be selected',
      );
    });

    test('recipes start concurrently on run()', () async {
      final startTimes = <String, int>{};
      final stopwatch = Stopwatch()..start();

      final a = AsyncRes<int, String>(() async {
        startTimes['a'] = stopwatch.elapsedMilliseconds;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Ok(1);
      });
      final b = AsyncRes<String, String>(() async {
        startTimes['b'] = stopwatch.elapsedMilliseconds;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Ok('x');
      });

      await ParallelRes2(a, b).run();

      // Both recipes should start within a small window of each other.
      final diff = (startTimes['a']! - startTimes['b']!).abs();
      expect(diff, lessThan(40), reason: 'recipes must start concurrently');
    });

    test('repeated run() re-executes all recipes', () async {
      var countA = 0;
      var countB = 0;

      final a = AsyncRes<int, String>(() async {
        countA++;
        return Ok(countA);
      });
      final b = AsyncRes<String, String>(() async {
        countB++;
        return Ok('run$countB');
      });

      final combinator = ParallelRes2(a, b);

      final first = await combinator.run();
      final second = await combinator.run();

      expect(countA, 2);
      expect(countB, 2);
      expect(
        first.fold(
          onSuccess: (r) => (r.$1, r.$2),
          onError: (e) => (-1, 'err'),
        ),
        (1, 'run1'),
      );
      expect(
        second.fold(
          onSuccess: (r) => (r.$1, r.$2),
          onError: (e) => (-1, 'err'),
        ),
        (2, 'run2'),
      );
    });

    test('no hidden retry on failure', () async {
      var callCount = 0;

      final a = AsyncRes<int, String>(() async {
        callCount++;
        return const Err('fail-once');
      });
      final b = AsyncRes<String, String>(() async => const Ok('x'));

      final result = await ParallelRes2(a, b).run();

      expect(callCount, 1, reason: 'recipe must not be retried');
      expect(result.isFailure, isTrue);
    });
  });

  group('ParallelRes3', () {
    test('all Ok produces Ok record with 3 typed fields', () async {
      final a = AsyncRes<int, String>(() async => const Ok(1));
      final b = AsyncRes<String, String>(() async => const Ok('two'));
      final c = AsyncRes<double, String>(() async => const Ok(3.14));

      final result = await ParallelRes3(a, b, c).run();

      expect(result, isA<Ok<(int, String, double), String>>());
      expect(
        result.fold(
          onSuccess: (r) => (r.$1, r.$2, r.$3),
          onError: (e) => (-1, 'err', -1.0),
        ),
        (1, 'two', 3.14),
      );
    });

    test('Err in any recipe produces Err', () async {
      final a = AsyncRes<int, String>(() async => const Ok(1));
      final b = AsyncRes<String, String>(() async => const Err('error-b'));
      final c = AsyncRes<double, String>(() async => const Ok(3.14));

      final result = await ParallelRes3(a, b, c).run();

      expect(result, isA<Err<(int, String, double), String>>());
      expect(result.isFailure, isTrue);
    });

    test('no eager execution before run()', () {
      var callCount = 0;

      final a = AsyncRes<int, String>(() async {
        callCount++;
        return const Ok(1);
      });
      final b = AsyncRes<String, String>(() async {
        callCount++;
        return const Ok('x');
      });
      final c = AsyncRes<double, String>(() async {
        callCount++;
        return const Ok(1.5);
      });

      ParallelRes3(a, b, c);

      expect(callCount, 0);
    });
  });

  group('ParallelRes4', () {
    test('all Ok produces Ok record with 4 typed fields', () async {
      final a = AsyncRes<int, String>(() async => const Ok(1));
      final b = AsyncRes<String, String>(() async => const Ok('two'));
      final c = AsyncRes<double, String>(() async => const Ok(3.14));
      final d = AsyncRes<bool, String>(() async => const Ok(true));

      final result = await ParallelRes4(a, b, c, d).run();

      expect(result, isA<Ok<(int, String, double, bool), String>>());
      expect(
        result.fold(
          onSuccess: (r) => (r.$1, r.$2, r.$3, r.$4),
          onError: (e) => (-1, 'err', -1.0, false),
        ),
        (1, 'two', 3.14, true),
      );
    });

    test('Err in any recipe produces Err', () async {
      final a = AsyncRes<int, String>(() async => const Ok(1));
      final b = AsyncRes<String, String>(() async => const Ok('two'));
      final c = AsyncRes<double, String>(() async => const Err('error-c'));
      final d = AsyncRes<bool, String>(() async => const Ok(true));

      final result = await ParallelRes4(a, b, c, d).run();

      expect(result.isFailure, isTrue);
    });

    test('repeated run() re-executes all recipes', () async {
      var totalCalls = 0;

      AsyncRes<int, String> makeRecipe() => AsyncRes<int, String>(() async {
        totalCalls++;
        return Ok(totalCalls);
      });

      final combinator = ParallelRes4(
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

  group('ParallelRes5', () {
    test('all Ok produces Ok record with 5 typed fields', () async {
      final a = AsyncRes<int, String>(() async => const Ok(1));
      final b = AsyncRes<String, String>(() async => const Ok('two'));
      final c = AsyncRes<double, String>(() async => const Ok(3.14));
      final d = AsyncRes<bool, String>(() async => const Ok(true));
      final e = AsyncRes<List<int>, String>(() async => const Ok([4, 5]));

      final result = await ParallelRes5(a, b, c, d, e).run();

      expect(result, isA<Ok<(int, String, double, bool, List<int>), String>>());
      result.fold(
        onSuccess: (r) {
          expect(r.$1, 1);
          expect(r.$2, 'two');
          expect(r.$3, 3.14);
          expect(r.$4, isTrue);
          expect(r.$5, [4, 5]);
        },
        onError: (e) => fail('expected Ok, got Err($e)'),
      );
    });

    test('Err in any recipe produces Err', () async {
      final a = AsyncRes<int, String>(() async => const Ok(1));
      final b = AsyncRes<String, String>(() async => const Ok('two'));
      final c = AsyncRes<double, String>(() async => const Ok(3.14));
      final d = AsyncRes<bool, String>(() async => const Err('error-d'));
      final e = AsyncRes<List<int>, String>(() async => const Ok([4, 5]));

      final result = await ParallelRes5(a, b, c, d, e).run();

      expect(result.isFailure, isTrue);
    });

    test('no eager execution before run()', () {
      var callCount = 0;

      AsyncRes<int, String> makeRecipe() => AsyncRes<int, String>(() async {
        callCount++;
        return const Ok(1);
      });

      ParallelRes5(
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
    test('analyzer rejects function-style parallelRes2..5 calls', () async {
      final fixture = File(
        '${Directory.current.path}/test/src/outcome/utils/.parallel_res_function_style_fixture.dart',
      );
      addTearDown(() async {
        if (fixture.existsSync()) await fixture.delete();
      });

      const source = '''
// ignore_for_file: avoid_print, file_names, unused_local_variable

import 'package:explicit/explicit.dart';

void main() {
  final a = AsyncRes<int, String>(() async => const Ok(1));
  final b = AsyncRes<String, String>(() async => const Ok('x'));

  // These must all fail: function-style helpers do not exist.
  final r2 = parallelRes2(a, b);
  final r3 = parallelRes3(a, b, a);
  final r4 = parallelRes4(a, b, a, b);
  final r5 = parallelRes5(a, b, a, b, a);

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
        reason: 'Analyzer must reject undefined parallelRes* functions',
      );
      expect(
        output,
        contains('undefined_function'),
        reason: 'Error must indicate parallelRes* functions are undefined',
      );
    });

    test(
      'analyzer rejects eager Future passed to ParallelRes2 constructor',
      () async {
        final fixture = File(
          '${Directory.current.path}/test/src/outcome/utils/.parallel_res_eager_future_fixture.dart',
        );
        addTearDown(() async {
          if (fixture.existsSync()) await fixture.delete();
        });

        const source = '''
// ignore_for_file: avoid_print, file_names, unused_local_variable

import 'package:explicit/explicit.dart';

void main() {
  // An already-started Future<Res<int, String>> — NOT an AsyncRes<int, String>.
  final Future<Res<int, String>> eagerFuture = Future.value(const Ok(42));

  final asyncRes = AsyncRes<String, String>(() async => const Ok('x'));

  // This must fail: ParallelRes2 requires AsyncRes, not Future<Res>.
  final combinator = ParallelRes2(eagerFuture, asyncRes);

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
          reason:
              'Analyzer must reject Future<Res<T, E>> '
              'where AsyncRes<T, E> is required',
        );
        expect(
          output,
          contains('argument_type_not_assignable'),
          reason:
              'Error must indicate type mismatch between Future and AsyncRes',
        );
      },
    );
  });
}
