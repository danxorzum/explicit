# Changelog

## 0.0.1

- Initial release of `explicit_outcome`.
- `Result<T, E>` sealed type with `Ok` and `Err` constructors and `Res<T, E>` compact typedef.
- `Option<T>` sealed type with `Val` and `Nil` constructors and `Opt<T>` compact typedef.
- Composition methods: `map`, `mapError`, `next`, `or`.
- Branching methods: `fold`, `when`, `getOrElse`.
- Compatibility aliases `Success` and `Failure`.
