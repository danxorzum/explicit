import 'package:explicit_outcome/src/option/opt.dart';
import 'package:meta/meta.dart';

/// Alias for an asynchronous [Opt].
///
/// ## Option
/// {@macro option}
@experimental
typedef OptionAsync<T extends Object> = Future<Opt<T>>;

/// Lazy asynchronous [Opt] composition.
///
/// The wrapped operation is not executed when an [AsyncOpt] is created or when
/// [map], [next], or [or] are chained. Work starts only when [run] is
/// called.
@experimental
final class AsyncOpt<T extends Object> {
  /// Creates a lazy asynchronous option from the provided operation.
  @experimental
  const AsyncOpt(this._operation);

  final Future<Opt<T>> Function() _operation;

  /// Executes the wrapped operation.
  @experimental
  OptionAsync<T> run() => _operation();

  /// Transforms the present value using [fn].
  @experimental
  AsyncOpt<R> map<R extends Object>(R Function(T value) fn) {
    return AsyncOpt<R>(() async {
      final option = await run();

      return option.map(fn);
    });
  }

  /// Chains another [AsyncOpt] operation when this option is [Val].
  ///
  /// The [fn] is called after the wrapped operation is executed and returns a
  /// [Val]. If the wrapped operation returns [Nil], absence is propagated and
  /// [fn] is not called.
  @experimental
  AsyncOpt<R> next<R extends Object>(AsyncOpt<R> Function(T value) fn) {
    return AsyncOpt<R>(() async {
      final option = await run();

      return option.fold<Future<Opt<R>>>(
        onVal: (value) => fn(value).run(),
        onNil: () async => Nil<R>(),
      );
    });
  }

  /// Chains another [AsyncOpt] operation when this option is [Nil].
  ///
  /// If this option is [Val], [fn] is not called.
  @experimental
  AsyncOpt<T> or(AsyncOpt<T> Function() fn) {
    return AsyncOpt<T>(() async {
      final option = await run();

      return option.fold<Future<Opt<T>>>(
        onVal: (value) async => Val(value),
        onNil: () => fn().run(),
      );
    });
  }
}

/// Convenience methods for consuming lazy asynchronous [Opt] values.
@experimental
extension AsyncOptConveniences<T extends Object> on AsyncOpt<T> {
  /// Executes [onVal] if the produced option is [Val], or [onNil] if it is
  /// [Nil].
  @experimental
  Future<R> fold<R>({
    required R Function(T value) onVal,
    required R Function() onNil,
  }) async {
    final option = await run();

    return option.fold(onVal: onVal, onNil: onNil);
  }

  /// Executes [onVal] if the produced option is [Val], or [onNil] if it is
  /// [Nil].
  @experimental
  Future<void> when({
    required void Function(T value) onVal,
    required void Function() onNil,
  }) async {
    final option = await run();

    option.when(onVal: onVal, onNil: onNil);
  }

  /// Returns the present value, or calls [fallback] when the produced option is
  /// [Nil].
  @experimental
  Future<T> getOrElse(T Function() fallback) async {
    final option = await run();

    return option.getOrElse(fallback);
  }

  /// Returns `true` when the produced option is [Val].
  @experimental
  Future<bool> get hasValue async => (await run()).hasValue;

  /// Returns `true` when the produced option is [Nil].
  @experimental
  Future<bool> get isNil async => (await run()).isNil;
}
