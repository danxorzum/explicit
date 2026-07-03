import 'package:test/test.dart';

import '../src/coverage_parser.dart';

void main() {
  group('CoverageParser', () {
    group('parseLcov', () {
      test('returns 100% when all lines are hit', () {
        const lcovContent = '''
SF:lib/src/some_file.dart
DA:1,1
DA:2,1
DA:3,1
LF:3
LH:3
end_of_record
''';
        final result = CoverageParser.parseLcov(lcovContent);
        expect(result.linesFound, 3);
        expect(result.linesHit, 3);
        expect(result.coveragePercent, 100.0);
      });

      test('returns correct percentage when some lines are missed', () {
        const lcovContent = '''
SF:lib/src/some_file.dart
DA:1,1
DA:2,0
DA:3,1
DA:4,0
LF:4
LH:2
end_of_record
''';
        final result = CoverageParser.parseLcov(lcovContent);
        expect(result.linesFound, 4);
        expect(result.linesHit, 2);
        expect(result.coveragePercent, 50.0);
      });

      test('aggregates multiple source files', () {
        const lcovContent = '''
SF:lib/src/file1.dart
DA:1,1
DA:2,1
LF:2
LH:2
end_of_record
SF:lib/src/file2.dart
DA:1,1
DA:2,0
DA:3,1
LF:3
LH:2
end_of_record
''';
        final result = CoverageParser.parseLcov(lcovContent);
        expect(result.linesFound, 5);
        expect(result.linesHit, 4);
        expect(result.coveragePercent, 80.0);
      });

      test('returns 0% when no lines are hit', () {
        const lcovContent = '''
SF:lib/src/some_file.dart
DA:1,0
DA:2,0
LF:2
LH:0
end_of_record
''';
        final result = CoverageParser.parseLcov(lcovContent);
        expect(result.linesFound, 2);
        expect(result.linesHit, 0);
        expect(result.coveragePercent, 0.0);
      });

      test('handles empty content', () {
        const lcovContent = '';
        final result = CoverageParser.parseLcov(lcovContent);
        expect(result.linesFound, 0);
        expect(result.linesHit, 0);
        expect(result.coveragePercent, 100.0);
      });

      test('handles content with only DA lines and no LF/LH', () {
        const lcovContent = '''
SF:lib/src/some_file.dart
DA:1,1
DA:2,0
end_of_record
''';
        final result = CoverageParser.parseLcov(lcovContent);
        expect(result.linesFound, 0);
        expect(result.linesHit, 0);
        expect(result.coveragePercent, 100.0);
      });

      test('handles real-world lcov format with multiple records', () {
        const lcovContent = '''
SF:/home/user/project/lib/src/option/async_opt.dart
DA:19,1
DA:25,1
DA:26,2
LF:32
LH:32
end_of_record
SF:/home/user/project/lib/src/option/opt.dart
DA:41,2
DA:53,8
LF:20
LH:18
end_of_record
''';
        final result = CoverageParser.parseLcov(lcovContent);
        expect(result.linesFound, 52);
        expect(result.linesHit, 50);
        expect(result.coveragePercent, closeTo(96.15, 0.01));
        expect(result.isFullCoverage, isFalse);
      });

      test('whitespace-only content treated as empty', () {
        const lcovContent = '   \n\n  \n';
        final result = CoverageParser.parseLcov(lcovContent);
        expect(result.linesFound, 0);
        expect(result.linesHit, 0);
        expect(result.isFullCoverage, isTrue);
      });
    });

    group('CoverageResult', () {
      test('isFullCoverage returns true when 100%', () {
        const result = CoverageResult(linesFound: 10, linesHit: 10);
        expect(result.isFullCoverage, isTrue);
      });

      test('isFullCoverage returns false when below 100%', () {
        const result = CoverageResult(linesFound: 10, linesHit: 9);
        expect(result.isFullCoverage, isFalse);
      });

      test('isFullCoverage returns true when no lines found', () {
        const result = CoverageResult(linesFound: 0, linesHit: 0);
        expect(result.isFullCoverage, isTrue);
      });
    });
  });
}
