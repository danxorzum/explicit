// Tests use experimental AsyncOpt/AsyncRes types and the toAsyncOpt/toAsyncRes
// adapter extensions.
// ignore_for_file: experimental_member_use

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

void main() {
  group('AsyncOptRecipe.toAsyncOpt', () {
    test('closure is not invoked until run() is called', () {
      var callCount = 0;

      Future<Opt<int>> recipe() async {
        callCount++;
        return const Val(42);
      }

      final asyncOpt = recipe.toAsyncOpt();

      expect(callCount, 0, reason: 'recipe must not run before run()');
      expect(asyncOpt, isA<AsyncOpt<int>>());
    });

    test('run() invokes the closure and returns Val', () async {
      var callCount = 0;

      Future<Opt<String>> recipe() async {
        callCount++;
        return const Val('hello');
      }

      final asyncOpt = recipe.toAsyncOpt();
      final result = await asyncOpt.run();

      expect(callCount, 1);
      expect(result, isA<Val<String>>());
      expect(
        result.fold(onVal: (v) => v, onNil: () => 'fallback'),
        'hello',
      );
    });

    test('run() invokes the closure and returns Nil', () async {
      Future<Opt<int>> recipe() async => const Nil();

      final asyncOpt = recipe.toAsyncOpt();
      final result = await asyncOpt.run();

      expect(result, isA<Nil<int>>());
      expect(result.isNil, isTrue);
    });

    test('repeated run() re-invokes the closure each time', () async {
      var callCount = 0;

      Future<Opt<int>> recipe() async {
        callCount++;
        return Val(callCount);
      }

      final asyncOpt = recipe.toAsyncOpt();

      final first = await asyncOpt.run();
      final second = await asyncOpt.run();

      expect(callCount, 2);
      expect(
        first.fold(onVal: (v) => v, onNil: () => -1),
        1,
      );
      expect(
        second.fold(onVal: (v) => v, onNil: () => -1),
        2,
      );
    });
  });

  group('AsyncResRecipe.toAsyncRes', () {
    test('closure is not invoked until run() is called', () {
      var callCount = 0;

      Future<Res<int, String>> recipe() async {
        callCount++;
        return const Ok(42);
      }

      final asyncRes = recipe.toAsyncRes();

      expect(callCount, 0, reason: 'recipe must not run before run()');
      expect(asyncRes, isA<AsyncRes<int, String>>());
    });

    test('run() invokes the closure and returns Ok', () async {
      var callCount = 0;

      Future<Res<String, int>> recipe() async {
        callCount++;
        return const Ok('success');
      }

      final asyncRes = recipe.toAsyncRes();
      final result = await asyncRes.run();

      expect(callCount, 1);
      expect(result, isA<Ok<String, int>>());
      expect(
        result.fold(onSuccess: (v) => v, onError: (e) => 'err:$e'),
        'success',
      );
    });

    test('run() invokes the closure and returns Err', () async {
      Future<Res<int, String>> recipe() async => const Err('failure');

      final asyncRes = recipe.toAsyncRes();
      final result = await asyncRes.run();

      expect(result, isA<Err<int, String>>());
      expect(result.isFailure, isTrue);
    });

    test('repeated run() re-invokes the closure each time', () async {
      var callCount = 0;

      Future<Res<int, String>> recipe() async {
        callCount++;
        return Ok(callCount);
      }

      final asyncRes = recipe.toAsyncRes();

      final first = await asyncRes.run();
      final second = await asyncRes.run();

      expect(callCount, 2);
      expect(
        first.fold(onSuccess: (v) => v, onError: (_) => -1),
        1,
      );
      expect(
        second.fold(onSuccess: (v) => v, onError: (_) => -1),
        2,
      );
    });
  });
}
