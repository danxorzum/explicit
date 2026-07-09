---
name: explicit
description: "Trigger: Dart, Flutter, explicit, null, nullable, error handling, Result, Option, Res, Opt. Use explicit to model absence/failure without null or exceptions."
license: MPL-2.0
metadata:
  author: danxorzum
  version: "1.0"
---

## Activation Contract

Load this skill when working in a Dart or Flutter project that uses or should use the `explicit` library to model operations with explicit success/failure and presence/absence types instead of exceptions or nullable types.

## Hard Rules

- Use `Res<T, E>` for operations that can fail, not exceptions.
- Use `Opt<T>` for optional values, not nullable types.
- Do not carry `null` through domain logic. If an API returns nullable data, convert it at the boundary with `.toOpt` and continue with `Opt<T>`.
- Make possible outcomes visible in type signatures; model success, failure, presence, and absence as data.
- Keep control flow readable and unsurprising: no hidden retry, caching, exception catching, or implicit execution.
- Compose with `map`, `next`, `or`, `fold` — preserve declaration order.
- Call `run()` to execute `AsyncRes`/`AsyncOpt` pipelines (lazy by default).
- Do not use this library for FP ceremony — it is pragmatic, not purist.

## Decision Gates

| Need | Use |
|------|-----|
| Operation can fail with recoverable error | `Res<T, E>` with `Ok`/`Err` |
| Value may be absent | `Opt<T>` with `Val`/`Nil` |
| API returns nullable data | Convert immediately with `.toOpt` |
| Chain async operations | `AsyncRes<T, E>` / `AsyncOpt<T>` (experimental) |
| Run multiple async ops concurrently | `ParallelOpt2-5` / `ParallelRes2-5` (experimental) |
| Wrap existing async closure | `.toAsyncRes()` / `.toAsyncOpt()` |

## Execution Steps

1. Install: `dart pub add explicit`
2. Import: `import 'package:explicit/explicit.dart';`
3. Return `Res<T, E>` from functions that can fail:
   ```dart
   Res<int, String> divide(int a, int b) {
     if (b == 0) return Err('division by zero');
     return Ok(a ~/ b);
   }
   ```
4. Compose with `map`, `mapError`, `next`, `or`:
   ```dart
   final result = divide(10, 2)
       .map((v) => v * 10)
       .mapError((e) => 'Error: $e')
       .next((v) => v > 0 ? Ok<int, String>(v) : Err<int, String>('must be positive'))
       .or((e) => Ok(0));
   ```
5. Branch explicitly with `fold`, `when`, or `getOrElse`:
   ```dart
   final message = result.fold(
     onSuccess: (v) => 'OK: $v',
     onError: (e) => 'ERR: $e',
   );
   ```
6. For async pipelines, build with `AsyncRes` and call `run()`:
   ```dart
   final pipeline = AsyncRes<int, String>(() async => Ok(2))
       .map((v) => v + 3)
       .next((v) => AsyncRes(() async => Ok(v * 10)));
   final result = await pipeline.run();
   ```

## Output Contract

When implementing with `explicit`:
- Return types must be `Res<T, E>` or `Opt<T>`, not exceptions or nullable.
- Convert nullable inputs at system boundaries with `.toOpt`; do not propagate `null` through business logic.
- Composition chains must preserve declaration order.
- Async pipelines must call `run()` to execute.
- Pattern match with `switch` on `Ok`/`Err` or `Val`/`Nil` when branching.

## References

- `references/explicit.md` — Full usage guide for the main `explicit` package.
- `references/explicit_outcome.md` — Low-level outcome types API reference.
