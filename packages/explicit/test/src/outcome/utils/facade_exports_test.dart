// Tests intentionally use experimental AsyncOpt/AsyncRes types from facade.
// ignore_for_file: experimental_member_use

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

void main() {
  group('facade exports', () {
    test('Opt is available from facade', () {
      const Opt<int> option = Val(42);
      expect(option.hasValue, isTrue);
    });

    test('Res is available from facade', () {
      const Res<int, String> result = Ok(42);
      expect(result.isSuccess, isTrue);
    });

    test('AsyncOpt is available from facade', () {
      final asyncOpt = AsyncOpt<int>(() async => const Val(42));
      expect(asyncOpt, isA<AsyncOpt<int>>());
    });

    test('AsyncRes is available from facade', () {
      final asyncRes = AsyncRes<int, String>(() async => const Ok(42));
      expect(asyncRes, isA<AsyncRes<int, String>>());
    });

    test('Val is available from facade', () {
      const val = Val(42);
      expect(val, isA<Opt<int>>());
    });

    test('Nil is available from facade', () {
      const nil = Nil<int>();
      expect(nil, isA<Opt<int>>());
    });

    test('Ok is available from facade', () {
      const ok = Ok<int, String>(42);
      expect(ok, isA<Res<int, String>>());
    });

    test('Err is available from facade', () {
      const err = Err<int, String>('error');
      expect(err, isA<Res<int, String>>());
    });
  });
}
