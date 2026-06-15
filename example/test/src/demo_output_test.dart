import 'package:explicit_example/src/demo_output.dart';
import 'package:test/test.dart';

typedef _DemoOutputCase = ({
  String name,
  bool Function(List<String> output) assertOutput,
});

void main() {
  group('demo output', () {
    final testCases = <_DemoOutputCase>[
      (
        name: 'prints success and failure section',
        assertOutput: (output) =>
            output.contains('== 1. Success and failure ==') &&
            output.contains('success: 5') &&
            output.contains('error: division by zero'),
      ),
      (
        name: 'prints flatMap and andThen section',
        assertOutput: (output) =>
            output.contains('== 2. flatMap / andThen ==') &&
            output.contains('length: 8'),
      ),
      (
        name: 'prints deprecated toRecord section',
        assertOutput: (output) =>
            output.contains('== 3. toRecord (deprecated compatibility) ==') &&
            output.contains('ok record: (5, null)') &&
            output.contains('err record: (null, division by zero)'),
      ),
      (
        name: 'prints lazy AsyncRes pipeline section in order',
        assertOutput: (output) {
          final built = output.indexOf(
            '  (pipeline built — nothing has run yet)',
          );
          final initial = output.indexOf('  (running initial step)');
          final mapped = output.indexOf('  (mapping 2)');
          final flatMapped = output.indexOf('  (flat-mapping 20)');
          return output.contains('== 4. AsyncRes lazy pipeline ==') &&
              built != -1 &&
              initial > built &&
              mapped > initial &&
              flatMapped > mapped &&
              output.contains('final: value=20');
        },
      ),
      (
        name: 'prints retry and awaited composition sections',
        assertOutput: (output) =>
            output.contains('== 5. AsyncRes with retry ==') &&
            output.contains('attempts used: 3') &&
            output.contains('payload: payload') &&
            output.contains('== 6. AsyncRes composition with awaitable ==') &&
            output.contains('ping: reachable'),
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () async {
        final output = await buildDemoOutput();

        expect(tc.assertOutput(output), isTrue);
      });
    }
  });
}
