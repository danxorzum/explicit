import 'package:meta/meta.dart';

/// Compact alias for [Result].
///
/// ## Result
/// {@macro result}
typedef Res<T extends Object, E extends Object> = Result<T, E>;

/// Compatibility alias for [Ok].
typedef Success<T extends Object, E extends Object> = Ok<T, E>;

/// Compatibility alias for [Err].
typedef Failure<T extends Object, E extends Object> = Err<T, E>;

/// {@template result}
/// A generic [Result] type that represents either an [Ok] success or an [Err]
/// error.
///
/// Use [Result] to make success and error states explicit without throwing
/// exceptions for expected failures.
/// - [Ok] means a success value is present.
/// - [Err] means an error value is present.
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
/// final doubled = result.next((value) => Ok<int, String>(value * 2));
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
sealed class Result<T extends Object, E extends Object> {
  const Result();

  /// Executes [onSuccess] if this is an [Ok], or [onError] if this is an
  /// [Err].
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

  /// Returns the value if this is an [Ok].
  ///
  /// If this is an [Err], the [fallback] function is called with the error
  /// value to provide a value.
  T getOrElse(T Function(E) fallback) {
    return fold(
      onSuccess: (value) => value,
      onError: fallback,
    );
  }

  /// Executes [onSuccess] if this is an [Ok], or [onError] if this is an
  /// [Err].
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
  /// If this is an [Err], the error is propagated.
  Res<R, E> map<R extends Object>(R Function(T) fn) {
    return fold(
      onSuccess: (value) => Ok(fn(value)),
      onError: Err.new,
    );
  }

  /// Chains another [Result] operation when this result is [Ok].
  ///
  /// If this is an [Err], the error is propagated and [fn] is not called.
  Res<R, E> next<R extends Object>(Res<R, E> Function(T) fn) {
    return fold(
      onSuccess: fn,
      onError: Err.new,
    );
  }

  /// Transforms the error value using [fn].
  ///
  /// If this is an [Ok], the value is propagated.
  Res<T, R> mapError<R extends Object>(R Function(E) fn) {
    return fold(
      onSuccess: Ok.new,
      onError: (error) => Err(fn(error)),
    );
  }

  /// Returns this result if it is [Ok], or calls [fn] with the error.
  ///
  /// If this is an [Ok], the success value is preserved and [fn] is not called.
  /// If this is an [Err], [fn] receives the error and its result is returned.
  Res<T, E> or(Res<T, E> Function(E error) fn) {
    return fold(
      onSuccess: Ok.new,
      onError: fn,
    );
  }
}

/// A [Result] representing a successful operation.
final class Ok<T extends Object, E extends Object> extends Result<T, E> {
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
final class Err<T extends Object, E extends Object> extends Result<T, E> {
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
