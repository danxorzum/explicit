import 'package:meta/meta.dart';

/// Alias for an asynchronous [Result].
typedef AsyncResult<T, E> = Future<Result<T, E>>;

/// Compact alias for [Result].
typedef Res<T, E> = Result<T, E>;

/// Compatibility alias for [Ok].
typedef Success<T, E> = Ok<T, E>;

/// Compatibility alias for [Err].
typedef Failure<T, E> = Err<T, E>;

/// {@template result}
/// A generic [Result] type that represents either an [Ok] or an [Err]
/// (failure).
///
/// Use [Result] to handle operations that can fail without throwing exceptions.
/// - [T] is the type of the success value.
/// - [E] is the type of the error value.
///
/// ### Example:
/// ```dart
/// final result = Ok<int, String>(42);
///
/// result.fold(
///   onSuccess: (value) => print('Success: $value'),
///   onError: (error) => print('Error: $error'),
/// );
///
/// switch (result) {
///   case Ok<int, String>(:final value):
///     print('Success: $value');
///   case Err<int, String>(:final error):
///     print('Error: $error');
/// }
/// ```
/// {@endtemplate}
@immutable
sealed class Result<T, E> {
  const Result();

  /// Executes [onSuccess] if the result is an [Ok], or [onError] if it is
  /// an [Err].
  ///
  /// Returns the result of the executed function.
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(E) onError,
  });

  /// Returns `true` if this is an [Ok].
  bool get isSuccess => fold(onSuccess: (_) => true, onError: (_) => false);

  /// Returns `true` if this is an [Err].
  bool get isFailure => fold(onSuccess: (_) => false, onError: (_) => true);

  /// Note: This is an experimental API and may change or be removed in the
  /// future.
  /// Returns a record with (value, error).
  /// - If it is [Ok], error will be null.
  /// - If it is [Err], value will be null.
  ///
  /// Null values are allowed, so you can have an [Ok] with a null value or an
  /// [Err] with a null error. Always check [isSuccess] or [isFailure] before
  /// using the values.
  @experimental
  (T? value, E? error) get values => toRecord();

  /// Returns a record with (value, error).
  ///
  /// - If it is [Ok], error will be null.
  /// - If it is [Err], value will be null.
  ///
  /// Null values are allowed, so check [isSuccess] or [isFailure] before using
  /// nullable payloads.
  (T? value, E? error) toRecord() => fold(
    onSuccess: (v) => (v, null),
    onError: (e) => (null, e),
  );

  /// Returns the value if this is an [Ok].
  ///
  /// Throws [StateError] if this is an [Err].
  /// Use this method only when you are sure the result is a success.
  @experimental
  @visibleForTesting
  T expect() => fold(
    onSuccess: (v) => v,
    onError: (_) => throw StateError(
      'Result.expect() was called on an error result.',
    ),
  );

  /// Returns the error value if this is an [Err].
  ///
  /// Throws [StateError] if this is an [Ok].
  /// Use this method only when you are sure the result is a failure.
  @experimental
  @visibleForTesting
  E expectError() => fold(
    onSuccess: (_) => throw StateError(
      'Result.expectError() was called on a success result.',
    ),
    onError: (e) => e,
  );

  /// Returns the value if this is an [Ok].
  ///
  /// If this is an error result, the [orElse] function is called with the error
  /// value to determine the result.
  T getOrElse(T Function(E) orElse) {
    return fold(
      onSuccess: (result) {
        return result;
      },
      onError: (err) {
        return orElse(err);
      },
    );
  }

  /// Executes [onSuccess] if the result is an [Ok], or [onError] if it is
  /// an [Err].
  void when({
    required void Function(T) onSuccess,
    required void Function(E) onError,
  }) {
    fold(
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  /// Transforms the success value using [fn].
  ///
  /// If the result is [Err], the error is propagated.
  Result<R, E> map<R>(R Function(T) fn) {
    return fold(
      onSuccess: (value) => Ok(fn(value)),
      onError: Err.new,
    );
  }

  /// Chains another [Result] operation when this result is [Ok].
  ///
  /// If this result is [Err], the error is propagated and [fn] is not called.
  Result<R, E> flatMap<R>(Result<R, E> Function(T) fn) {
    return fold(
      onSuccess: fn,
      onError: Err.new,
    );
  }

  /// Alias for [flatMap].
  Result<R, E> andThen<R>(Result<R, E> Function(T) fn) => flatMap(fn);

  /// Transforms the error value using [fn].
  ///
  /// If the result is [Ok], the value is propagated.
  Result<T, R> mapError<R>(R Function(E) fn) {
    return fold(
      onSuccess: Ok.new,
      onError: (error) => Err(fn(error)),
    );
  }
}

/// A [Result] representing a successful operation.
final class Ok<T, E> extends Result<T, E> {
  /// Creates an [Ok] with the given [value].
  const Ok(this.value);

  /// The successful value.
  final T value;

  @override
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(E) onError,
  }) {
    return onSuccess(value);
  }

  @override
  String toString() => 'Ok($value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Ok<T, E>) {
      return value == other.value;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Ok, T, E, value);
}

/// A [Result] representing a failed operation.
final class Err<T, E> extends Result<T, E> {
  /// Creates an [Err] with the given [error].
  const Err(this.error);

  /// The error value.
  final E error;

  @override
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(E) onError,
  }) {
    return onError(error);
  }

  @override
  String toString() => 'Err($error)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Err<T, E>) {
      return error == other.error;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Err, T, E, error);
}
