// Publish simulation CLI: safe no-op publish that logs what would be published.
//
// Usage:
//   dart run tool/publish_simulation.dart
//   dart run tool/publish_simulation.dart --packages=explicit_outcome,explicit
//   dart run tool/publish_simulation.dart --all
//
// SAFETY: This script NEVER executes real publish commands.
// It only prints what WOULD be published, in what order.
// The final step is always a no-op simulation log.

import 'dart:io';

import 'src/affected_detector.dart';
import 'src/package_info.dart';
import 'src/publish_safety.dart';

Future<void> main(List<String> args) async {
  stdout
    ..writeln('=== Publish Simulation (No-Op) ===')
    ..writeln();

  // Determine explicit publish candidates.
  //
  // IMPORTANT: validation expansion and publish selection are separate. For
  // example, an `explicit_outcome` change may validate dependent `explicit`,
  // but it must not automatically publish `explicit` unless that package is an
  // intentional release candidate too.
  final List<String> packageNames;
  final customPackages = args
      .where((a) => a.startsWith('--packages='))
      .map((a) => a.substring('--packages='.length))
      .firstOrNull;
  final includeAll = args.contains('--all');

  if (customPackages != null) {
    packageNames = customPackages
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  } else if (includeAll) {
    packageNames = AffectedDetector.allPackages.toList();
  } else {
    packageNames = const [];
  }

  if (packageNames.isEmpty) {
    stdout
      ..writeln('No publish candidates selected.')
      ..writeln()
      ..writeln('Validation may still run for all affected/dependent packages,')
      ..writeln('but publish simulation requires explicit release intent.')
      ..writeln()
      ..writeln('Use one of:')
      ..writeln('  dart run tool/publish_simulation.dart --packages=explicit_outcome')
      ..writeln('  dart run tool/publish_simulation.dart --packages=explicit_outcome,explicit')
      ..writeln('  dart run tool/publish_simulation.dart --all')
      ..writeln()
      ..writeln('Status: SIMULATION ONLY — nothing was published');
    return;
  }

  // Read package info from pubspec.yaml files
  final packages = <PackageInfo>[];
  for (final name in packageNames) {
    final pubspecPath = 'packages/$name/pubspec.yaml';
    final pubspecFile = File(pubspecPath);

    if (!pubspecFile.existsSync()) {
      stderr.writeln('ERROR: $pubspecPath not found.');
      exit(1);
    }

    final content = pubspecFile.readAsStringSync();
    try {
      packages.add(PackageInfo.fromPubspecContent(content, 'packages/$name'));
    } on FormatException catch (e) {
      stderr.writeln('ERROR: $e');
      exit(1);
    }
  }

  // Order packages correctly (explicit_outcome before explicit)
  final ordered = PackageInfo.publishOrder(packages);

  // Phase 1: Dry-run readiness check
  stdout
    ..writeln('Phase 1: Publish dry-run readiness')
    ..writeln('---');
  for (final pkg in ordered) {
    stdout
      ..writeln('  ${pkg.name} ${pkg.version} (${pkg.path})')
      ..writeln('  Would run: ${pkg.dryRunCommand()}');
  }
  // Phase 2: Pana max-score gate (informational)
  stdout
    ..writeln()
    ..writeln('Phase 2: Pana max-score gate')
    ..writeln('---')
    ..writeln('  Run: melos run quality:pana')
    ..writeln(
      '  Pass condition: max score or known format-only Pana exception',
    )
    ..writeln()
    ..writeln('Phase 3: No-op publish simulation')
    ..writeln('---');
  for (final pkg in ordered) {
    stdout.writeln('  ${pkg.simulationLine()}');
  }
  // Self-safety assertion: verify this script's own content is safe
  stdout
    ..writeln()
    ..writeln('Safety self-check: verifying no forbidden patterns...');
  final selfFile = File('tool/publish_simulation.dart');
  if (selfFile.existsSync()) {
    final selfContent = selfFile.readAsStringSync();
    final safetyResult = PublishSafety.assertSafeContent(selfContent);
    if (!safetyResult.isSafe) {
      stderr.writeln('CRITICAL: publish_simulation.dart contains violations:');
      for (final v in safetyResult.violations) {
        stderr.writeln('  $v');
      }
      exit(2);
    }
    stdout.writeln('  ✅ Self-check passed: no forbidden publish patterns');
  } else {
    stdout.writeln('  ⚠️  Could not read self for safety check (skipped)');
  }

  stdout
    ..writeln()
    ..writeln('=== Simulation Complete ===')
    ..writeln()
    ..writeln('Summary:')
    ..writeln('  Packages: ${ordered.map((p) => p.name).join(', ')}')
    ..writeln(
      '  Order: '
      '${ordered.map((p) => '${p.name}@${p.version}').join(' → ')}',
    )
    ..writeln('  Status: SIMULATION ONLY — nothing was published')
    ..writeln()
    ..writeln(
      'To enable real publishing: replace this no-op step with '
      'OIDC/trusted publishing configuration.',
    );
}
