import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

typedef _TestCase<T, E, R> = ({
  String name,
  Result<T, E> input,
  R Function(T) onSuccess,
  R Function(E) onError,
  R expected,
});

void main() {
  group('Result', () {
    final testCases = <_TestCase<dynamic, dynamic, dynamic>>[
      (
        name: 'Ok case',
        input: const Ok(42),
        onSuccess: (_) => 84,
        onError: (_) => -1,
        expected: 84,
      ),
      (
        name: 'Err case',
        input: const Err('error'),
        onSuccess: (_) => 84,
        onError: (_) => 'Quesi',
        expected: 'Quesi',
      ),
      (
        name: 'Ok with null value still routes to onSuccess',
        input: const Ok<String?, Object>(null),
        onSuccess: (value) => value == null ? 'null-ok' : 'value-ok',
        onError: (_) => 'err',
        expected: 'null-ok',
      ),
      (
        name: 'Err with null error still routes to onError',
        input: const Err<int, String?>(null),
        onSuccess: (_) => 'ok',
        onError: (error) => error == null ? 'null-err' : 'value-err',
        expected: 'null-err',
      ),
      (
        name: 'fold can return a different type from both branches',
        input: const Ok<int, String>(1),
        onSuccess: (value) => 'success:$value',
        onError: (error) => 'error:$error',
        expected: 'success:1',
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final result = tc.input.fold(
          onSuccess: tc.onSuccess,
          onError: tc.onError,
        );

        expect(result, tc.expected);
      });
    }
  });
}
