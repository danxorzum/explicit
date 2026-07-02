import 'package:explicit_outcome/explicit_outcome.dart';
import 'package:meta/meta.dart';

/// Adapter extension to convert a lazy closure returning `Future<Opt<T>>`
/// into an [AsyncOpt].
///
/// The closure is not invoked until [AsyncOpt.run] is called, preserving
/// laziness. Each call to [AsyncOpt.run] re-invokes the closure — there is
/// no hidden caching.
///
/// Example:
/// ```dart
/// Future<Opt<int>> fetchCount() async => Val(42);
/// final asyncOpt = fetchCount.toAsyncOpt();
/// ```
@experimental
extension AsyncOptRecipe<T extends Object> on Future<Opt<T>> Function() {
  /// Wraps this lazy closure as an [AsyncOpt].
  ///
  /// The closure is not executed until [AsyncOpt.run] is called.
  @experimental
  AsyncOpt<T> toAsyncOpt() => AsyncOpt<T>(this);
}

/// Adapter extension to convert a lazy closure returning `Future<Res<T, E>>`
/// into an [AsyncRes].
///
/// The closure is not invoked until [AsyncRes.run] is called, preserving
/// laziness. Each call to [AsyncRes.run] re-invokes the closure — there is
/// no hidden caching.
///
/// Example:
/// ```dart
/// Future<Res<int, String>> fetchCount() async => Ok(42);
/// final asyncRes = fetchCount.toAsyncRes();
/// ```
@experimental
extension AsyncResRecipe<T extends Object, E extends Object>
    on Future<Res<T, E>> Function() {
  /// Wraps this lazy closure as an [AsyncRes].
  ///
  /// The closure is not executed until [AsyncRes.run] is called.
  @experimental
  AsyncRes<T, E> toAsyncRes() => AsyncRes<T, E>(this);
}
