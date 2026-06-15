// The example intentionally calls the deprecated `toRecord` API to show the
// compatibility surface.
// Cascades would make the ordered walkthrough less direct to scan.
// ignore_for_file: deprecated_member_use, cascade_invocations

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
  if (attempt < 3) return Err<String, String>('transient $attempt');
  return const Ok<String, String>('payload');
}

/// Builds the demo output for the explicit package example.
Future<List<String>> buildDemoOutput() async {
  final lines = <String>[];
  lines.add('== 1. Success and failure ==');
  final ok = _divide(10, 2);
  final err = _divide(10, 0);

  lines
    ..add(ok.fold(onSuccess: (v) => 'success: $v', onError: (e) => 'error: $e'))
    ..add(
      err.fold(onSuccess: (v) => 'success: $v', onError: (e) => 'error: $e'),
    );

  lines
    ..add('')
    ..add('== 2. flatMap / andThen ==');
  final chained = _divide(20, 4)
      .flatMap((value) => Ok<String, String>('result=$value'))
      .andThen((text) => Ok<int, String>(text.length));
  lines.add(
    chained.fold(onSuccess: (v) => 'length: $v', onError: (e) => 'err: $e'),
  );

  lines
    ..add('')
    ..add('== 3. toRecord (deprecated compatibility) ==');
  lines
    ..add('ok record: ${ok.toRecord()}')
    ..add('err record: ${err.toRecord()}');

  lines
    ..add('')
    ..add('== 4. AsyncRes lazy pipeline ==');
  final pipeline =
      AsyncRes<int, String>(() async {
            lines.add('  (running initial step)');
            return const Ok<int, String>(2);
          })
          .map((value) {
            lines.add('  (mapping $value)');
            return value * 10;
          })
          .flatMap((value) {
            lines.add('  (flat-mapping $value)');
            return AsyncRes<String, String>(
              () async => Ok<String, String>('value=$value'),
            );
          });
  lines.add('  (pipeline built — nothing has run yet)');
  final asyncResult = await pipeline.run();
  lines.add(
    asyncResult.fold(onSuccess: (v) => 'final: $v', onError: (e) => 'err: $e'),
  );

  lines
    ..add('')
    ..add('== 5. AsyncRes with retry ==');
  var attempts = 0;
  final retried = await retry<String, String>(() async {
    attempts++;
    return _flakyFetch(attempts);
  }, maxAttempts: 5);
  lines
    ..add('attempts used: $attempts')
    ..add(
      retried.fold(onSuccess: (v) => 'payload: $v', onError: (e) => 'err: $e'),
    );

  lines
    ..add('')
    ..add('== 6. AsyncRes composition with awaitable ==');
  final pinged =
      await AsyncRes<String, String>(
            () async => const Ok<String, String>('example.test'),
          )
          .flatMap((host) => AsyncRes<bool, String>(() => _ping(host)))
          .map((ok) => ok ? 'reachable' : 'unreachable')
          .run();
  lines.add(
    pinged.fold(onSuccess: (v) => 'ping: $v', onError: (e) => 'err: $e'),
  );

  return lines;
}
