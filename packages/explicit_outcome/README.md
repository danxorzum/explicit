# Explicit Outcome

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MPL-2.0][license_badge]][license_link]
[![Dart 3.12+][dart_badge]][dart_link]

Typed outcomes for explicit, predictable Dart development.

`explicit_outcome` provides `Result` and `Option` types — sealed, pattern-matchable containers that make success, failure, presence, and absence first-class citizens in your type signatures.

## Installation

```sh
dart pub add explicit_outcome
```

> Most users should install [`explicit`](https://pub.dev/packages/explicit) instead, which re-exports these types and adds ergonomic utilities. Use `explicit_outcome` directly only when you need the low-level outcome types without additional utilities.

## Result: `Res<T, E>`

Model operations that can succeed with a value or fail with an error — without throwing exceptions.

```dart
import 'package:explicit_outcome/explicit_outcome.dart';

Res<int, String> parsePort(String raw) {
  final value = int.tryParse(raw);
  if (value == null || value < 1 || value > 65535) {
    return Err('invalid port: $raw');
  }
  return Ok(value);
}
```

### Creating results

| Constructor | Purpose |
|---|---|
| `Ok<T, E>(value)` | Wrap a success value. |
| `Err<T, E>(error)` | Wrap an error value. |
| `Res<T, E>` | Compact typedef for `Result<T, E>`. |
| `Success<T, E>` | Compatibility alias for `Ok`. |
| `Failure<T, E>` | Compatibility alias for `Err`. |

### Consuming results

```dart
final result = parsePort('8080');

// Branch and return a value:
final message = result.fold(
  onSuccess: (port) => 'port=$port',
  onError: (error) => 'error=$error',
);

// Branch for side effects:
result.when(
  onSuccess: (port) => print('port=$port'),
  onError: (error) => print('error=$error'),
);

// Provide a default on error:
final port = result.getOrElse((error) => 8080);

// Pattern match:
switch (result) {
  case Ok(:final value):
    print('success: $value');
  case Err(:final error):
    print('error: $error');
}
```

### Composing results

```dart
final pipeline = parsePort('8080')
    .map((port) => 'http://localhost:$port')       // transform success
    .mapError((e) => 'ConfigError: $e')            // transform error
    .next((url) => checkUrl(url))                  // chain another Result operation
    .or((error) => Ok('http://localhost:8080'));   // recover from error
```

| Method | Signature | Behavior |
|---|---|---|
| `map` | `Res<R, E> map<R>(R Function(T))` | Transform the success value. Short-circuits on `Err`. |
| `mapError` | `Res<T, R> mapError<R>(R Function(E))` | Transform the error value. Short-circuits on `Ok`. |
| `next` | `Res<R, E> next<R>(Res<R, E> Function(T))` | Chain another result-returning operation. Short-circuits on `Err`. |
| `or` | `Res<T, E> or(Res<T, E> Function(E))` | Recover from error with an alternative result. |
| `fold` | `R fold<R>({R Function(T), R Function(E)})` | Branch on variant and return a value. |
| `when` | `void when({void Function(T), void Function(E)})` | Branch for side effects. |
| `getOrElse` | `T getOrElse(T Function(E))` | Return value or compute a default from the error. |
| `isSuccess` | `bool` | `true` if `Ok`. |
| `isFailure` | `bool` | `true` if `Err`. |

## Option: `Opt<T>`

Model presence and absence without `null`.

```dart
Opt<int> findIndex(List<String> items, String target) {
  final index = items.indexOf(target);
  if (index == -1) return Nil();
  return Val(index);
}
```

### Creating options

| Constructor | Purpose |
|---|---|
| `Val<T>(value)` | Wrap a present value. |
| `Nil<T>()` | Represent absence. |
| `Opt<T>` | Compact typedef for `Option<T>`. |

### Consuming options

```dart
final option = findIndex(names, 'Alice');

final label = option.fold(
  onVal: (i) => 'Found at $i',
  onNil: () => 'Not found',
);

option.when(
  onVal: (i) => print('index=$i'),
  onNil: () => print('absent'),
);

final index = option.getOrElse(() => -1);
```

### Composing options

```dart
final result = findIndex(names, 'Alice')
    .map((i) => names[i].toUpperCase())
    .next((name) => validateName(name))
    .or(() => Val('DEFAULT'));
```

| Method | Signature | Behavior |
|---|---|---|
| `map` | `Opt<R> map<R>(R Function(T))` | Transform the present value. Propagates `Nil`. |
| `next` | `Opt<R> next<R>(Opt<R> Function(T))` | Chain another option-returning operation. Propagates `Nil`. |
| `or` | `Opt<T> or(Opt<T> Function())` | Provide an alternative when `Nil`. |
| `fold` | `R fold<R>({R Function(T), R Function()})` | Branch on variant and return a value. |
| `when` | `void when({void Function(T), void Function()})` | Branch for side effects. |
| `getOrElse` | `T getOrElse(T Function())` | Return value or compute a default. |
| `hasValue` | `bool` | `true` if `Val`. |
| `isNil` | `bool` | `true` if `Nil`. |

## Async: `AsyncRes<T, E>` and `AsyncOpt<T>`

Lazy asynchronous wrappers. Work does not start until `run()` is called.

```dart
final pipeline = AsyncRes<int, String>(() async => Ok(2))
    .map((v) => v + 3)
    .next((v) => AsyncRes(() async => Ok(v * 10)));

final result = await pipeline.run(); // Res<int, String>
```

### Semantics

| Behavior | Detail |
|---|---|
| **Lazy** | No work happens until `run()` is called. |
| **Short-circuit** | After `Err`/`Nil`, downstream steps are not invoked. |
| **No caching** | Each `run()` re-executes the pipeline. |
| **No retry** | Failures are not retried. |
| **No catching** | Thrown exceptions propagate; use `fold` for expected failures. |

### AsyncRes methods

| Method | Description |
|---|---|
| `run()` | Execute and return `Future<Res<T, E>>`. |
| `map` | Transform the success value (lazy). |
| `next` | Chain another `AsyncRes` operation (lazy). |
| `mapError` | Transform the error value (lazy). |
| `or` | Recover from error (lazy). |

### AsyncOpt methods

| Method | Description |
|---|---|
| `run()` | Execute and return `Future<Opt<T>>`. |
| `map` | Transform the present value (lazy). |
| `next` | Chain another `AsyncOpt` operation (lazy). |
| `or` | Provide an alternative when `Nil` (lazy). |
| `fold` | Await and branch (convenience extension). |
| `when` | Await and side-effect (convenience extension). |
| `getOrElse` | Await and default (convenience extension). |
| `hasValue` | Await and check for `Val` (convenience extension). |
| `isNil` | Await and check for `Nil` (convenience extension). |

`ResultAsync<T, E>` and `OptionAsync<T>` are convenience typedefs for `Future<Res<T, E>>` and `Future<Opt<T>>` respectively.

## API Summary

| Symbol | Kind | Description |
|---|---|---|
| `Res<T, E>` | typedef | Compact alias for `Result<T, E>`. |
| `Result<T, E>` | sealed class | Base type for success/error. |
| `Ok<T, E>` | class | Success variant. |
| `Err<T, E>` | class | Error variant. |
| `Opt<T>` | typedef | Compact alias for `Option<T>`. |
| `Option<T>` | sealed class | Base type for present/absent. |
| `Val<T>` | class | Present option variant. |
| `Nil<T>` | class | Absent option variant. |
| `ResultAsync<T, E>` | typedef | `Future<Res<T, E>>`. |
| `AsyncRes<T, E>` | class | Lazy async result. |
| `OptionAsync<T>` | typedef | `Future<Opt<T>>`. |
| `AsyncOpt<T>` | class | Lazy async option. |
| `Success<T, E>` | typedef | Compatibility alias for `Ok`. |
| `Failure<T, E>` | typedef | Compatibility alias for `Err`. |

## Compatibility

- **Dart SDK:** `^3.12.0` (sealed classes, pattern matching, records).
- **License:** [Mozilla Public License 2.0][license_link] (MPL-2.0).

[license_badge]: https://img.shields.io/badge/license-MPL_2.0-blue.svg
[license_link]: https://opensource.org/licenses/MPL-2.0
[dart_badge]: https://img.shields.io/badge/dart-%5E3.12.0-blue.svg
[dart_link]: https://dart.dev/get-dart
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
