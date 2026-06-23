import 'package:explicit_outcome/explicit_outcome.dart' show AsyncRes, Err, Ok;
import 'package:explicit_outcome/src/option/opt.dart';
import 'package:explicit_outcome/src/result/async_res.dart' show AsyncRes;
import 'package:explicit_outcome/src/result/res.dart' show Err, Ok;
import 'package:explicit_outcome/src/result/result.dart' show AsyncRes, Err, Ok;

/// Lazy asynchronous [Opt] composition.
///
/// The wrapped operation is not executed when an [AsyncOpt] is created or when
/// [map], [flatMap], or [andThen] are chained. Work starts only when [run] is
/// called.
final class AsyncOpt<T> {
  /// Creates a lazy asynchronous result from the provided operation.
  const AsyncOpt(this._operation);

  final Future<Opt<T>> Function() _operation;

  /// Executes the wrapped operation.
  Future<Opt<T>> run() => _operation();

  /// Transforms the success value using [fn].
  ///
  /// If the result is [Err], the error is propagated and [fn] is not called.
  AsyncOpt<R> map<R>(R Function(T value) fn) {
    return AsyncOpt<R>(() async {
      final result = await run();

      return result.map(fn);
    });
  }

  AsyncOpt<R> asyncNext<R>(
    AsyncOption<R> Function(AsyncOption<T> Function() operation) fn,
  ) {
    return AsyncOpt<R>(() => fn(_operation));
  }

  /// Chains another [AsyncRes] operation when this result is [Ok].
  ///
  /// If this result is [Err], the error is propagated and [fn] is not called.
  AsyncOpt<R> next<R>(AsyncOpt<R> Function(T value) fn) {
    return AsyncOpt<R>(() async {
      final result = await run();

      return result.fold<Future<Opt<R>>>(
        onVal: (value) => fn(value).run(),
        onNil: () async => Nil<R>(),
      );
    });
  }
}
