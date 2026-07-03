import 'package:test/test.dart';

import '../src/package_info.dart';

void main() {
  group('PackageInfo', () {
    group('fromPubspecContent', () {
      test('parses name and version from pubspec content', () {
        const pubspecContent = '''
name: explicit_outcome
version: 0.0.1
description: Some package
''';
        final info = PackageInfo.fromPubspecContent(
          pubspecContent,
          'packages/explicit_outcome',
        );
        expect(info.name, 'explicit_outcome');
        expect(info.version, '0.0.1');
        expect(info.path, 'packages/explicit_outcome');
      });

      test('handles version with pre-release suffix', () {
        const pubspecContent = '''
name: explicit
version: 1.2.3-dev.1
description: Some package
''';
        final info = PackageInfo.fromPubspecContent(
          pubspecContent,
          'packages/explicit',
        );
        expect(info.name, 'explicit');
        expect(info.version, '1.2.3-dev.1');
      });

      test('throws on missing name field', () {
        const pubspecContent = '''
version: 0.0.1
description: No name
''';
        expect(
          () => PackageInfo.fromPubspecContent(
            pubspecContent,
            'packages/unknown',
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on missing version field', () {
        const pubspecContent = '''
name: explicit
description: No version
''';
        expect(
          () => PackageInfo.fromPubspecContent(
            pubspecContent,
            'packages/explicit',
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles multiline description without confusion', () {
        const pubspecContent = '''
name: explicit_outcome
version: 0.0.1
description: >
  Dart typed outcomes for explicit,
  predictable development.
''';
        final info = PackageInfo.fromPubspecContent(
          pubspecContent,
          'packages/explicit_outcome',
        );
        expect(info.name, 'explicit_outcome');
        expect(info.version, '0.0.1');
      });
    });

    group('publishOrder', () {
      test('explicit_outcome comes before explicit', () {
        final packages = [
          const PackageInfo(
            name: 'explicit',
            version: '0.0.1',
            path: 'packages/explicit',
          ),
          const PackageInfo(
            name: 'explicit_outcome',
            version: '0.0.1',
            path: 'packages/explicit_outcome',
          ),
        ];
        final ordered = PackageInfo.publishOrder(packages);
        expect(ordered[0].name, 'explicit_outcome');
        expect(ordered[1].name, 'explicit');
      });

      test('maintains order for single package', () {
        final packages = [
          const PackageInfo(
            name: 'explicit_outcome',
            version: '0.0.1',
            path: 'packages/explicit_outcome',
          ),
        ];
        final ordered = PackageInfo.publishOrder(packages);
        expect(ordered, hasLength(1));
        expect(ordered[0].name, 'explicit_outcome');
      });
    });

    group('simulationLine', () {
      test('produces expected simulation output format', () {
        const info = PackageInfo(
          name: 'explicit_outcome',
          version: '0.0.1',
          path: 'packages/explicit_outcome',
        );
        final line = info.simulationLine();
        expect(
          line,
          'SIMULATION ONLY: would publish explicit_outcome 0.0.1 '
          'from packages/explicit_outcome',
        );
      });

      test('includes correct package name and version', () {
        const info = PackageInfo(
          name: 'explicit',
          version: '1.2.3',
          path: 'packages/explicit',
        );
        final line = info.simulationLine();
        expect(line, contains('explicit'));
        expect(line, contains('1.2.3'));
        expect(line, contains('SIMULATION ONLY'));
      });
    });

    group('dryRunCommand', () {
      test('returns the safe dry-run command', () {
        const info = PackageInfo(
          name: 'explicit_outcome',
          version: '0.0.1',
          path: 'packages/explicit_outcome',
        );
        expect(info.dryRunCommand(), 'dart pub publish --dry-run');
      });
    });
  });
}
