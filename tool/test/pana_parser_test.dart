import 'package:test/test.dart';

import '../src/pana_parser.dart';

void main() {
  group('PanaParser', () {
    group('parsePanaJson', () {
      test('returns pass when grantedPoints equals maxPoints', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 160,
    "maxPoints": 160
  },
  "packageName": "explicit_outcome"
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.grantedPoints, 160);
        expect(result.maxPoints, 160);
        expect(result.isMaxScore, isTrue);
        expect(result.packageName, 'explicit_outcome');
      });

      test('returns fail when grantedPoints is less than maxPoints', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 140,
    "maxPoints": 160
  },
  "packageName": "explicit"
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.grantedPoints, 140);
        expect(result.maxPoints, 160);
        expect(result.isMaxScore, isFalse);
        expect(result.packageName, 'explicit');
      });

      test('handles different max scores (not hardcoded to 160)', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 200,
    "maxPoints": 200
  },
  "packageName": "some_package"
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.grantedPoints, 200);
        expect(result.maxPoints, 200);
        expect(result.isMaxScore, isTrue);
        expect(result.isAcceptable, isTrue);
      });

      test('allows format-only Pana partial score', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 150,
    "maxPoints": 160
  },
  "packageName": "explicit",
  "report": {
    "sections": [
      {
        "id": "analysis",
        "grantedPoints": 40,
        "maxPoints": 50,
        "status": "partial",
        "summary": "lib/foo.dart doesn't match the Dart formatter."
      }
    ]
  }
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.isMaxScore, isFalse);
        expect(result.hasFormatOnlyException, isTrue);
        expect(result.isAcceptable, isTrue);
      });

      test('does not allow non-format Pana partial score', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 150,
    "maxPoints": 160
  },
  "packageName": "explicit",
  "report": {
    "sections": [
      {
        "id": "analysis",
        "grantedPoints": 40,
        "maxPoints": 50,
        "status": "partial",
        "summary": "Package has analysis warnings."
      }
    ]
  }
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.hasFormatOnlyException, isFalse);
        expect(result.isAcceptable, isFalse);
      });

      test('does not allow format issue plus another partial section', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 140,
    "maxPoints": 160
  },
  "packageName": "explicit",
  "report": {
    "sections": [
      {
        "id": "analysis",
        "grantedPoints": 40,
        "maxPoints": 50,
        "status": "partial",
        "summary": "lib/foo.dart doesn't match the Dart formatter."
      },
      {
        "id": "documentation",
        "grantedPoints": 10,
        "maxPoints": 20,
        "status": "partial",
        "summary": "Missing docs."
      }
    ]
  }
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.hasFormatOnlyException, isFalse);
        expect(result.isAcceptable, isFalse);
      });

      test('handles zero points', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 0,
    "maxPoints": 0
  },
  "packageName": "empty_package"
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.grantedPoints, 0);
        expect(result.maxPoints, 0);
        expect(result.isMaxScore, isTrue);
      });

      test('throws on invalid JSON', () {
        const jsonContent = 'not valid json';
        expect(
          () => PanaParser.parsePanaJson(jsonContent),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on missing scores field', () {
        const jsonContent = '''
{
  "packageName": "explicit"
}
''';
        expect(
          () => PanaParser.parsePanaJson(jsonContent),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on missing grantedPoints', () {
        const jsonContent = '''
{
  "scores": {
    "maxPoints": 160
  },
  "packageName": "explicit"
}
''';
        expect(
          () => PanaParser.parsePanaJson(jsonContent),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on missing maxPoints', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 160
  },
  "packageName": "explicit"
}
''';
        expect(
          () => PanaParser.parsePanaJson(jsonContent),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles empty package name gracefully', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 100,
    "maxPoints": 100
  },
  "packageName": ""
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.packageName, '');
        expect(result.isMaxScore, isTrue);
      });

      test('handles missing packageName field', () {
        const jsonContent = '''
{
  "scores": {
    "grantedPoints": 100,
    "maxPoints": 100
  }
}
''';
        final result = PanaParser.parsePanaJson(jsonContent);
        expect(result.packageName, 'unknown');
        expect(result.isMaxScore, isTrue);
      });
    });

    group('PanaResult', () {
      test('isMaxScore returns true when granted equals max', () {
        const result = PanaResult(
          grantedPoints: 160,
          maxPoints: 160,
          packageName: 'test',
        );
        expect(result.isMaxScore, isTrue);
        expect(result.isAcceptable, isTrue);
      });

      test('isMaxScore returns false when granted is less than max', () {
        const result = PanaResult(
          grantedPoints: 159,
          maxPoints: 160,
          packageName: 'test',
        );
        expect(result.isMaxScore, isFalse);
        expect(result.isAcceptable, isFalse);
      });

      test('isMaxScore returns true when both are zero', () {
        const result = PanaResult(
          grantedPoints: 0,
          maxPoints: 0,
          packageName: 'test',
        );
        expect(result.isMaxScore, isTrue);
      });

      test('scorePercent calculates correctly', () {
        const result = PanaResult(
          grantedPoints: 80,
          maxPoints: 100,
          packageName: 'test',
        );
        expect(result.scorePercent, 80.0);
      });

      test('scorePercent handles zero maxPoints', () {
        const result = PanaResult(
          grantedPoints: 0,
          maxPoints: 0,
          packageName: 'test',
        );
        expect(result.scorePercent, 100.0);
      });
    });
  });
}
