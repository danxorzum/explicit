// @dart=3.5

// Dart 3.6 compatibility fixture CLI.
//
// Creates a temporary path-consumer project outside the workspace and runs
// `pub get`, `analyze --fatal-infos`, and the smoke test to prove the
// declared SDK floor (>=3.6.0 <4.0.0) works for both packages.
//
// Usage:
//   dart tool/dart36_compatibility.dart [--repo-root=<path>]
//
// The workspace forces Dart 3.12+ for maintainer tooling, so the package
// floor must be proven by an external consumer. CI runs this on Dart 3.6.

import 'dart:io';

import 'src/dart36_fixture.dart';

Future<void> main(List<String> args) async {
  final repoRoot = _parseRepoRoot(args);

  final explicitDir = Directory('$repoRoot/packages/explicit');
  final outcomeDir = Directory('$repoRoot/packages/explicit_outcome');

  if (!explicitDir.existsSync() || !outcomeDir.existsSync()) {
    stderr.writeln(
      'Error: packages/explicit and packages/explicit_outcome '
      'must exist under $repoRoot',
    );
    exit(66); // EX_NOINPUT
  }

  validateExplicitOutcomeConstraint(
    explicitPubspec: File(
      '${explicitDir.path}/pubspec.yaml',
    ).readAsStringSync(),
    outcomePubspec: File('${outcomeDir.path}/pubspec.yaml').readAsStringSync(),
  );

  stdout
    ..writeln('=== Dart 3.6 Compatibility Fixture ===')
    ..writeln('Repo root: $repoRoot')
    ..writeln('Dart SDK: ${Platform.version}')
    ..writeln();

  // Create temporary directory for the consumer project.
  final tmpDir = Directory.systemTemp.createTempSync('dart36_fixture_');
  stdout.writeln('Fixture dir: ${tmpDir.path}');

  try {
    _writeFixture(
      fixtureDir: tmpDir,
      explicitAbsPath: explicitDir.resolveSymbolicLinksSync(),
      outcomeAbsPath: outcomeDir.resolveSymbolicLinksSync(),
    );

    // Step 1: pub get
    stdout
      ..writeln()
      ..writeln('--- Step 1: dart pub get ---');
    final pubGetResult = await _run('dart', ['pub', 'get'], tmpDir.path);
    if (pubGetResult != 0) {
      stderr.writeln('FAIL: dart pub get exited with code $pubGetResult');
      exit(1);
    }
    // Step 2: analyze
    stdout
      ..writeln('PASS: dart pub get')
      ..writeln()
      ..writeln('--- Step 2: dart analyze --fatal-infos ---');
    final analyzeResult = await _run(
      'dart',
      [
        'analyze',
        '--fatal-infos',
        '.',
      ],
      tmpDir.path,
    );
    if (analyzeResult != 0) {
      stderr.writeln(
        'FAIL: dart analyze --fatal-infos exited with code $analyzeResult',
      );
      exit(1);
    }
    // Step 3: smoke test
    stdout
      ..writeln('PASS: dart analyze --fatal-infos')
      ..writeln()
      ..writeln('--- Step 3: dart run test/smoke_test.dart ---');
    final smokeResult = await _run(
      'dart',
      [
        'run',
        '--enable-asserts',
        'test/smoke_test.dart',
      ],
      tmpDir.path,
    );
    if (smokeResult != 0) {
      stderr.writeln('FAIL: smoke test exited with code $smokeResult');
      exit(1);
    }
    stdout
      ..writeln('PASS: smoke test')
      ..writeln()
      ..writeln('=== Dart 3.6 compatibility fixture PASSED ===');
  } finally {
    // Clean up.
    try {
      tmpDir.deleteSync(recursive: true);
    } on FileSystemException {
      stderr.writeln('Warning: could not clean up ${tmpDir.path}');
    }
  }
}

String _parseRepoRoot(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--repo-root=')) {
      return arg.substring('--repo-root='.length);
    }
  }
  // Default: current working directory.
  return Directory.current.path;
}

void _writeFixture({
  required Directory fixtureDir,
  required String explicitAbsPath,
  required String outcomeAbsPath,
}) {
  // pubspec.yaml
  File('${fixtureDir.path}/pubspec.yaml').writeAsStringSync(
    generateConsumerPubspec(
      explicitPath: explicitAbsPath,
      outcomePath: outcomeAbsPath,
    ),
  );

  // analysis_options.yaml
  File(
    '${fixtureDir.path}/analysis_options.yaml',
  ).writeAsStringSync(generateAnalysisOptions());

  // test/smoke_test.dart
  Directory('${fixtureDir.path}/test').createSync();
  File(
    '${fixtureDir.path}/test/smoke_test.dart',
  ).writeAsStringSync(generateSmokeTest());
}

Future<int> _run(String executable, List<String> args, String workingDir) {
  return Process.start(
    executable,
    args,
    workingDirectory: workingDir,
    mode: ProcessStartMode.inheritStdio,
  ).then((process) => process.exitCode);
}
