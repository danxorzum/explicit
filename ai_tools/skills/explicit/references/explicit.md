# explicit — Usage Guide

## Installation

```sh
dart pub add explicit
```

```dart
import 'package:explicit/explicit.dart';
```

Requires Dart SDK `^3.12.0` (sealed classes, pattern matching, records).

## Philosophy

`explicit` is **pragmatic, not purist**. It provides the highest-impact FP patterns — Result and Option types — without forcing full FP ceremony. The goal: make success, failure, presence, and absence first-class in your type signatures so callers handle every case by design.

No hidden retry. No hidden caching. No hidden exception catching. Every behavior is explicit.

## Result: `Res<T, E>`

`Res<T, E>` (alias for `Result<T, E>`) models operations that succeed with `Ok(value)` or fail with `Err(error)`. Both `T` and `E` must be non-nullable object types; use `String`, records, or domain objects for recoverable failures.

### Creating

```dart
Res<int, String> parsePort(String raw) {
  final value = int.tryParse(raw);
  if (value == null || value < 1 || value > 65535) {
    return Err<int, String>('invalid port: $raw');
  }
  return Ok<int, String>(value);
}
```

### Composing

All methods short-circuit on `Err` and preserve the sealed type.

| Method | Signature | Purpose |
|--------|-----------|---------|
| `map` | `Res<R, E> map<R>(R Function(T))` | Transform success value |
| `mapError` | `Res<T, R> mapError<R>(R Function(E))` | Transform error value |
| `next` | `Res<R, E> next<R>(Res<R, E> Function(T))` | Chain another Result operation |
| `or` | `Res<T, E> or(Res<T, E> Function(E))` | Recover with alternative result |

```dart
final result = parsePort('8080')
    .map((port) => 'http://localhost:$port')
    .mapError((e) => 'ConfigError: $e')
    .next((url) => url.startsWith('http')
        ? Ok<String, String>('$url OK')
        : Err<String, String>('bad scheme'))
    .or((e) => Ok<String, String>('unhealthy'));
```

### Branching

| Method | Signature | Purpose |
|--------|-----------|---------|
| `fold` | `R fold<R>({R Function(T), R Function(E)})` | Return a value from either branch |
| `when` | `void when({void Function(T), void Function(E)})` | Side effects, no return value |
| `getOrElse` | `T getOrElse(T Function(E))` | Return value or compute default |

```dart
final message = result.fold(
  onSuccess: (v) => 'OK: $v',
  onError: (e) => 'ERR: $e',
);

result.when(
  onSuccess: (v) => print('value=$v'),
  onError: (e) => print('error=$e'),
);

final value = result.getOrElse((e) => -1);
```

### Pattern matching

```dart
switch (result) {
  case Ok(:final value):
    print('success: $value');
  case Err(:final error):
    print('error: $error');
}
```

### Compatibility aliases

`Success<T, E>` and `Failure<T, E>` are typedef aliases for `Ok` and `Err`. Use whichever reads better.

## Option: `Opt<T>`

`Opt<T>` (alias for `Option<T>`) models presence with `Val(value)` or absence with `Nil`. Unlike nullable types, the compiler forces you to handle both cases.

### Creating

```dart
Opt<int> findIndex(List<String> items, String target) {
  final index = items.indexOf(target);
  if (index == -1) return Nil();
  return Val(index);
}
```

### Converting nullable to Opt

```dart
String? maybeName = fetchName();
Opt<String> nameOpt = maybeName.toOpt; // null → Nil, non-null → Val
```

### Composing

Options share the same vocabulary as Results.

| Method | Signature | Purpose |
|--------|-----------|---------|
| `map` | `Opt<R> map<R>(R Function(T))` | Transform present value |
| `next` | `Opt<R> next<R>(Opt<R> Function(T))` | Chain another Option operation |
| `or` | `Opt<T> or(Opt<T> Function())` | Provide alternative when Nil |
| `fold` | `R fold<R>({R Function(T), R Function()})` | Branch and return value |
| `when` | `void when({void Function(T), void Function()})` | Branch for side effects |
| `getOrElse` | `T getOrElse(T Function())` | Return value or compute default |

```dart
final label = findIndex(names, 'Alice')
    .map((i) => 'Found at index $i')
    .getOrElse(() => 'Not found');
```

## Async Pipelines: `AsyncRes<T, E>` and `AsyncOpt<T>`

> `@experimental` — async pipeline APIs may change in future versions.

Lazy async wrappers. Nothing executes until `run()` is called. Each `run()` starts fresh — no caching, no memoization.

### Semantics

| Behavior | Detail |
|----------|--------|
| Lazy | No work until `run()` |
| Short-circuit | After `Err`/`Nil`, downstream steps skipped |
| No caching | Each `run()` re-executes |
| No retry | Failures propagate |
| No catching | Thrown exceptions propagate |

### AsyncRes

```dart
final pipeline = AsyncRes<int, String>(() async => Ok<int, String>(2))
    .map((v) => v + 3)
    .next((v) => AsyncRes<int, String>(() async => Ok(v * 10)))
    .map((v) => 'final=$v');

final result = await pipeline.run(); // Res<String, String>
```

Methods: `run()`, `map`, `next`, `mapError`, `or`.

### AsyncOpt

Same pattern for options. Methods: `run()`, `map`, `next`, `or`, plus convenience extensions `fold`, `when`, `getOrElse`, `hasValue`, `isNil`.

### Wrapping existing async closures

```dart
Future<Res<String, String>> fetchBody() async => Ok('hello');

final asyncRes = fetchBody.toAsyncRes(); // wraps without invoking
final result = await asyncRes.run();     // invokes and returns Res
```

```dart
Future<Opt<int>> fetchCount() async => Val(42);

final asyncOpt = fetchCount.toAsyncOpt();
final result = await asyncOpt.run(); // Opt<int>
```

### Return type typedefs

- `ResultAsync<T, E>` = `Future<Res<T, E>>`
- `OptionAsync<T>` = `Future<Opt<T>>`

## Parallel Recipes (Experimental)

> `@experimental` — may change in future versions.

Run multiple async operations concurrently and combine results into typed Dart records.

### ParallelOpt

```dart
final a = AsyncOpt<int>(() async => Val(1));
final b = AsyncOpt<String>(() async => Val('hello'));

final parallel = ParallelOpt2(a, b);
final result = await parallel.run(); // Opt<(int, String)>
// Val((1, 'hello'))
```

If any recipe produces `Nil`, the combined result is `Nil`.

### ParallelRes

```dart
final a = AsyncRes<int, String>(() async => Ok(1));
final b = AsyncRes<String, String>(() async => Ok('hello'));

final parallel = ParallelRes2(a, b);
final result = await parallel.run(); // Res<(int, String), String>
// Ok((1, 'hello'))
```

If any recipe produces `Err`, the result is the first `Err` by parameter order.

### Available arities

| Class | Recipes | Result type |
|-------|---------|-------------|
| `ParallelOpt2` | 2 × `AsyncOpt` | `Future<Opt<(A, B)>>` |
| `ParallelOpt3` | 3 × `AsyncOpt` | `Future<Opt<(A, B, C)>>` |
| `ParallelOpt4` | 4 × `AsyncOpt` | `Future<Opt<(A, B, C, D)>>` |
| `ParallelOpt5` | 5 × `AsyncOpt` | `Future<Opt<(A, B, C, D, E)>>` |
| `ParallelRes2` | 2 × `AsyncRes` | `Future<Res<(A, B), E>>` |
| `ParallelRes3` | 3 × `AsyncRes` | `Future<Res<(A, B, C), E>>` |
| `ParallelRes4` | 4 × `AsyncRes` | `Future<Res<(A, B, C, D), E>>` |
| `ParallelRes5` | 5 × `AsyncRes` | `Future<Res<(A, B, C, D, F), E>>` |

## What This Library Does NOT Do

| Non-feature | Reason |
|-------------|--------|
| Hidden retry | Retry is a policy decision, not a default |
| Hidden exception catching | Exceptions propagate; use `fold` for expected failures |
| Hidden caching / memoization | Each `run()` starts fresh; caller controls caching |
| Implicit repeated execution | `run()` twice = runs twice |
| Factory functions for parallel | Construct directly; helpers would duplicate the API |
