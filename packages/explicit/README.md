# Explicit

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MPL-2.0][license_badge]][license_link]
[![Dart 3.12+][dart_badge]][dart_link]
[![Coverage 100%][coverage_badge]][coverage_link]

A compact library for explicit, predictable, and readable Dart.

Design your software without implicit surprises. `Explicit` is a foundational approach to writing code where control flow and state changes are clearly defined, leaving no room for ambiguity.

Use it to model operations with a simple [Result][result_wikipedia] toolkit. Eliminate hidden exceptions, chain operations in declaration order, and compose lazy async pipelines with predictable short-circuiting.

## Quick Start

1. **Add the dependency**:

   ```sh
   dart pub add explicit
   ```

2. **Model success and failure** with `Ok` and `Err`:

   ```dart
   import 'package:explicit/explicit.dart';

   Result<int, String> divide(int a, int b) {
     if (b == 0) return Err<int, String>('division by zero');
     return Ok<int, String>(a ~/ b);
   }
   ```

   or even more compactly with the `Res` alias:

   ```dart
   Res<int, String> divide(int a, int b) {
     if (b == 0) return Err('division by zero'); // The type parameters can be inferred.
     return Ok(a ~/ b);
   }
   ```

3. **Handle the result** with `fold`, `when`, `getOrElse`, or `expect`:

   ```dart
   final result = divide(10, 2);

   final message = result.fold(
     onSuccess: (value) => 'got $value',
     onError: (error) => 'failed: $error',
   );
   ```

   4. **Chain operations safely** without implicit try/catch blocks. If any step fails, the chain short-circuits gracefully:

   ```dart
   final message = divide(10, 2)
       .map((value) => value * 10) // Only runs if the division was successful
       .fold(
         onSuccess: (value) => 'Final result: $value',
         onError: (error) => 'Operation failed: $error',
       );
   ```

## Motivation

This library was born out of a pragmatic necessity: the continuous extraction of the same core primitives across multiple projects.

In modern software development, code must be more than just functional; it must be a clear, unambiguous contract. Implicit control flows, hidden exceptions, and unpredictable side effects make codebases fragile and hard to read. `explicit` is designed to be the reliable heart of any application, enforcing a style where every case and edge case is handled by design.

### The Philosophy

The core tenet is simple: **Explicit Programming**. Whether you are building reactive, functional, or deeply object-oriented systems, the code should be declarative and self-documenting. If an operation can fail, that failure should be part of the method's signature.

### Pragmatic, not Purist

While heavily inspired by Functional Programming (FP) concepts like immutability and predictable state, `explicit` is **not** a full-blown FP library. There are already excellent libraries in the Dart ecosystem for strict functional paradigms. Instead, this package focuses on the highest-impact, lowest-friction patterns. It provides the essential building blocks to prevent side effects and keep your architecture highly readable, without forcing your team to learn complex mathematical theories.

Stop rewriting the same boilerplate to defend against implicit behavior. `explicit` provides the standardized foundation to build software that simply does what it says.

## Features

| Feature             | API                                                      | Notes                                                                 |
| ------------------- | -------------------------------------------------------- | --------------------------------------------------------------------- |
| Compact sync result | `Res<T, E>`, `Ok<T, E>`, `Err<T, E>`                     | `Res` is a typedef for the sealed `Result<T, E>` base.                |
| Composition         | `map`, `mapError`, `flatMap`, `andThen`                  | `andThen` is an alias for `flatMap` for callers that prefer the name. |
| Branch handling     | `fold`, `when`, `getOrElse`                              | `fold` returns a value; `when` is for side effects.                   |
| Programmer errors   | `expect`, `expectError`                                  | Both throw `StateError` when called on the wrong variant.             |
| Record access       | `toRecord` (deprecated)                                  | Kept for compatibility; prefer `fold` for new code.                   |
| Lazy async          | `AsyncRes<T, E>` with `run`, `map`, `flatMap`, `andThen` | Work does not start until `run()` is called.                          |
| Retry               | `retry(operation, maxAttempts: 3)`                       | Standalone function; throws `ArgumentError` for `maxAttempts <= 0`.   |
| Compatibility       | `Success<T, E>`, `Failure<T, E>`                         | Typedef aliases for `Ok` and `Err` to ease migration.                 |

## Usage

### 1. Build results with `Ok` and `Err`

`Res<T, E>` is the compact alias for the sealed `Result<T, E>` base. Use `Ok`
to wrap a success value and `Err` to wrap an error.

```dart
Res<int, String> parsePort(String raw) {
  final value = int.tryParse(raw);
  if (value == null || value < 1 || value > 65535) {
    return Err<int, String>('invalid port: $raw');
  }
  return Ok<int, String>(value);
}
```

`E` is intentionally unconstrained: this library models recoverable failures as
data, not thrown control flow. Use `String`, custom error records, or domain
objects — whatever fits the call site.

### 2. Compose results with `map`, `mapError`, and `flatMap`

All composition methods preserve the sealed type and short-circuit on `Err`.

```dart
final result = parsePort('8080')
    .map((port) => 'http://localhost:$port')
    .mapError((error) => 'ConfigurationError: $error')
    .flatMap((url) => fetchHealth(url)); // returns Res<bool, String>
```

`andThen` is provided as an alias of `flatMap` for callers that prefer
railway-oriented naming:

```dart
final chained = parsePort('8080')
    .andThen((port) => Ok<int, String>(port * 2));
```

### 3. Branch on results

`fold` returns a value from either branch. `when` is for side effects without
allocating a return value. `getOrElse` lets the error branch compute a default.

```dart
final summary = result.fold(
  onSuccess: (value) => 'OK: $value',
  onError: (error) => 'ERR: $error',
);

result.when(
  onSuccess: (value) => print('value=$value'),
  onError: (error) => print('error=$error'),
);

final value = result.getOrElse((error) => -1);
```

`expect` and `expectError` are escape hatches for tests and invariants. They
**throw `StateError`** when called on the wrong variant, signaling a programmer
error rather than a recoverable failure:

```dart
final value = okResult.expect();    // returns the wrapped value
final error = errResult.expectError(); // returns the wrapped error

okResult.expectError();   // throws StateError
errResult.expect();       // throws StateError
```

### 4. Record access

`toRecord()` returns a `(T? value, E? error)` record. One slot is always
`null`, so always check `isSuccess` or `isFailure` before reading the payload.
The API is kept for compatibility but new code should prefer `fold` or
pattern matching:

```dart
// ignore_for_file: deprecated_member_use_from_same_package
final record = result.toRecord();
if (result.isSuccess) {
  print('value=${record.$1}');
} else {
  print('error=${record.$2}');
}
```

### 5. Compose async pipelines with `AsyncRes`

`AsyncRes<T, E>` wraps a `Future<Res<T, E>>` and defers execution until
`run()` is called. `map` and `flatMap` return new lazy `AsyncRes` values and
preserve declaration order. After an `Err`, the chain short-circuits — no
downstream step is invoked.

```dart
final pipeline = AsyncRes<int, String>(() async => Ok<int, String>(2))
    .map((value) => value + 3)
    .flatMap((value) => AsyncRes<int, String>(
      () async => Ok<int, String>(value * 10),
    ))
    .map((value) => 'final=$value');

final result = await pipeline.run(); // Res<String, String>
```

Nothing runs until `run()`. Calling `run()` multiple times re-executes the
pipeline, which is useful for retries and replays.

### 6. Retry transient failures

`retry` is a standalone utility (not a method on `AsyncRes`). It repeatedly
calls the async operation until it returns `Ok` or the attempt budget is
exhausted. `maxAttempts` must be greater than zero; otherwise the function
throws `ArgumentError` synchronously.

```dart
Future<Res<String, String>> flakyFetch() async {
  // Imagine a network call that can fail.
  return Err<String, String>('transient');
}

final result = await retry<String, String>(
  flakyFetch,
  maxAttempts: 5,
);

result.when(
  onSuccess: (body) => print('body=$body'),
  onError: (error) => print('gave up: $error'),
);
```

## API reference

| Symbol                              | Kind         | Description                                                                       |
| ----------------------------------- | ------------ | --------------------------------------------------------------------------------- |
| `Res<T, E>`                         | typedef      | Compact alias for `Result<T, E>`.                                                 |
| `Result<T, E>`                      | sealed class | Base type. Pattern-match with `case Ok(:final value)` / `case Err(:final error)`. |
| `Ok<T, E>`                          | class        | Success variant.                                                                  |
| `Err<T, E>`                         | class        | Error variant.                                                                    |
| `Result.fold`                       | method       | Branch on the variant and return a value.                                         |
| `Result.map`                        | method       | Transform the success value.                                                      |
| `Result.mapError`                   | method       | Transform the error value.                                                        |
| `Result.flatMap` / `Result.andThen` | method       | Chain another `Result`-returning function.                                        |
| `Result.when`                       | method       | Side-effect-only branching.                                                       |
| `Result.getOrElse`                  | method       | Provide a default from the error branch.                                          |
| `Result.expect`                     | method       | Returns the value or throws `StateError`.                                         |
| `Result.expectError`                | method       | Returns the error or throws `StateError`.                                         |
| `Result.toRecord` (deprecated)      | method       | Record representation `(T?, E?)`.                                                 |
| `Success<T, E>`                     | typedef      | Compatibility alias for `Ok`.                                                     |
| `Failure<T, E>`                     | typedef      | Compatibility alias for `Err`.                                                    |
| `AsyncRes<T, E>`                    | class        | Lazy async pipeline. `run`, `map`, `flatMap`, `andThen`.                          |
| `retry<T, E>`                       | function     | Repeat an async operation up to `maxAttempts`.                                    |

## Example

A runnable Very Good CLI Dart app lives in [`example/`](example/). It has its
own `pubspec.yaml` with a path dependency back to this package and uses the VGV
Dart CLI layout at
[`example/bin/explicit_example.dart`](example/bin/explicit_example.dart).

The app walks through success, failure, `flatMap`/`andThen`, `toRecord`, the
lazy `AsyncRes` pipeline, `AsyncRes` with `retry`, and awaited async
composition. Run it from the example directory:

```sh
cd example
dart pub get
dart run
```

## Testing and coverage

The package uses `package:test` and `mocktail` and follows the
`result_fold_test.dart` Table-Driven Test Cases (TCT) style across the entire
test suite. To run everything locally:

```sh
dart pub get
dart test --coverage=coverage
dart run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info \
  --package=. --report-on=lib
```

Line coverage for `lib/src/outcome/*.dart` and `lib/src/utils/*.dart` is
**100%** (75/75 lines) as enforced by the SDD testing slice.

## Continuous Integration

The repository ships a [GitHub Actions][github_actions_link] workflow that
formats, lints, tests, and reports coverage on every push and pull request.
Lints follow [Very Good Analysis][very_good_analysis_link].

## Compatibility

- **Dart SDK:** `^3.12.0` (sealed classes, pattern matching, records).
- **License:** [Mozilla Public License 2.0][license_link] (MPL-2.0).

[result_wikipedia]: https://en.wikipedia.org/wiki/Result_type
[license_badge]: https://img.shields.io/badge/license-MPL_2.0-blue.svg
[license_link]: https://opensource.org/licenses/MPL-2.0
[dart_badge]: https://img.shields.io/badge/dart-%5E3.12.0-blue.svg
[dart_link]: https://dart.dev/get-dart
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[coverage_badge]: https://img.shields.io/badge/coverage-100%25-brightgreen.svg
[coverage_link]: coverage/lcov.info
[github_actions_link]: https://docs.github.com/en/actions
