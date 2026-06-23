import 'package:meta/meta.dart';

/// Alias for an asynchronous [Option].
typedef AsyncOption<T> = Future<Option<T>>;

/// Compact alias for [Option].
typedef Opt<T> = Option<T>;

/// {@template option}
/// A generic [Option] type that represents either a [Val] value or a [Nil]
/// (absence of value).
///
/// Use [Option] to handle operations that can fail by returning no value
/// without throwing exceptions.
/// - [T] is the type of the success value.
///
/// ### Example:
/// ```dart
/// final option = Val<int>(42);
///
/// option.fold(
///   onVal: (value) => print('Value: $value'),
///   onNil: () => print('No value'),
/// );
///
/// option.next(
///  onVal: (value) =>  Val(value * 2),
///  onNil: () => Nil(),
/// );
///
/// switch (option) {
///   case Val<int>(:final value):
///     print('Value: $value');
///   case Nil<int>():
///     print('No value');
/// }
/// ```
/// {@endtemplate}
@immutable
sealed class Option<T> {
  const Option();

  /// Executes [onVal] if the result is an [Val], or [onNil] if it is
  /// a [Nil].
  ///
  /// Returns the result of the executed function.
  R fold<R>({
    required R Function(T) onVal,
    required R Function() onNil,
  });

  /// Returns `true` if this is an [Val].
  bool get hasValue => fold(onVal: (_) => true, onNil: () => false);

  /// Returns `true` if this is an [Nil].
  bool get isNil => fold(onVal: (_) => false, onNil: () => true);

  /// Returns the value if this is an [Val].
  ///
  /// If this is a [Nil], the [fallback] function is called with the error
  /// value to determine the result.
  T getOrElse(T Function() fallback) {
    return fold(
      onVal: (result) => result,
      onNil: () => fallback(),
    );
  }

  /// Executes [onVal] if the result is an [Val], or [onNil] if it is
  /// a [Nil].
  void when({
    required void Function(T) onVal,
    required void Function() onNil,
  }) {
    fold(onVal: onVal, onNil: onNil);
  }

  /// Transforms the success value using [fn].
  Opt<R> map<R>(R Function(T) fn) {
    return fold(
      onVal: (value) => Val(fn(value)),
      onNil: Nil<R>.new,
    );
  }

  /// Chains another [Option] operation when this result is [Val].
  ///
  /// If this result is [Nil], the error is propagated and [fn] is not called.
  Opt<R> next<R>(Opt<R> Function(T) fn) {
    return fold(
      onVal: fn,
      onNil: Nil<R>.new,
    );
  }
}

/// A [Option] representing a successful operation.
final class Val<T> extends Opt<T> {
  /// Creates an [Val] with the given [value].
  const Val(this.value);

  /// The successful value.
  final T value;

  @override
  R fold<R>({
    required R Function(T) onVal,
    required R Function() onNil,
  }) {
    return onVal(value);
  }

  @override
  String toString() => 'Val($value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Val<T>) {
      return value == other.value;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Val, T, value);
}

/// A [Option] representing a failed operation.
final class Nil<T> extends Opt<T> {
  /// Creates an [Nil].
  const Nil();

  @override
  R fold<R>({
    required R Function(T) onVal,
    required R Function() onNil,
  }) {
    return onNil();
  }

  @override
  String toString() => 'Nil';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Nil<T>) {
      return true;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Nil, T);
}
