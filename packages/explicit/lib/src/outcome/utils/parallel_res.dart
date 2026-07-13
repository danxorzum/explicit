import 'package:explicit_outcome/explicit_outcome.dart';
import 'package:meta/meta.dart';

/// Runs two [AsyncRes] recipes concurrently and combines their results into
/// a typed record.
///
/// On [run], both recipes start together. If both produce [Ok],
/// the result is `Ok<(A, B)>`. If any recipe produces [Err], the result
/// is the first [Err] by parameter order.
///
/// No work happens until [run] is called. Each call to [run]
/// re-executes all recipes — there is no hidden caching.
///
/// Exceptions thrown by recipes propagate; this class does not catch, retry,
/// or convert thrown errors.
@experimental
final class ParallelRes2<A extends Object, B extends Object, E extends Object> {
  /// Creates a parallel combinator for two [AsyncRes] recipes.
  const ParallelRes2(this.a, this.b);

  /// The first recipe.
  final AsyncRes<A, E> a;

  /// The second recipe.
  final AsyncRes<B, E> b;

  /// Runs all recipes concurrently and combines results into a typed record.
  ResultAsync<(A, B), E> run() async {
    final results = await (a.run(), b.run()).wait;
    final (resA, resB) = results;

    return resA.fold(
      onSuccess: (va) => resB.fold(
        onSuccess: (vb) => Ok((va, vb)),
        onError: Err.new,
      ),
      onError: Err.new,
    );
  }
}

/// Runs three [AsyncRes] recipes concurrently and combines their results into
/// a typed record.
///
/// On [run], all recipes start together. If all produce [Ok],
/// the result is `Ok<(A, B, C)>`. If any recipe produces [Err], the result
/// is the first [Err] by parameter order.
///
/// No work happens until [run] is called. Each call to [run]
/// re-executes all recipes — there is no hidden caching.
///
/// Exceptions thrown by recipes propagate; this class does not catch, retry,
/// or convert thrown errors.
@experimental
final class ParallelRes3<A extends Object, B extends Object, C extends Object,
    E extends Object> {
  /// Creates a parallel combinator for three [AsyncRes] recipes.
  const ParallelRes3(this.a, this.b, this.c);

  /// The first recipe.
  final AsyncRes<A, E> a;

  /// The second recipe.
  final AsyncRes<B, E> b;

  /// The third recipe.
  final AsyncRes<C, E> c;

  /// Runs all recipes concurrently and combines results into a typed record.
  ResultAsync<(A, B, C), E> run() async {
    final results = await (a.run(), b.run(), c.run()).wait;
    final (resA, resB, resC) = results;

    return resA.fold(
      onSuccess: (va) => resB.fold(
        onSuccess: (vb) => resC.fold(
          onSuccess: (vc) => Ok((va, vb, vc)),
          onError: Err.new,
        ),
        onError: Err.new,
      ),
      onError: Err.new,
    );
  }
}

/// Runs four [AsyncRes] recipes concurrently and combines their results into
/// a typed record.
///
/// On [run], all recipes start together. If all produce [Ok],
/// the result is `Ok<(A, B, C, D)>`. If any recipe produces [Err], the result
/// is the first [Err] by parameter order.
///
/// No work happens until [run] is called. Each call to [run]
/// re-executes all recipes — there is no hidden caching.
///
/// Exceptions thrown by recipes propagate; this class does not catch, retry,
/// or convert thrown errors.
@experimental
final class ParallelRes4<A extends Object, B extends Object, C extends Object,
    D extends Object, E extends Object> {
  /// Creates a parallel combinator for four [AsyncRes] recipes.
  const ParallelRes4(this.a, this.b, this.c, this.d);

  /// The first recipe.
  final AsyncRes<A, E> a;

  /// The second recipe.
  final AsyncRes<B, E> b;

  /// The third recipe.
  final AsyncRes<C, E> c;

  /// The fourth recipe.
  final AsyncRes<D, E> d;

  /// Runs all recipes concurrently and combines results into a typed record.
  ResultAsync<(A, B, C, D), E> run() async {
    final results = await (a.run(), b.run(), c.run(), d.run()).wait;
    final (resA, resB, resC, resD) = results;

    return resA.fold(
      onSuccess: (va) => resB.fold(
        onSuccess: (vb) => resC.fold(
          onSuccess: (vc) => resD.fold(
            onSuccess: (vd) => Ok((va, vb, vc, vd)),
            onError: Err.new,
          ),
          onError: Err.new,
        ),
        onError: Err.new,
      ),
      onError: Err.new,
    );
  }
}

/// Runs five [AsyncRes] recipes concurrently and combines their results into
/// a typed record.
///
/// On [run], all recipes start together. If all produce [Ok],
/// the result is `Ok<(A, B, C, D, F)>`. If any recipe produces [Err],
/// the result is the first [Err] by parameter order.
///
/// No work happens until [run] is called. Each call to [run]
/// re-executes all recipes — there is no hidden caching.
///
/// Exceptions thrown by recipes propagate; this class does not catch, retry,
/// or convert thrown errors.
@experimental
final class ParallelRes5<A extends Object, B extends Object, C extends Object,
    D extends Object, F extends Object, E extends Object> {
  /// Creates a parallel combinator for five [AsyncRes] recipes.
  const ParallelRes5(this.a, this.b, this.c, this.d, this.e);

  /// The first recipe.
  final AsyncRes<A, E> a;

  /// The second recipe.
  final AsyncRes<B, E> b;

  /// The third recipe.
  final AsyncRes<C, E> c;

  /// The fourth recipe.
  final AsyncRes<D, E> d;

  /// The fifth recipe.
  final AsyncRes<F, E> e;

  /// Runs all recipes concurrently and combines results into a typed record.
  ResultAsync<(A, B, C, D, F), E> run() async {
    final results = await (a.run(), b.run(), c.run(), d.run(), e.run()).wait;
    final (resA, resB, resC, resD, resE) = results;

    return resA.fold(
      onSuccess: (va) => resB.fold(
        onSuccess: (vb) => resC.fold(
          onSuccess: (vc) => resD.fold(
            onSuccess: (vd) => resE.fold(
              onSuccess: (ve) => Ok((va, vb, vc, vd, ve)),
              onError: Err.new,
            ),
            onError: Err.new,
          ),
          onError: Err.new,
        ),
        onError: Err.new,
      ),
      onError: Err.new,
    );
  }
}
