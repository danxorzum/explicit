import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('NullableToOpt analyzer contract', () {
    test('analyzer rejects nullable payload in toOpt result', () async {
      final fixture = File(
        '${Directory.current.path}/test/src/outcome/utils/.nullable_to_opt_contract_fixture.dart',
      );
      addTearDown(() async {
        if (fixture.existsSync()) await fixture.delete();
      });

      const source = '''
// ignore_for_file: avoid_print, file_names, unused_local_variable

import 'package:explicit/explicit.dart';

void main() {
  // This should fail: Opt<String?> is not allowed (T extends Object)
  final Opt<String?> badOpt = const Nil<String>();

  // This should fail: Val<String?> is not allowed
  final val = Val<String?>('test');

  print((badOpt, val));
}
''';
      await fixture.writeAsString(source);

      final result = await Process.run(
        'dart',
        ['analyze', fixture.path],
        workingDirectory: Directory.current.path,
      );
      final output = '${result.stdout}\n${result.stderr}';

      expect(
        result.exitCode,
        isNot(0),
        reason: 'Analyzer should reject nullable payloads',
      );
      expect(output, contains('String?'));
    });

    test('toOpt returns Opt with non-null payload type', () async {
      final fixture = File(
        '${Directory.current.path}/test/src/outcome/utils/.to_opt_payload_contract_fixture.dart',
      );
      addTearDown(() async {
        if (fixture.existsSync()) await fixture.delete();
      });

      // This fixture should compile successfully
      const source = '''
// ignore_for_file: avoid_print, file_names, unused_local_variable

import 'package:explicit/explicit.dart';

void main() {
  const String? maybeString = 'hello';
  const int? maybeInt = 42;

  // toOpt should produce Opt<String> and Opt<int> (non-null payloads)
  final Opt<String> stringOpt = maybeString.toOpt;
  final Opt<int> intOpt = maybeInt.toOpt;

  // Pattern matching should work with non-null payload
  final value = switch (stringOpt) {
    Val<String>(:final value) => value,
    Nil<String>() => 'default',
  };

  print((stringOpt, intOpt, value));
}
''';
      await fixture.writeAsString(source);

      final result = await Process.run(
        'dart',
        ['analyze', fixture.path],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: 'Valid toOpt usage should compile');
    });
  });
}
