import 'package:explicit_outcome/explicit_outcome.dart';
import 'package:meta/meta.dart';

/// Runs two [AsyncOpt] recipes concurrently and combines their results into
/// a typed record.
///
/// On [run], both recipes start together. If both produce [Val],
/// the result is `Val<(A, B)>`. If any recipe produces [Nil], the result
/// is `Nil`.
///
/// No work happens until [run] is called. Each call to [run]
/// re-executes all recipes — there is no hidden caching.
///
/// Exceptions thrown by recipes propagate; this class does not catch, retry,
/// or convert thrown errors.
@experimental
final class ParallelOpt2<A extends Object, B extends Object> {
  /// Creates a parallel combinator for two [AsyncOpt] recipes.
  const ParallelOpt2(this.a, this.b);

  /// The first recipe.
  final AsyncOpt<A> a;

  /// The second recipe.
  final AsyncOpt<B> b;

  /// Runs all recipes concurrently and combines results into a typed record.
  OptionAsync<(A, B)> run() async {
    final results = await (a.run(), b.run()).wait;
    final (optA, optB) = results;

    return optA.fold<Opt<(A, B)>>(
      onVal: (va) => optB.fold<Opt<(A, B)>>(
        onVal: (vb) => Val((va, vb)),
        onNil: () => const Nil(),
      ),
      onNil: () => const Nil(),
    );
  }
}

/// Runs three [AsyncOpt] recipes concurrently and combines their results into
/// a typed record.
///
/// On [run], all recipes start together. If all produce [Val],
/// the result is `Val<(A, B, C)>`. If any recipe produces [Nil], the result
/// is `Nil`.
///
/// No work happens until [run] is called. Each call to [run]
/// re-executes all recipes — there is no hidden caching.
///
/// Exceptions thrown by recipes propagate; this class does not catch, retry,
/// or convert thrown errors.
@experimental
final class ParallelOpt3<A extends Object, B extends Object, C extends Object> {
  /// Creates a parallel combinator for three [AsyncOpt] recipes.
  const ParallelOpt3(this.a, this.b, this.c);

  /// The first recipe.
  final AsyncOpt<A> a;

  /// The second recipe.
  final AsyncOpt<B> b;

  /// The third recipe.
  final AsyncOpt<C> c;

  /// Runs all recipes concurrently and combines results into a typed record.
  OptionAsync<(A, B, C)> run() async {
    final results = await (a.run(), b.run(), c.run()).wait;
    final (optA, optB, optC) = results;

    return optA.fold<Opt<(A, B, C)>>(
      onVal: (va) => optB.fold<Opt<(A, B, C)>>(
        onVal: (vb) => optC.fold<Opt<(A, B, C)>>(
          onVal: (vc) => Val((va, vb, vc)),
          onNil: () => const Nil(),
        ),
        onNil: () => const Nil(),
      ),
      onNil: () => const Nil(),
    );
  }
}

/// Runs four [AsyncOpt] recipes concurrently and combines their results into
/// a typed record.
///
/// On [run], all recipes start together. If all produce [Val],
/// the result is `Val<(A, B, C, D)>`. If any recipe produces [Nil], the
/// result is `Nil`.
///
/// No work happens until [run] is called. Each call to [run]
/// re-executes all recipes — there is no hidden caching.
///
/// Exceptions thrown by recipes propagate; this class does not catch, retry,
/// or convert thrown errors.
@experimental
final class ParallelOpt4<
  A extends Object,
  B extends Object,
  C extends Object,
  D extends Object
> {
  /// Creates a parallel combinator for four [AsyncOpt] recipes.
  const ParallelOpt4(this.a, this.b, this.c, this.d);

  /// The first recipe.
  final AsyncOpt<A> a;

  /// The second recipe.
  final AsyncOpt<B> b;

  /// The third recipe.
  final AsyncOpt<C> c;

  /// The fourth recipe.
  final AsyncOpt<D> d;

  /// Runs all recipes concurrently and combines results into a typed record.
  OptionAsync<(A, B, C, D)> run() async {
    final results = await (a.run(), b.run(), c.run(), d.run()).wait;
    final (optA, optB, optC, optD) = results;

    return optA.fold<Opt<(A, B, C, D)>>(
      onVal: (va) => optB.fold<Opt<(A, B, C, D)>>(
        onVal: (vb) => optC.fold<Opt<(A, B, C, D)>>(
          onVal: (vc) => optD.fold<Opt<(A, B, C, D)>>(
            onVal: (vd) => Val((va, vb, vc, vd)),
            onNil: () => const Nil(),
          ),
          onNil: () => const Nil(),
        ),
        onNil: () => const Nil(),
      ),
      onNil: () => const Nil(),
    );
  }
}

/// Runs five [AsyncOpt] recipes concurrently and combines their results into
/// a typed record.
///
/// On [run], all recipes start together. If all produce [Val],
/// the result is `Val<(A, B, C, D, E)>`. If any recipe produces [Nil], the
/// result is `Nil`.
///
/// No work happens until [run] is called. Each call to [run]
/// re-executes all recipes — there is no hidden caching.
///
/// Exceptions thrown by recipes propagate; this class does not catch, retry,
/// or convert thrown errors.
@experimental
final class ParallelOpt5<
  A extends Object,
  B extends Object,
  C extends Object,
  D extends Object,
  E extends Object
> {
  /// Creates a parallel combinator for five [AsyncOpt] recipes.
  const ParallelOpt5(this.a, this.b, this.c, this.d, this.e);

  /// The first recipe.
  final AsyncOpt<A> a;

  /// The second recipe.
  final AsyncOpt<B> b;

  /// The third recipe.
  final AsyncOpt<C> c;

  /// The fourth recipe.
  final AsyncOpt<D> d;

  /// The fifth recipe.
  final AsyncOpt<E> e;

  /// Runs all recipes concurrently and combines results into a typed record.
  OptionAsync<(A, B, C, D, E)> run() async {
    final results = await (a.run(), b.run(), c.run(), d.run(), e.run()).wait;
    final (optA, optB, optC, optD, optE) = results;

    return optA.fold<Opt<(A, B, C, D, E)>>(
      onVal: (va) => optB.fold<Opt<(A, B, C, D, E)>>(
        onVal: (vb) => optC.fold<Opt<(A, B, C, D, E)>>(
          onVal: (vc) => optD.fold<Opt<(A, B, C, D, E)>>(
            onVal: (vd) => optE.fold<Opt<(A, B, C, D, E)>>(
              onVal: (ve) => Val((va, vb, vc, vd, ve)),
              onNil: () => const Nil(),
            ),
            onNil: () => const Nil(),
          ),
          onNil: () => const Nil(),
        ),
        onNil: () => const Nil(),
      ),
      onNil: () => const Nil(),
    );
  }
}
