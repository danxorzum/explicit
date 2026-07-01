import 'package:explicit_outcome/src/result/res.dart';
import 'package:meta/meta.dart';

/// Alias for an asynchronous [Res].
///
/// ## Result
/// {@macro result}
@experimental
typedef ResultAsync<T extends Object, E extends Object> = Future<Res<T, E>>;

/// Lazy asynchronous [Res] composition.
///
/// The wrapped operation is not executed when an [AsyncRes] is created or when
/// [map], [next], [mapError], or [or] are chained. Work starts only when [run]
/// is called.
@experimental
final class AsyncRes<T extends Object, E extends Object> {
  /// Creates a lazy asynchronous result from the provided operation.
  @experimental
  const AsyncRes(this._operation);

  final Future<Res<T, E>> Function() _operation;

  /// Executes the wrapped operation.
  @experimental
  ResultAsync<T, E> run() => _operation();

  /// Transforms the success value using [fn].
  ///
  /// If the result is [Err], the error is propagated and [fn] is not called.
  @experimental
  AsyncRes<R, E> map<R extends Object>(R Function(T value) fn) {
    return AsyncRes<R, E>(() async {
      final result = await run();

      return result.map(fn);
    });
  }

  /// Chains another [AsyncRes] operation when this result is [Ok].
  ///
  /// The [fn] is called after the wrapped operation is executed and returns an
  /// [Ok]. If the wrapped operation returns [Err], the error is propagated and
  /// [fn] is not called.
  @experimental
  AsyncRes<R, E> next<R extends Object>(AsyncRes<R, E> Function(T value) fn) {
    return AsyncRes<R, E>(() async {
      final result = await run();

      return result.fold<Future<Res<R, E>>>(
        onSuccess: (value) => fn(value).run(),
        onError: (error) async => Err<R, E>(error),
      );
    });
  }

  /// Transforms the error value using [fn].
  ///
  /// If the result is [Ok], the success value is propagated and [fn] is not
  /// called.
  @experimental
  AsyncRes<T, R> mapError<R extends Object>(R Function(E error) fn) {
    return AsyncRes<T, R>(() async {
      final result = await run();

      return result.mapError(fn);
    });
  }

  /// Returns this result if it is [Ok], or calls [fn] with the error.
  ///
  /// If the wrapped operation returns [Ok], the success value is preserved and
  /// [fn] is not called. If it returns [Err], [fn] receives the error and its
  /// [AsyncRes] is executed.
  @experimental
  AsyncRes<T, E> or(AsyncRes<T, E> Function(E error) fn) {
    return AsyncRes<T, E>(() async {
      final result = await run();

      return result.fold<Future<Res<T, E>>>(
        onSuccess: (value) async => Ok<T, E>(value),
        onError: (error) => fn(error).run(),
      );
    });
  }
}
