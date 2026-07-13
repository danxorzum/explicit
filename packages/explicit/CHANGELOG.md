# Changelog

## 0.0.2

- **Compatibility**: Lowered Dart SDK floor from `^3.12.0` to `>=3.6.0 <4.0.0` to support more Dart 3 consumers.
- **Compatibility**: Relaxed `meta` constraint from `^1.18.3` to `>=1.15.0 <2.0.0` (packages only need long-lived annotations).
- **Compatibility**: Widened `test` dev dependency to `>=1.25.0 <2.0.0` for Dart 3.6 lane resolution.
- **Analysis**: Switched to Very Good Analysis `^7.0.0` (declares `^3.5.0`) for Dart 3.6-compatible lint rules.
- Added CI Dart 3.6 package compatibility lane with external path-consumer fixture.

## 0.0.1

- Initial release of `explicit`.
- Re-exports `Result` and `Option` types from `explicit_outcome`.
- Nullable conversion via `.toOpt` extension.
- Async result pipelines via `AsyncRes<T, E>` with lazy execution and short-circuiting.
- Async option pipelines via `AsyncOpt<T>`.
- Lazy async adapters `.toAsyncOpt()` and `.toAsyncRes()`.
- Experimental parallel recipe composition via `ParallelOpt2`–`ParallelOpt5` and `ParallelRes2`–`ParallelRes5`.
