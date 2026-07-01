import 'dart:io';

import 'package:explicit_outcome/explicit_outcome.dart';
import 'package:test/test.dart';

typedef _OptCase = ({
  String name,
  Opt<int> option,
  bool hasValue,
  bool isNil,
  String folded,
  int fallbackValue,
});

void main() {
  group('Opt', () {
    final testCases = <_OptCase>[
      (
        name: 'reports a present value',
        option: const Val(42),
        hasValue: true,
        isNil: false,
        folded: 'value:42',
        fallbackValue: 42,
      ),
      (
        name: 'reports explicit absence',
        option: const Nil(),
        hasValue: false,
        isNil: true,
        folded: 'nil',
        fallbackValue: -1,
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        expect(tc.option.hasValue, tc.hasValue);
        expect(tc.option.isNil, tc.isNil);
        expect(
          tc.option.fold(
            onVal: (value) => 'value:$value',
            onNil: () => 'nil',
          ),
          tc.folded,
        );
        expect(tc.option.getOrElse(() => -1), tc.fallbackValue);
      });
    }

    test('when executes only the matching presence branch', () {
      final events = <String>[];

      const Val(7).when(
        onVal: (value) => events.add('value:$value'),
        onNil: () => events.add('nil'),
      );
      const Nil<int>().when(
        onVal: (value) => events.add('unexpected:$value'),
        onNil: () => events.add('nil'),
      );

      expect(events, ['value:7', 'nil']);
    });

    test('map transforms present values and preserves nil', () {
      expect(const Val(20).map((value) => value + 22), const Val(42));
      expect(const Nil<int>().map((value) => value + 22), const Nil<int>());
    });

    test('next chains present values and short-circuits nil', () {
      final events = <String>[];

      final present = const Val(20).next((value) {
        events.add('next:$value');
        return Val(value + 22);
      });
      final absent = const Nil<int>().next((value) {
        events.add('unexpected:$value');
        return Val(value + 22);
      });

      expect(present, const Val(42));
      expect(absent, const Nil<int>());
      expect(events, ['next:20']);
    });

    test('or returns present values and evaluates fallback only for nil', () {
      final events = <String>[];

      final present = const Val(42).or(() {
        events.add('unexpected');
        return const Val(0);
      });
      final absent = const Nil<int>().or(() {
        events.add('fallback');
        return const Val(7);
      });

      expect(present, const Val(42));
      expect(absent, const Val(7));
      expect(events, ['fallback']);
    });

    test('equality and toString describe value presence or nil absence', () {
      expect(const Val(42), const Val(42));
      expect(const Val(42), isNot(const Val(7)));
      expect(const Nil<int>(), const Nil<int>());
      expect(const Val(42).toString(), 'Val(42)');
      expect(const Nil<int>().toString(), 'Nil');
      expect(const Val(42).hashCode, const Val(42).hashCode);
      expect(const Nil<int>().hashCode, const Nil<int>().hashCode);
    });

    test('analyzer rejects nullable payload contracts', () async {
      final fixture = File(
        '${Directory.current.path}/test/src/option/.nullable_contract_fixture.dart',
      );
      addTearDown(() async {
        if (fixture.existsSync()) await fixture.delete();
      });

      const source = '''
// ignore_for_file: avoid_print, file_names, prefer_const_constructors

import 'package:explicit_outcome/explicit_outcome.dart';

void main() {
  final opt = <Opt<String?>?>[];
  final option = <Option<String?>?>[];
  final val = Val(null);

  print((opt, option, val));
}
''';
      await fixture.writeAsString(source);

      final result = await Process.run(
        'dart',
        ['analyze', fixture.path],
        workingDirectory: Directory.current.path,
      );
      final output = '${result.stdout}\n${result.stderr}';

      expect(result.exitCode, isNot(0));
      expect(source, contains('Val(null)'));
      expect(output, contains('Opt<String?>'));
      expect(output, contains('Option<String?>'));
      expect(output, contains("The argument type 'Null'"));
    });
  });
}
