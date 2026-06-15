// Because of this is testing deprecated_member_use_from_same_package, we need
//to ignore it in this test file.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:explicit/explicit.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('isSuccess / isFailure report the right variant', () {
      //Arrange
      const okResult = Ok<int, String>(42);
      const errResult = Err<int, String>('error');

      //Assert - Act
      expect(okResult.isSuccess, isTrue);
      expect(okResult.isFailure, isFalse);
      expect(errResult.isSuccess, isFalse);
      expect(errResult.isFailure, isTrue);
    });

    test('isSuccess / isFailure for zero and empty error boundaries', () {
      //Arrange
      const okResult = Ok<int, String>(0);
      const errResult = Err<int, String>('');

      //Assert - Act
      expect(okResult.isSuccess, isTrue);
      expect(okResult.isFailure, isFalse);
      expect(errResult.isSuccess, isFalse);
      expect(errResult.isFailure, isTrue);
    });

    group('values (deprecated)', () {
      test('normal case', () {
        //Arrange
        const result = Ok<String, Object>('success');
        const errorResult = Err<int, String>('error');

        //Act
        final (value, error) = result.values;
        final (errorValue, errorError) = errorResult.values;

        //Assert
        expect(value, 'success');
        expect(error, isNull);
        expect(errorValue, isNull);
        expect(errorError, 'error');
      });
      test('null values', () {
        //Arrange
        const result = Ok<String?, Object>(null);
        const errorResult = Err<int, String?>(null);

        //Act
        final (value, error) = result.values;
        final (errorValue, errorError) = errorResult.values;

        //Assert
        expect(value, isNull);
        expect(error, isNull);
        expect(errorValue, isNull);
        expect(errorError, isNull);
      });
    });
  });
}
