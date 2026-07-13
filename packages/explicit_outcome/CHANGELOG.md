# Changelog

## 0.0.2

- **Compatibility**: Lowered Dart SDK floor from `^3.12.0` to `>=3.6.0 <4.0.0` to support more Dart 3 consumers.
- **Compatibility**: Relaxed `meta` constraint from `^1.18.3` to `>=1.15.0 <2.0.0` (packages only need long-lived annotations).
- **Compatibility**: Widened `test` dev dependency to `>=1.25.0 <2.0.0` for Dart 3.6 lane resolution.
- **Analysis**: Switched to Very Good Analysis `^7.0.0` (declares `^3.5.0`) for Dart 3.6-compatible lint rules.

## 0.0.1

- Initial release of `explicit_outcome`.
- `Result<T, E>` sealed type with `Ok` and `Err` constructors and `Res<T, E>` compact typedef.
- `Option<T>` sealed type with `Val` and `Nil` constructors and `Opt<T>` compact typedef.
- Composition methods: `map`, `mapError`, `next`, `or`.
- Branching methods: `fold`, `when`, `getOrElse`.
- Compatibility aliases `Success` and `Failure`.
