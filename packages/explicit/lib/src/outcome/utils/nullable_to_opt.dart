import 'package:explicit_outcome/explicit_outcome.dart';

/// Extension on nullable types to convert to [Opt].
///
/// Converts a nullable value to an [Opt]:
/// - `null` becomes [Nil]
/// - non-null values become `Val<T>` with non-nullable payload type
///
/// Example:
/// ```dart
/// String? maybeName = getName();
/// Opt<String> nameOpt = maybeName.toOpt;
/// ```
extension NullableToOpt<T extends Object> on T? {
  /// Converts this nullable value to an [Opt].
  ///
  /// Returns [Nil] if this is `null`, otherwise returns [Val] with the
  /// non-null value.
  Opt<T> get toOpt => this == null ? Nil<T>() : Val<T>(this!);
}
