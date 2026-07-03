// Command construction for the quality gate.
//
// Keeping these arguments centralized makes the CLI contract testable without
// spawning subprocesses from unit tests.

const dartExecutable = 'dart';

const testCoverageDirectory = 'coverage';
const lcovOutputPath = 'coverage/lcov.info';
const lcovReportOnPath = 'lib';
const packageConfigPathFromPackage = '../../.dart_tool/package_config.json';

/// Returns the package directory used as the working directory for package
/// gates.
String packageWorkingDirectory(String package) => 'packages/$package';

/// Arguments for `dart format`.
const qualityGateFormatArgs = [
  'format',
  '--output=none',
  '--set-exit-if-changed',
  '.',
];

/// Arguments for `dart analyze`.
const qualityGateAnalyzeArgs = [
  'analyze',
  '--fatal-infos',
  '.',
];

/// Arguments for `dart test`.
///
/// The command intentionally avoids selection flags (`--name`, `--tags`, etc.)
/// so the quality gate cannot accidentally run only a focused subset. The
/// `--run-skipped` flag is supported by package:test and turns skipped tests
/// into executable tests for pre-commit validation.
const qualityGateTestArgs = [
  'test',
  '--coverage=$testCoverageDirectory',
  '--run-skipped',
];

/// Arguments for converting package coverage output to LCOV.
const qualityGateLcovArgs = [
  'run',
  'coverage:format_coverage',
  '--lcov',
  '--in=$testCoverageDirectory',
  '--out=$lcovOutputPath',
  '--report-on=$lcovReportOnPath',
  '--packages=$packageConfigPathFromPackage',
];
