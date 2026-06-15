import 'package:explicit/src/outcome/outcome.dart';

/// Retries an asynchronous operation up to [maxAttempts].
///
/// [maxAttempts] must be greater than zero.
AsyncResult<T, E> retry<T, E>(
  AsyncResult<T, E> Function() operation, {
  int maxAttempts = 3,
}) {
  if (maxAttempts <= 0) {
    throw ArgumentError.value(
      maxAttempts,
      'maxAttempts',
      'must be greater than zero',
    );
  }

  return _retry(operation, maxAttempts: maxAttempts);
}

Future<Result<T, E>> _retry<T, E>(
  AsyncResult<T, E> Function() operation, {
  required int maxAttempts,
}) async {
  Result<T, E>? lastResult;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final result = await operation();
    if (result.isSuccess) return result;
    lastResult = result;
  }

  return lastResult!;
}
