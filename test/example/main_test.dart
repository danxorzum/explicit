// Mirrors the scenarios in `example/main.dart` in Table-Driven Test Cases
// (TCT) style. The example is a runnable demo; these tests prove that the
// same library calls produce the documented outcomes.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

Res<int, String> _divide(int a, int b) {
  if (b == 0) return const Err<int, String>('division by zero');
  return Ok<int, String>(a ~/ b);
}

Future<Res<bool, String>> _ping(String host) async {
  if (host.isEmpty) return const Err<bool, String>('empty host');
  return const Ok<bool, String>(true);
}

Future<Res<String, String>> _flakyFetch(int attempt) async {
  if (attempt < 3) return Err<String, String>('transient $attempt');
  return const Ok<String, String>('payload');
}

Future<({int calls, Res<String, String> result})> _retryFlaky(int max) async {
  var calls = 0;
  final result = await retry<String, String>(
    () async {
      calls++;
      return _flakyFetch(calls);
    },
    maxAttempts: max,
  );
  return (calls: calls, result: result);
}

typedef _DivideCase = ({
  String name,
  Res<int, String> input,
  String expected,
});

typedef _ChainCase = ({
  String name,
  Res<int, String> input,
  String expected,
});

typedef _RecordCase = ({
  String name,
  Res<int, String> input,
  (int?, String?) expected,
});

typedef _PipelineCase = ({
  String name,
  Future<String> Function() build,
  String expected,
});

typedef _RetryCase = ({
  String name,
  int maxAttempts,
  int expectedCalls,
  String expectedRendered,
});

typedef _PingCase = ({
  String name,
  Future<String> Function() build,
  String expected,
});

void main() {
  // ---------------------------------------------------------------
  // 1. Success and failure (mirrors `example/main.dart` section 1)
  // ---------------------------------------------------------------
  group('example: success and failure', () {
    final testCases = <_DivideCase>[
      (
        name: 'divide(10, 2) yields Ok(5)',
        input: _divide(10, 2),
        expected: 'success: 5',
      ),
      (
        name: 'divide(10, 0) yields Err(division by zero)',
        input: _divide(10, 0),
        expected: 'error: division by zero',
      ),
      (
        name: 'divide(0, 5) yields Ok(0) (zero payload is still a success)',
        input: _divide(0, 5),
        expected: 'success: 0',
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final rendered = tc.input.fold(
          onSuccess: (v) => 'success: $v',
          onError: (e) => 'error: $e',
        );
        expect(rendered, tc.expected);
      });
    }
  });

  // ---------------------------------------------------------------
  // 2. flatMap / andThen (mirrors section 2)
  // ---------------------------------------------------------------
  group('example: flatMap / andThen', () {
    final testCases = <_ChainCase>[
      (
        name: 'flatMap into Ok then andThen chains length',
        input: _divide(20, 4)
            .flatMap((value) => Ok<String, String>('result=$value'))
            .andThen((text) => Ok<int, String>(text.length)),
        expected: 'length: 8',
      ),
      (
        name: 'flatMap short-circuits when input is Err',
        input: _divide(20, 0)
            .flatMap((value) => Ok<String, String>('result=$value'))
            .andThen((text) => Ok<int, String>(text.length)),
        expected: 'err: division by zero',
      ),
      (
        name: 'andThen alias of flatMap composes Ok into Ok',
        input: const Ok<int, String>(5).andThen(
          (value) => Ok<int, String>(value * 2),
        ),
        expected: 'length: 10',
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final rendered = tc.input.fold(
          onSuccess: (v) => 'length: $v',
          onError: (e) => 'err: $e',
        );
        expect(rendered, tc.expected);
      });
    }
  });

  // ---------------------------------------------------------------
  // 3. toRecord deprecated compatibility (mirrors section 3)
  // ---------------------------------------------------------------
  group('example: toRecord (deprecated)', () {
    final testCases = <_RecordCase>[
      (
        name: 'Ok record carries value and null error',
        input: _divide(10, 2),
        expected: (5, null),
      ),
      (
        name: 'Err record carries null value and error',
        input: _divide(10, 0),
        expected: (null, 'division by zero'),
      ),
      (
        name: 'Ok(0) record is (0, null), not treated as missing',
        input: _divide(0, 5),
        expected: (0, null),
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        expect(tc.input.toRecord(), tc.expected);
      });
    }
  });

  // ---------------------------------------------------------------
  // 4. AsyncRes lazy pipeline (mirrors section 4)
  // ---------------------------------------------------------------
  group('example: AsyncRes lazy pipeline', () {
    final testCases = <_PipelineCase>[
      (
        name: 'pipeline is lazy until run() is awaited',
        build: () {
          final events = <String>[];
          final pipeline =
              AsyncRes<int, String>(
                    () async {
                      events.add('initial');
                      return const Ok<int, String>(2);
                    },
                  )
                  .map((value) {
                    events.add('map:$value');
                    return value * 10;
                  })
                  .flatMap((value) {
                    events.add('flatMap:$value');
                    return AsyncRes<String, String>(
                      () async => Ok<String, String>('value=$value'),
                    );
                  });

          return pipeline.run().then((result) {
            expect(
              events,
              equals(['initial', 'map:2', 'flatMap:20']),
              reason: 'steps must run in declaration order',
            );
            return result.fold(
              onSuccess: (v) => 'final: $v',
              onError: (e) => 'err: $e',
            );
          });
        },
        expected: 'final: value=20',
      ),
      (
        name: 'Err in initial step short-circuits downstream map and flatMap',
        build: () {
          final events = <String>[];
          final pipeline =
              AsyncRes<int, String>(
                    () async => const Err<int, String>('boom'),
                  )
                  .map((value) {
                    events.add('map:$value');
                    return value;
                  })
                  .flatMap((value) {
                    events.add('flatMap:$value');
                    return AsyncRes<String, String>(
                      () async => const Ok<String, String>('unused'),
                    );
                  });

          return pipeline.run().then((result) {
            expect(events, isEmpty, reason: 'no downstream step may run');
            return result.fold(
              onSuccess: (v) => 'final: $v',
              onError: (e) => 'err: $e',
            );
          });
        },
        expected: 'err: boom',
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        final rendered = await tc.build();
        expect(rendered, tc.expected);
      });
    }
  });

  // ---------------------------------------------------------------
  // 5. retry (mirrors section 5)
  // ---------------------------------------------------------------
  group('example: retry', () {
    final testCases = <_RetryCase>[
      (
        name: 'retry recovers after 2 transient failures (3 attempts total)',
        maxAttempts: 5,
        expectedCalls: 3,
        expectedRendered: 'payload: payload',
      ),
      (
        name: 'retry returns last failure when budget is exhausted',
        maxAttempts: 2,
        expectedCalls: 2,
        expectedRendered: 'err: transient 2',
      ),
      (
        name: 'retry with maxAttempts: 1 returns the first failure',
        maxAttempts: 1,
        expectedCalls: 1,
        expectedRendered: 'err: transient 1',
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        final outcome = await _retryFlaky(tc.maxAttempts);
        expect(outcome.calls, tc.expectedCalls);
        expect(
          outcome.result.fold(
            onSuccess: (v) => 'payload: $v',
            onError: (e) => 'err: $e',
          ),
          tc.expectedRendered,
        );
      });
    }
  });

  // ---------------------------------------------------------------
  // 6. AsyncRes composition with awaitable (mirrors section 6)
  // ---------------------------------------------------------------
  group('example: AsyncRes composition with awaitable', () {
    final testCases = <_PingCase>[
      (
        name: 'flatMap into another AsyncRes with a reachable host',
        build: () =>
            AsyncRes<String, String>(
                  () async => const Ok<String, String>('example.test'),
                )
                .flatMap((host) => AsyncRes<bool, String>(() => _ping(host)))
                .map((ok) => ok ? 'reachable' : 'unreachable')
                .run()
                .then(
                  (result) => result.fold(
                    onSuccess: (v) => 'ping: $v',
                    onError: (e) => 'err: $e',
                  ),
                ),
        expected: 'ping: reachable',
      ),
      (
        name: 'flatMap propagates an empty-host Err without running _ping',
        build: () =>
            AsyncRes<String, String>(
                  () async => const Ok<String, String>(''),
                )
                .flatMap((host) => AsyncRes<bool, String>(() => _ping(host)))
                .map((ok) => ok ? 'reachable' : 'unreachable')
                .run()
                .then(
                  (result) => result.fold(
                    onSuccess: (v) => 'ping: $v',
                    onError: (e) => 'err: $e',
                  ),
                ),
        expected: 'err: empty host',
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        final rendered = await tc.build();
        expect(rendered, tc.expected);
      });
    }
  });
}
