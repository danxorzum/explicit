// A small console walkthrough of the `explicit` public API.
//
// Run from the package root:
//   dart run example/main.dart
//
// The demo exercises success, failure, `flatMap`/`andThen`, the deprecated
// `toRecord` API, a lazy `AsyncRes` pipeline, and the standalone `retry`
// utility. All output is plain `print` so the example is easy to read in a
// terminal.

// The example intentionally calls the deprecated `toRecord` API to show the
// compatibility surface, and uses `print` because it is a console demo.
// ignore_for_file: deprecated_member_use_from_same_package, avoid_print

import 'package:explicit/explicit.dart';

Res<int, String> _divide(int a, int b) {
  if (b == 0) return const Err<int, String>('division by zero');
  return Ok<int, String>(a ~/ b);
}

AsyncResult<bool, String> _ping(String host) async {
  if (host.isEmpty) return const Err<bool, String>('empty host');
  return const Ok<bool, String>(true);
}

AsyncResult<String, String> _flakyFetch(int attempt) async {
  // Pretend the first two attempts fail transiently.
  if (attempt < 3) return Err<String, String>('transient $attempt');
  return const Ok<String, String>('payload');
}

Future<void> main() async {
  print('== 1. Success and failure ==');
  final ok = _divide(10, 2);
  final err = _divide(10, 0);

  print(ok.fold(onSuccess: (v) => 'success: $v', onError: (e) => 'error: $e'));
  print(err.fold(onSuccess: (v) => 'success: $v', onError: (e) => 'error: $e'));

  print('\n== 2. flatMap / andThen ==');
  final chained = _divide(20, 4)
      .flatMap((value) => Ok<String, String>('result=$value'))
      .andThen((text) => Ok<int, String>(text.length));
  print(
    chained.fold(onSuccess: (v) => 'length: $v', onError: (e) => 'err: $e'),
  );

  print('\n== 3. toRecord (deprecated compatibility) ==');
  print('ok record: ${ok.toRecord()}');
  print('err record: ${err.toRecord()}');

  print('\n== 4. AsyncRes lazy pipeline ==');
  final pipeline =
      AsyncRes<int, String>(
            () async {
              print('  (running initial step)');
              return const Ok<int, String>(2);
            },
          )
          .map((value) {
            print('  (mapping $value)');
            return value * 10;
          })
          .flatMap((value) {
            print('  (flat-mapping $value)');
            return AsyncRes<String, String>(
              () async => Ok<String, String>('value=$value'),
            );
          });
  print('  (pipeline built — nothing has run yet)');
  final asyncResult = await pipeline.run();
  print(
    asyncResult.fold(onSuccess: (v) => 'final: $v', onError: (e) => 'err: $e'),
  );

  print('\n== 5. AsyncRes with retry ==');
  var attempts = 0;
  final retried = await retry<String, String>(
    () async {
      attempts++;
      return _flakyFetch(attempts);
    },
    maxAttempts: 5,
  );
  print('attempts used: $attempts');
  print(
    retried.fold(onSuccess: (v) => 'payload: $v', onError: (e) => 'err: $e'),
  );

  print('\n== 6. AsyncRes composition with awaitable ==');
  final pinged =
      await AsyncRes<String, String>(
            () async => const Ok<String, String>('example.test'),
          )
          .flatMap((host) => AsyncRes<bool, String>(() => _ping(host)))
          .map((ok) => ok ? 'reachable' : 'unreachable')
          .run();
  print(pinged.fold(onSuccess: (v) => 'ping: $v', onError: (e) => 'err: $e'));
}
