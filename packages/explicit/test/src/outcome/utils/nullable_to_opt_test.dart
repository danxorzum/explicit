// Tests intentionally declare nullable variables to exercise the .toOpt
// extension.
// ignore_for_file: unnecessary_nullable_for_final_variable_declarations

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

void main() {
  group('NullableToOpt', () {
    test('null maps to Nil', () {
      const String? value = null;

      final result = value.toOpt;

      expect(result, isA<Nil<String>>());
      expect(result.isNil, isTrue);
    });

    test('non-null String? maps to Val<String> with correct value', () {
      const String? value = 'hello';

      final result = value.toOpt;

      expect(result, isA<Val<String>>());
      expect(result.hasValue, isTrue);
      expect(
        result.fold(
          onVal: (v) => v,
          onNil: () => 'fallback',
        ),
        'hello',
      );
    });

    test('non-null int? maps to Val<int> with correct value', () {
      const int? value = 42;

      final result = value.toOpt;

      expect(result, isA<Val<int>>());
      expect(
        result.fold(
          onVal: (v) => v,
          onNil: () => -1,
        ),
        42,
      );
    });

    test('null int? maps to Nil<int>', () {
      const int? value = null;

      final result = value.toOpt;

      expect(result, isA<Nil<int>>());
      expect(result.isNil, isTrue);
    });

    test('toOpt result can be used in pattern matching', () {
      const String? present = 'world';
      const String? absent = null;

      final presentResult = present.toOpt;
      final absentResult = absent.toOpt;

      final presentDescription = switch (presentResult) {
        Val<String>(:final value) => 'val:$value',
        Nil<String>() => 'nil',
      };
      final absentDescription = switch (absentResult) {
        Val<String>(:final value) => 'val:$value',
        Nil<String>() => 'nil',
      };

      expect(presentDescription, 'val:world');
      expect(absentDescription, 'nil');
    });
  });
}
