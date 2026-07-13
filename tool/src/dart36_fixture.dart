// @dart=3.5

/// Dart 3.6 compatibility fixture — pure functions for generating the
/// external path-consumer project that proves package SDK floor outside
/// the workspace (workspace resolution forces Dart 3.12+).
///
/// The CLI wrapper [tool/dart36_compatibility.dart] uses these to create
/// a temporary directory, write the generated files, and run
/// `pub get` / `analyze` / `test` on whatever SDK is available.
library;

/// Generates a consumer `pubspec.yaml` that depends on both packages
/// via path dependencies, outside the workspace.
///
/// Uses `dependency_overrides` for `explicit_outcome` because pub cannot
/// satisfy `explicit`'s hosted dependency with the consumer's direct path
/// dependency. Call [validateExplicitOutcomeConstraint] before writing the
/// fixture so the override does not mask coordinated release drift.
String generateConsumerPubspec({
  required String explicitPath,
  required String outcomePath,
}) {
  return '''
name: dart36_compatibility_consumer
description: >-
  Temporary fixture that proves explicit + explicit_outcome resolve,
  analyze, and pass smoke tests on Dart >=3.6.0 <4.0.0 outside the
  workspace.
publish_to: none

environment:
  sdk: ">=3.6.0 <4.0.0"

dependencies:
  explicit:
    path: $explicitPath
  explicit_outcome:
    path: $outcomePath

dev_dependencies:
  test: ">=1.25.0 <2.0.0"
  very_good_analysis: ^7.0.0

dependency_overrides:
  explicit_outcome:
    path: $outcomePath
''';
}

/// Validates that `explicit` depends on the local `explicit_outcome` version.
void validateExplicitOutcomeConstraint({
  required String explicitPubspec,
  required String outcomePubspec,
}) {
  final outcomeVersion = _readTopLevelVersion(outcomePubspec);
  final explicitOutcomeConstraint = _readExplicitOutcomeConstraint(
    explicitPubspec,
  );
  final expectedConstraint = '^$outcomeVersion';

  if (explicitOutcomeConstraint != expectedConstraint) {
    throw StateError(
      'packages/explicit/pubspec.yaml must depend on explicit_outcome '
      '$expectedConstraint for the coordinated compatibility release; found '
      '$explicitOutcomeConstraint.',
    );
  }
}

String _readTopLevelVersion(String pubspec) {
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    throw StateError(
      'packages/explicit_outcome/pubspec.yaml is missing version.',
    );
  }
  return match.group(1)!;
}

String _readExplicitOutcomeConstraint(String pubspec) {
  final match = RegExp(
    r'^\s{2}explicit_outcome:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    throw StateError(
      'packages/explicit/pubspec.yaml is missing explicit_outcome dependency.',
    );
  }
  return match.group(1)!;
}

/// Generates `analysis_options.yaml` for the fixture consumer project.
String generateAnalysisOptions() {
  return 'include: package:very_good_analysis/analysis_options.yaml\n';
}

/// Generates a minimal smoke test that imports both packages and
/// exercises core Result/Option types to prove they compile and
/// behave correctly on the target SDK.
String generateSmokeTest() {
  return '''
// Smoke test: proves explicit + explicit_outcome compile and behave
// correctly on the Dart 3.6 compatibility floor.

// The fixture is generated code; blanket-ignore lint noise that would
// not apply to real consumer code.
// ignore_for_file: avoid_print

import 'package:explicit/explicit.dart';

/// Returns a nullable String at runtime so the type is genuinely
/// nullable (avoids const-folding to non-nullable).
String? _nullable([String? value]) => value;

void main() {
  // Result: Ok and Err construct and fold correctly.
  const ok = Ok<int, String>(42);
  assert(ok.isSuccess, 'Ok should report success');
  assert(
    ok.fold(onSuccess: (v) => v, onError: (e) => -1) == 42,
    'Ok fold should return success value',
  );

  const err = Err<int, String>('fail');
  assert(err.isFailure, 'Err should report failure');
  assert(
    err.fold(onSuccess: (v) => v, onError: (e) => e) == 'fail',
    'Err fold should return error value',
  );

  // Option: Val and Nil construct and fold correctly.
  const val = Val<int>(7);
  assert(val.hasValue, 'Val should report hasValue');
  assert(
    val.fold(onVal: (v) => v, onNil: () => -1) == 7,
    'Val fold should return value',
  );

  const nil = Nil<int>();
  assert(nil.isNil, 'Nil should report isNil');

  // Composition: map + next short-circuit on Err.
  final chain = const Ok<int, String>(10)
      .map((v) => v * 2)
      .next<String>(
        (v) => v > 0
            ? const Ok<String, String>('ok')
            : const Err<String, String>('nope'),
      );
  assert(
    chain.fold(onSuccess: (v) => v, onError: (e) => e) == 'ok',
    'Chained Ok should map then next to ok',
  );

  final broken = const Err<int, String>('bad')
      .map((v) => v * 2)
      .next<String>((v) => const Ok<String, String>('unreachable'));
  assert(
    broken.fold(onSuccess: (v) => v, onError: (e) => e) == 'bad',
    'Err should short-circuit map and next',
  );

  // Res compact alias works.
  Res<int, String> divide(int a, int b) {
    if (b == 0) return const Err<int, String>('division by zero');
    return Ok<int, String>(a ~/ b);
  }

  assert(divide(10, 2).isSuccess, 'divide(10,2) should succeed');
  assert(divide(10, 0).isFailure, 'divide(10,0) should fail');

  // toOpt extension on nullable.
  final maybe = _nullable('hello');
  final opt = maybe.toOpt;
  assert(opt.hasValue, 'non-null toOpt should be Val');

  final nothing = _nullable();
  final nilOpt = nothing.toOpt;
  assert(nilOpt.isNil, 'null toOpt should be Nil');

print('Dart 3.6 compatibility smoke test passed.');
}
''';
}
