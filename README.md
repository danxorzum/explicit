# Explicit

[![ci][ci_badge]][ci_link]
[![coverage][coverage_badge]][ci_link]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MPL-2.0][license_badge]][license_link]
[![Dart 3.12+][dart_badge]][dart_link]

A compact library for explicit, predictable, and readable Dart.

Design your software without implicit surprises. `explicit` is a foundational approach to writing code where control flow and state changes are clearly defined, leaving no room for ambiguity.

Use it to model operations with a simple [Result][result_wikipedia] toolkit. Eliminate hidden exceptions, chain operations in declaration order, and compose lazy async pipelines with predictable short-circuiting.

## Quick Start

### Install after publication

```sh
dart pub add explicit
```

### Model success and failure

Use `Ok` for successful values and `Err` for recoverable failures.

```dart
import 'package:explicit/explicit.dart';

Res<int, String> divide(int a, int b) {
  if (b == 0) return Err('division by zero');
  return Ok(a ~/ b);
}
```

### Branch explicitly

Use `fold`, `when`, or `getOrElse` when the call site needs to decide what happens next.

```dart
final result = divide(10, 2);

final message = result.fold(
  onSuccess: (value) => 'got $value',
  onError: (error) => 'failed: $error',
);
```

### Compose safely

Chains preserve declaration order. If any operation fails, the chain short-circuits.

```dart
final message = divide(10, 2)
    .map((value) => value * 10)
    .fold(
      onSuccess: (value) => 'Final result: $value',
      onError: (error) => 'Operation failed: $error',
    );
```

## Motivation

This library was born out of a pragmatic necessity: the continuous extraction of the same core primitives across multiple projects.

In modern software development, code must be more than just functional — it must be a clear, unambiguous contract. Implicit control flows, hidden exceptions, and unpredictable side effects make codebases fragile and hard to read. `explicit` is designed to be the reliable heart of any application, enforcing a style where every case and edge case is handled by design.

### Explicit Code Philosophy

The core tenet is simple: **Explicit Programming**. Whether you are building reactive, declarative, imperative, or deeply object-oriented systems, the code should be declarative and self-documenting. If an operation can fail, that failure should be part of the method's signature.

No hidden behavior. No implicit surprises. Readable control flow that does what it says.

### Pragmatic, not Purist

While heavily inspired by Functional Programming concepts like immutability and predictable state, `explicit` is **not** a full-blown FP library. There are already excellent libraries in the Dart ecosystem for strict functional paradigms. Instead, this package focuses on the highest-impact, lowest-friction patterns — the essential building blocks to prevent side effects and keep your architecture highly readable, without forcing your team to learn complex mathematical theories.

### Pillars

#### Explicit

Every computational outcome is part of the type signature. Success, failure, presence, absence — all modeled as data, never hidden in control flow. The library makes the shape of every possible result visible at the call site, so callers handle each case by design.

#### Simple

Small, focused primitives with names that explain the behavior at the call site. Each concept earns its place before joining the API. Today that includes `Result` and `Option` families; tomorrow it may grow to cover other explicit modeling needs — but only when the abstraction proves its value across real projects.

#### Optimized

Work happens when the caller asks for it. Lazy async pipelines defer execution until `run()`, short-circuit predictably, and avoid hidden caching, retry, or replay. Performance is predictable by construction, not by convention.

## Usage

### Results: `Ok` and `Err`

`Res<T, E>` is the compact alias for the sealed `Result<T, E>` base. Use `Ok` to wrap a success value and `Err` to wrap an error.

```dart
Res<int, String> parsePort(String raw) {
  final value = int.tryParse(raw);
  if (value == null || value < 1 || value > 65535) {
    return Err<int, String>('invalid port: $raw');
  }
  return Ok<int, String>(value);
}
```

`E` is intentionally unconstrained: this library models recoverable failures as data, not thrown control flow. Use `String`, custom error records, or domain objects — whatever fits the call site.

### Result composition: `map`, `mapError`, `next`, and `or`

All composition methods preserve the sealed type and short-circuit on `Err`.

```dart
final result = parsePort('8080')
    .map((port) => 'http://localhost:$port')
    .mapError((error) => 'ConfigurationError: $error')
    .next((url) => fetchHealth(url)); // returns Res<bool, String>
```

Use `or` to recover from errors with an alternative result:

```dart
final result = parsePort('8080')
    .or((error) => Ok<int, String>(8080)); // fallback to default port
```

### Result branching

`fold` returns a value from either branch. `when` is for side effects without allocating a return value. `getOrElse` lets the error branch compute a default.

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

### Nullable conversion: `.toOpt`

The `.toOpt` extension converts any nullable value to an `Opt<T>`. `null` becomes `Nil`, and non-null values become `Val<T>` with a non-nullable payload type enforced by the analyzer.

```dart
String? maybeName = fetchName();
Opt<String> nameOpt = maybeName.toOpt;

switch (nameOpt) {
  case Val(:final value):
    print('name=$value');
  case Nil():
    print('no name');
}
```

### Options: `Val` and `Nil`

`Opt<T>` is the compact alias for the sealed `Option<T>` base. Use `Val` for a present value and `Nil` for absence.

```dart
Opt<int> findIndex(List<String> items, String target) {
  final index = items.indexOf(target);
  if (index == -1) return Nil();
  return Val(index);
}

final label = findIndex(names, 'Alice')
    .map((i) => 'Found at index $i')
    .getOrElse(() => 'Not found');
```

Options support the same composition pattern: `map`, `next`, `or`, `fold`, `when`, and `getOrElse`.

### Async result pipelines: `AsyncRes`

`AsyncRes<T, E>` wraps a `Future<Res<T, E>>` and defers execution until `run()` is called. `map`, `next`, `mapError`, and `or` return new lazy `AsyncRes` values and preserve declaration order. After an `Err`, the chain short-circuits — no downstream step is invoked.

```dart
final pipeline = AsyncRes<int, String>(() async => Ok<int, String>(2))
    .map((value) => value + 3)
    .next((value) => AsyncRes<int, String>(
      () async => Ok<int, String>(value * 10),
    ))
    .map((value) => 'final=$value');

final result = await pipeline.run(); // Res<String, String>
```

Nothing runs until `run()`. Calling `run()` multiple times re-executes the pipeline — there is no hidden caching or memoization.

`ResultAsync<T, E>` is a convenience typedef for `Future<Res<T, E>>`, useful as a return type.

### Lazy async adapters: `.toAsyncOpt()` / `.toAsyncRes()`

When you have a closure that returns a `Future<Opt<T>>` or `Future<Res<T, E>>`, use the adapter extensions to wrap it as an `AsyncOpt` or `AsyncRes` without invoking the closure eagerly.

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

### Parallel recipes: `ParallelOpt` / `ParallelRes`

> **Experimental**: These classes are marked `@experimental` and may change in future versions.

`ParallelOpt2` through `ParallelOpt5` run multiple `AsyncOpt` recipes concurrently and combine results into a typed record. `ParallelRes2` through `ParallelRes5` do the same for `AsyncRes` recipes.

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

Construct them directly: `ParallelOpt2(a, b)`, `ParallelRes3(a, b, c)`.

## API at a glance

The full API reference is generated by `dartdoc` and available on pub.dev after publication. This section gives you the conceptual map so you know which tool to reach for.

### Result: success and failure as data

`Result<T, E>` (alias `Res<T, E>`) models operations that can succeed or fail. Use `Ok(value)` for success and `Err(error)` for failure. The error type `E` is yours to choose — `String`, a custom record, a domain object.

Composition methods — `map`, `mapError`, `next`, `or` — transform values while preserving the sealed type and short-circuiting on `Err`. Branching methods — `fold`, `when`, `getOrElse` — let the call site decide how to handle each outcome.

### Option: presence and absence without nullable ambiguity

`Option<T>` (alias `Opt<T>`) models values that may or may not exist. Use `Val(value)` for presence and `Nil` for absence. Unlike nullable types, the compiler forces you to handle both cases.

Options share the same composition vocabulary as Results: `map`, `next`, `or`, `fold`, `when`, and `getOrElse`.

### Async workflows: lazy pipelines that start on demand

`AsyncRes<T, E>` and `AsyncOpt<T>` wrap lazy async computations. You build a pipeline with `map`, `next`, `mapError`, and `or`, but nothing executes until you call `run()`. Each call to `run()` starts fresh — there is no hidden caching or replay.

Use these when you need to compose multiple async steps with predictable short-circuiting and declaration-order readability.

### Adapters: bridging nullable values and lazy closures

- `.toOpt` — converts any `T?` to `Opt<T>`. `null` becomes `Nil`, non-null becomes `Val`.
- `.toAsyncOpt()` — wraps a `Future<Opt<T>> Function()` as an `AsyncOpt<T>` without invoking the closure.
- `.toAsyncRes()` — wraps a `Future<Res<T, E>> Function()` as an `AsyncRes<T, E>` without invoking the closure.

These adapters let you bring existing nullable APIs and async functions into the explicit world without rewriting them.

### Parallel recipes: concurrent composition with typed records

> **Experimental**: These classes are marked `@experimental` and may change in future versions.

`ParallelOpt2` through `ParallelOpt5` run multiple `AsyncOpt` recipes concurrently and combine the results into a typed Dart record. `ParallelRes2` through `ParallelRes5` do the same for `AsyncRes` recipes. If any option is `Nil` (or any result is `Err`), the combined result propagates that outcome.

### Compatibility aliases

`Success<T, E>` and `Failure<T, E>` are typedef aliases for `Ok` and `Err`. They exist for codebases that prefer the longer names — use whichever reads better at the call site.

## What this library does NOT do

| Non-feature | Reason |
|---|---|
| Hidden retry | Retry is an explicit policy decision, not a default behavior. |
| Hidden exception catching | Exceptions propagate. Use `fold` or pattern matching for expected failures. |
| Hidden caching / memoization | Each `run()` starts fresh. Caller controls caching externally. |
| Implicit repeated execution | Calling `run()` twice runs twice. No hidden replay policy. |
| Factory functions for parallel classes | Construct classes directly. Helper functions would duplicate the API. |

## Development and Testing

This repository uses a Dart workspace with two packages. To run tests locally:

```sh
# From the repository root
dart pub get

# Run tests for each package
cd packages/explicit_outcome && dart test
cd ../explicit && dart test
```

Lint checks use [Very Good Analysis][very_good_analysis_link]:

```sh
dart analyze packages/explicit_outcome
dart analyze packages/explicit
```

### Pre-push quality gate

Install the local pre-push hook to catch format, analyze, test, and coverage failures before pushing:

```sh
melos run hooks:install
```

The hook runs the same validation as CI — no divergent logic. To uninstall:

```sh
melos run hooks:install -- --uninstall
```

## Contributing

Contributions are welcome. This repository uses the following automation and conventions:

- **CI** ([`ci.yaml`][ci_link]): runs strict quality gates (format, analyze, tests, 100% coverage) on every push and pull request to `main`, plus semantic PR title checks.
- **Release version PR** ([`release_version_pr.yaml`]): prepares version, changelog, and provenance updates from explicit changesets. Maintainers manually create release tags after the version PR merges and CI is green.
- **Dependabot** ([`dependabot.yaml`]): opens daily pull requests for outdated GitHub Actions and pub dependencies.
- **Issue-first policy** ([`issue_first.yaml`]): automatically closes pull requests that do not reference a linked issue.
- **Pull request template** ([`PULL_REQUEST_TEMPLATE.md`]): every PR must include a linked issue, Status, Description, and the Type of Change checklist.

License validation is intentionally deferred until a workspace-safe license gate is added. The previous reusable license workflow assumed root-package behavior and did not cover this monorepo correctly.

### Issue-first policy

This project requires an **approved issue** before accepting pull requests. The policy exists to validate intent, scope, and alignment with the Explicit Code philosophy before code is written.

**How it works:**

1. Open an issue describing the bug, feature, or change you want to make.
2. Wait for a maintainer to confirm the approach and scope.
3. Reference the issue in your PR body using a closing keyword (`Closes #123`, `Fixes #456`) or the full issue URL.

Pull requests without a linked issue are **closed automatically** by the [`issue_first.yaml`][issue_first.yaml] workflow. Bot accounts (Dependabot, Renovate) are exempt.

Before opening a pull request:

1. Ensure `dart analyze` passes with no warnings on the affected package.
2. Ensure `dart test` passes for the affected package.
3. Follow the existing code style and test patterns (table-driven tests with `package:test`).
4. Keep changes focused — one concern per pull request.

## Releases

The `main` branch represents the current version of the project. The package is not published yet. Once publication is enabled, CI/CD is expected to handle pub.dev deployments from GitHub Actions so releases stay tied to the current `main` version.

## Issues

Report bugs and request features via the [GitHub issue tracker][issue_tracker_link]. The repository provides dedicated templates for common issue types — including bug reports, feature requests, documentation, performance, refactoring, tests, and CI — so pick the one that best fits your case and fill in the fields.

Bug reports use the existing bug template fields: Description, Steps To Reproduce,
Expected Behavior, Screenshots when useful, and Additional Context.

## Roadmap

- Stabilize the async API (`AsyncRes`, `AsyncOpt`, `Parallel*`) and remove `@experimental` annotations.
- Expand documentation with real-world usage patterns.

## Compatibility

- **Dart SDK:** `^3.12.0` (sealed classes, pattern matching, records).
- **License:** [Mozilla Public License 2.0][license_link] (MPL-2.0).

## Repository Layout

For contributors, this monorepo contains:

| Path | Description |
|---|---|
| `packages/explicit` | The public `explicit` package intended for pub.dev publication. |
| `packages/explicit_outcome` | Low-level typed outcomes used by `explicit`. |

Users should install `explicit` via `dart pub add explicit` — the outcome primitives are included.

[result_wikipedia]: https://en.wikipedia.org/wiki/Result_type
[ci_badge]: https://github.com/danxorzum/explicit/actions/workflows/ci.yaml/badge.svg?branch=main
[ci_link]: https://github.com/danxorzum/explicit/actions/workflows/ci.yaml
[coverage_badge]: https://img.shields.io/badge/coverage-100%25-brightgreen.svg
[license_badge]: https://img.shields.io/badge/license-MPL_2.0-blue.svg
[license_link]: https://opensource.org/licenses/MPL-2.0
[dart_badge]: https://img.shields.io/badge/dart-%5E3.12.0-blue.svg
[dart_link]: https://dart.dev/get-dart
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[issue_tracker_link]: https://github.com/danxorzum/explicit/issues
[dependabot.yaml]: https://github.com/danxorzum/explicit/blob/main/.github/dependabot.yaml
[release_version_pr.yaml]: https://github.com/danxorzum/explicit/blob/main/.github/workflows/release_version_pr.yaml
[issue_first.yaml]: https://github.com/danxorzum/explicit/blob/main/.github/workflows/issue_first.yaml
[PULL_REQUEST_TEMPLATE.md]: https://github.com/danxorzum/explicit/blob/main/.github/PULL_REQUEST_TEMPLATE.md
