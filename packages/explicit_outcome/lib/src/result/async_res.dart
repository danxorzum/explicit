import 'package:explicit_outcome/src/result/result.dart';

/// Lazy asynchronous [Res] composition.
///
/// The wrapped operation is not executed when an [AsyncRes] is created or when
/// [map], [flatMap], or [andThen] are chained. Work starts only when [run] is
/// called.
final class AsyncRes<T extends Object, E extends Object> {
  /// Creates a lazy asynchronous result from the provided operation.
  const AsyncRes(this._operation);

  final Future<Res<T, E>> Function() _operation;

  /// Executes the wrapped operation.
  Future<Res<T, E>> run() => _operation();

  /// Transforms the success value using [fn].
  ///
  /// If the result is [Err], the error is propagated and [fn] is not called.
  AsyncRes<R, E> map<R extends Object>(R Function(T value) fn) {
    return AsyncRes<R, E>(() async {
      final result = await run();

      return result.map(fn);
    });
  }

  /// Chains another [AsyncRes] operation when this result is [Ok].
  ///
  /// If this result is [Err], the error is propagated and [fn] is not called.
  AsyncRes<R, E> flatMap<R extends Object>(
    AsyncRes<R, E> Function(T value) fn,
  ) {
    return AsyncRes<R, E>(() async {
      final result = await run();

      return result.fold<Future<Res<R, E>>>(
        onSuccess: (value) => fn(value).run(),
        onError: (error) async => Err<R, E>(error),
      );
    });
  }

  /// Alias for [flatMap].
  AsyncRes<R, E> andThen<R extends Object>(
    AsyncRes<R, E> Function(T value) fn,
  ) {
    return flatMap(fn);
  }
}
