# Changelog

## 0.0.1

- Initial release of `explicit`.
- Re-exports `Result` and `Option` types from `explicit_outcome`.
- Nullable conversion via `.toOpt` extension.
- Async result pipelines via `AsyncRes<T, E>` with lazy execution and short-circuiting.
- Async option pipelines via `AsyncOpt<T>`.
- Lazy async adapters `.toAsyncOpt()` and `.toAsyncRes()`.
- Experimental parallel recipe composition via `ParallelOpt2`–`ParallelOpt5` and `ParallelRes2`–`ParallelRes5`.
