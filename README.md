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

## Architecture

`explicit` is a **facade** over [`explicit_outcome`][explicit_outcome_link]. Core primitives (`Res`, `Opt`, `AsyncRes`, `AsyncOpt`) live in `explicit_outcome` and are re-exported through this package. The facade adds ergonomic utilities for nullable conversion, lazy closure adapters, and experimental parallel composition — without changing primitive behavior.

```
package:explicit/explicit.dart
  ├── explicit_outcome primitives (re-exported)
  │   ├── Res<T, E>, Ok, Err, AsyncRes
  │   └── Opt<T>, Val, Nil, AsyncOpt
  └── facade utilities
      ├── .toOpt (nullable conversion)
      ├── .toAsyncOpt() / .toAsyncRes() (closure adapters)
      └── ParallelOpt2..5 / ParallelRes2..5 (experimental)
```

## Features

| Feature | API | Notes |
|---|---|---|
| Compact sync result | `Res<T, E>`, `Ok<T, E>`, `Err<T, E>` | `Res` is a typedef for the sealed `Result<T, E>` base. |
| Option type | `Opt<T>`, `Val<T>`, `Nil` | Nullable-safe option type from `explicit_outcome`. |
| Composition | `map`, `mapError`, `flatMap`, `andThen` | `andThen` is an alias for `flatMap` for callers that prefer the name. |
| Branch handling | `fold`, `when`, `getOrElse` | `fold` returns a value; `when` is for side effects. |
| Programmer errors | `expect`, `expectError` | Both throw `StateError` when called on the wrong variant. |
| Lazy async | `AsyncRes<T, E>`, `AsyncOpt<T>` | Work does not start until `run()` is called. |
| Nullable conversion | `.toOpt` extension | `null` → `Nil`, non-null → `Val<T>` with non-nullable payload. |
| Closure adapters | `.toAsyncOpt()`, `.toAsyncRes()` | Wrap lazy closures as `AsyncOpt`/`AsyncRes`. Experimental. |
| Parallel composition | `ParallelOpt2..5`, `ParallelRes2..5` | Concurrent lazy execution with typed records. Experimental. |
| Compatibility | `Success<T, E>`, `Failure<T, E>` | Typedef aliases for `Ok` and `Err` to ease migration. |

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

### 4. Convert nullable values with `.toOpt`

The `.toOpt` extension converts any nullable value to an `Opt<T>`. `null`
becomes `Nil`, and non-null values become `Val<T>` with a non-nullable
payload type enforced by the analyzer.

```dart
String? maybeName = fetchName();
Opt<String> nameOpt = maybeName.toOpt;

// Pattern match on the result:
switch (nameOpt) {
  case Val(:final value):
    print('name=$value');
  case Nil():
    print('no name');
}
```

The payload type `T` is constrained to `extends Object`, so the analyzer
rejects `Opt<int?>` — the payload is always non-null after conversion.

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
pipeline — there is no hidden caching or memoization.

### 6. Adapt lazy closures with `.toAsyncOpt()` / `.toAsyncRes()`

When you have a closure that returns a `Future<Opt<T>>` or `Future<Res<T, E>>`,
use the adapter extensions to wrap it as an `AsyncOpt` or `AsyncRes` without
invoking the closure eagerly.

```dart
Future<Opt<int>> fetchCount() async => Val(42);

// The closure is NOT called here — just wrapped:
final asyncOpt = fetchCount.toAsyncOpt();

// Work starts only when you call run():
final result = await asyncOpt.run(); // Opt<int>
```

```dart
Future<Res<String, String>> fetchBody() async => Ok('hello');

final asyncRes = fetchBody.toAsyncRes();
final result = await asyncRes.run(); // Res<String, String>
```

Each call to `run()` re-invokes the closure. There is no hidden caching.

### 7. Run recipes in parallel with `ParallelOpt` / `ParallelRes` (experimental)

> **Experimental**: These classes are marked `@experimental` and may change
> in future versions.

`ParallelOpt2` through `ParallelOpt5` run multiple `AsyncOpt` recipes
concurrently and combine results into a typed record. `ParallelRes2` through
`ParallelRes5` do the same for `AsyncRes` recipes.

```dart
final asyncOptA = AsyncOpt<int>(() async => Val(1));
final asyncOptB = AsyncOpt<String>(() async => Val('hello'));

final parallel = ParallelOpt2(asyncOptA, asyncOptB);
final result = await parallel.run(); // Opt<(int, String)>
// result is Val((1, 'hello'))
```

```dart
final asyncResA = AsyncRes<int, String>(() async => Ok(1));
final asyncResB = AsyncRes<String, String>(() async => Ok('hello'));

final parallel = ParallelRes2(asyncResA, asyncResB);
final result = await parallel.run(); // Res<(int, String), String>
// result is Ok((1, 'hello'))
```

#### Key semantics

| Behavior | Detail |
|---|---|
| **Laziness** | No work happens until `.run()` is called. Construction stores recipes only. |
| **Repeated runs** | Each `.run()` re-executes all recipes. There is no hidden caching. |
| **Nil propagation** | `ParallelOpt`: if any recipe produces `Nil`, the result is `Nil`. |
| **Error propagation** | `ParallelRes`: if any recipe produces `Err`, the result is the first `Err` by parameter order. |
| **No hidden retry** | Classes do not retry, catch, or convert thrown exceptions. |
| **No hidden caching** | Each `.run()` starts fresh. Caller controls memoization externally. |
| **Typed records** | Results use Dart records `(A, B)`, `(A, B, C)`, etc. — no `List<dynamic>` casts. |

#### Available arities

| Class | Recipes | Result type |
|---|---|---|
| `ParallelOpt2` | 2 × `AsyncOpt` | `Future<Opt<(A, B)>>` |
| `ParallelOpt3` | 3 × `AsyncOpt` | `Future<Opt<(A, B, C)>>` |
| `ParallelOpt4` | 4 × `AsyncOpt` | `Future<Opt<(A, B, C, D)>>` |
| `ParallelOpt5` | 5 × `AsyncOpt` | `Future<Opt<(A, B, C, D, E)>>` |
| `ParallelRes2` | 2 × `AsyncRes` | `Future<Res<(A, B), E>>` |
| `ParallelRes3` | 3 × `AsyncRes` | `Future<Res<(A, B, C), E>>` |
| `ParallelRes4` | 4 × `AsyncRes` | `Future<Res<(A, B, C, D), E>>` |
| `ParallelRes5` | 5 × `AsyncRes` | `Future<Res<(A, B, C, D, F), E>>` |

There are no factory or helper functions for these classes. Construct them
directly: `ParallelOpt2(a, b)`, not `parallelOpt2(a, b)`.

## API reference

| Symbol | Kind | Description |
|---|---|---|
| `Res<T, E>` | typedef | Compact alias for `Result<T, E>`. |
| `Result<T, E>` | sealed class | Base type. Pattern-match with `case Ok(:final value)` / `case Err(:final error)`. |
| `Ok<T, E>` | class | Success variant. |
| `Err<T, E>` | class | Error variant. |
| `Opt<T>` | sealed class | Option type. `Val<T>` or `Nil`. |
| `Val<T>` | class | Present option variant. |
| `Nil` | class | Absent option variant. |
| `AsyncRes<T, E>` | class | Lazy async result. `run`, `map`, `flatMap`, `andThen`. |
| `AsyncOpt<T>` | class | Lazy async option. `run`, `map`. |
| `Result.fold` | method | Branch on the variant and return a value. |
| `Result.map` | method | Transform the success value. |
| `Result.mapError` | method | Transform the error value. |
| `Result.flatMap` / `Result.andThen` | method | Chain another `Result`-returning function. |
| `Result.when` | method | Side-effect-only branching. |
| `Result.getOrElse` | method | Provide a default from the error branch. |
| `Result.expect` | method | Returns the value or throws `StateError`. |
| `Result.expectError` | method | Returns the error or throws `StateError`. |
| `NullableToOpt.toOpt` | extension | Converts `T?` to `Opt<T>`. |
| `.toAsyncOpt()` | extension | Wraps `Future<Opt<T>> Function()` as `AsyncOpt<T>`. Experimental. |
| `.toAsyncRes()` | extension | Wraps `Future<Res<T, E>> Function()` as `AsyncRes<T, E>`. Experimental. |
| `ParallelOpt2..5` | class | Concurrent lazy `AsyncOpt` composition into typed records. Experimental. |
| `ParallelRes2..5` | class | Concurrent lazy `AsyncRes` composition into typed records. Experimental. |
| `Success<T, E>` | typedef | Compatibility alias for `Ok`. |
| `Failure<T, E>` | typedef | Compatibility alias for `Err`. |

## What this library does NOT do

| Non-feature | Reason |
|---|---|
| Hidden retry | Retry is an explicit policy decision, not a default behavior. |
| Hidden exception catching | Exceptions propagate. Use `fold` or pattern matching for expected failures. |
| Hidden caching / memoization | Each `run()` starts fresh. Caller controls caching externally. |
| Implicit repeated execution | Calling `run()` twice runs twice. No hidden replay policy. |
| Factory functions for parallel classes | Construct classes directly. Helper functions would duplicate the API. |

## Example

A runnable Very Good CLI Dart app lives in [`example/`](example/). It has its
own `pubspec.yaml` with a path dependency back to this package and uses the VGV
Dart CLI layout at
[`example/bin/explicit_example.dart`](example/bin/explicit_example.dart).

The app walks through success, failure, `flatMap`/`andThen`, the lazy
`AsyncRes` pipeline, and awaited async composition. Run it from the example
directory:

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
[explicit_outcome_link]: https://pub.dev/packages/explicit_outcome
