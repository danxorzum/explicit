# explicit_outcome — API Reference

Low-level typed outcomes used by `explicit`. Most users should install `explicit` instead, which re-exports these types with additional utilities.

Install only when you need the raw outcome types without the `explicit` wrapper:

```sh
dart pub add explicit_outcome
```

```dart
import 'package:explicit_outcome/explicit_outcome.dart';
```

## API Summary

| Symbol | Kind | Description |
|--------|------|-------------|
| `Res<T, E>` | typedef | Compact alias for `Result<T, E>` |
| `Result<T, E>` | sealed class | Base type for success/error |
| `Ok<T, E>` | class | Success variant |
| `Err<T, E>` | class | Error variant |
| `Success<T, E>` | typedef | Compatibility alias for `Ok` |
| `Failure<T, E>` | typedef | Compatibility alias for `Err` |
| `Opt<T>` | typedef | Compact alias for `Option<T>` |
| `Option<T>` | sealed class | Base type for present/absent |
| `Val<T>` | class | Present option variant |
| `Nil<T>` | class | Absent option variant |
| `AsyncRes<T, E>` | class | Lazy async result |
| `AsyncOpt<T>` | class | Lazy async option |
| `ResultAsync<T, E>` | typedef | `Future<Res<T, E>>` |
| `OptionAsync<T>` | typedef | `Future<Opt<T>>` |

## Result Methods

| Method | Signature | Behavior |
|--------|-----------|----------|
| `map` | `Res<R, E> map<R>(R Function(T))` | Transform success. Short-circuits on `Err` |
| `mapError` | `Res<T, R> mapError<R>(R Function(E))` | Transform error. Short-circuits on `Ok` |
| `next` | `Res<R, E> next<R>(Res<R, E> Function(T))` | Chain another Result. Short-circuits on `Err` |
| `or` | `Res<T, E> or(Res<T, E> Function(E))` | Recover with alternative result |
| `fold` | `R fold<R>({R Function(T), R Function(E)})` | Branch and return value |
| `when` | `void when({void Function(T), void Function(E)})` | Branch for side effects |
| `getOrElse` | `T getOrElse(T Function(E))` | Return value or compute default |
| `isSuccess` | `bool` | `true` if `Ok` |
| `isFailure` | `bool` | `true` if `Err` |

### Quick example

```dart
Res<int, String> parsePort(String raw) {
  final value = int.tryParse(raw);
  if (value == null || value < 1 || value > 65535) {
    return Err('invalid port: $raw');
  }
  return Ok(value);
}

final pipeline = parsePort('8080')
    .map((port) => 'http://localhost:$port')
    .mapError((e) => 'ConfigError: $e')
    .next((url) => url.startsWith('http')
        ? Ok<String, String>('$url OK')
        : Err<String, String>('bad scheme'))
    .or((e) => Ok('http://localhost:8080'));

final message = pipeline.fold(
  onSuccess: (url) => 'URL: $url',
  onError: (e) => 'Error: $e',
);
```

## Option Methods

| Method | Signature | Behavior |
|--------|-----------|----------|
| `map` | `Opt<R> map<R>(R Function(T))` | Transform present value. Propagates `Nil` |
| `next` | `Opt<R> next<R>(Opt<R> Function(T))` | Chain another Option. Propagates `Nil` |
| `or` | `Opt<T> or(Opt<T> Function())` | Alternative when `Nil` |
| `fold` | `R fold<R>({R Function(T), R Function()})` | Branch and return value |
| `when` | `void when({void Function(T), void Function()})` | Branch for side effects |
| `getOrElse` | `T getOrElse(T Function())` | Return value or compute default |
| `hasValue` | `bool` | `true` if `Val` |
| `isNil` | `bool` | `true` if `Nil` |

### Quick example

```dart
Opt<int> findIndex(List<String> items, String target) {
  final index = items.indexOf(target);
  if (index == -1) return Nil();
  return Val(index);
}

final names = ['Ada', 'Alice'];

final result = findIndex(names, 'Alice')
    .map((i) => names[i].toUpperCase())
    .next((name) => name.isNotEmpty ? Val(name) : Nil<String>())
    .or(() => Val('DEFAULT'));

final label = result.fold(
  onVal: (name) => 'Found: $name',
  onNil: () => 'Not found',
);
```

## Async Types

### AsyncRes Methods

| Method | Description |
|--------|-------------|
| `run()` | Execute and return `Future<Res<T, E>>` |
| `map` | Transform success value (lazy) |
| `next` | Chain another `AsyncRes` (lazy) |
| `mapError` | Transform error value (lazy) |
| `or` | Recover from error (lazy) |

### AsyncOpt Methods

| Method | Description |
|--------|-------------|
| `run()` | Execute and return `Future<Opt<T>>` |
| `map` | Transform present value (lazy) |
| `next` | Chain another `AsyncOpt` (lazy) |
| `or` | Alternative when `Nil` (lazy) |
| `fold` | Await and branch (convenience) |
| `when` | Await and side-effect (convenience) |
| `getOrElse` | Await and default (convenience) |
| `hasValue` | Await and check `Val` (convenience) |
| `isNil` | Await and check `Nil` (convenience) |

### Async semantics

| Behavior | Detail |
|----------|--------|
| Lazy | No work until `run()` |
| Short-circuit | After `Err`/`Nil`, downstream skipped |
| No caching | Each `run()` re-executes |
| No retry | Failures propagate |
| No catching | Exceptions propagate |

### Quick example

```dart
final pipeline = AsyncRes<int, String>(() async => Ok(2))
    .map((v) => v + 3)
    .next((v) => AsyncRes(() async => Ok(v * 10)));

final result = await pipeline.run(); // Res<int, String>
```

## Compatibility

- **Dart SDK:** `^3.12.0`
- **License:** MPL-2.0
