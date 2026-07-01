import 'package:meta/meta.dart';

/// Compact alias for [Option].
///
/// ## Option
/// {@macro option}
typedef Opt<T extends Object> = Option<T>;

/// {@template option}
/// A generic [Option] type that represents either a [Val] value or a [Nil]
/// (absence of value).
///
/// Use [Option] to make presence and absence explicit without throwing
/// exceptions or hiding absence behind `null`.
/// - [Val] means a value is present.
/// - [Nil] means no value is present.
/// - [T] is non-nullable; [Val] cannot wrap `null`. Use [Nil] to represent
///   absence.
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
/// final doubled = option.next((value) => Val(value * 2));
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
sealed class Option<T extends Object> {
  const Option();

  /// Executes [onVal] if this is an [Val], or [onNil] if it is
  /// a [Nil].
  ///
  /// Returns the value produced by the executed function.
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
  /// If this is a [Nil], the [fallback] function is called to provide a value.
  T getOrElse(T Function() fallback) {
    return fold(
      onVal: (value) => value,
      onNil: () => fallback(),
    );
  }

  /// Executes [onVal] if this is an [Val], or [onNil] if it is
  /// a [Nil].
  void when({
    required void Function(T) onVal,
    required void Function() onNil,
  }) {
    fold(onVal: onVal, onNil: onNil);
  }

  /// Transforms the present value using [fn].
  Opt<R> map<R extends Object>(R Function(T) fn) {
    return fold(
      onVal: (value) => Val(fn(value)),
      onNil: Nil<R>.new,
    );
  }

  /// Chains another [Option] operation when this option is [Val].
  ///
  /// If this option is [Nil], [fn] is not called.
  Opt<R> next<R extends Object>(Opt<R> Function(T) fn) {
    return fold(
      onVal: fn,
      onNil: Nil<R>.new,
    );
  }

  /// Chains another [Option] operation when this option is [Nil].
  ///
  /// If this option is [Val], [fn] is not called.
  Opt<T> or(Opt<T> Function() fn) => fold(onVal: Val.new, onNil: fn);
}

/// An [Option] representing a present, non-null value.
final class Val<T extends Object> extends Opt<T> {
  /// Creates an [Val] with the given [value].
  const Val(this.value);

  /// The present value.
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

/// An [Option] representing absence of a value.
final class Nil<T extends Object> extends Opt<T> {
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
