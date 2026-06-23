// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:explicit_outcome/explicit_outcome.dart';
import 'package:test/test.dart';

void main() {
  group('ExplicitOutcome', () {
    test('can be instantiated', () {
      expect(ExplicitOutcome(), isNotNull);
    });
  });
}
