import 'dart:io';

import 'package:test/test.dart';

typedef _FileCase = ({
  String name,
  String path,
  String expectedContent,
});

void main() {
  group('example app layout', () {
    final testCases = <_FileCase>[
      (
        name: 'example has its own pubspec with parent path dependency',
        path: 'example/pubspec.yaml',
        expectedContent: 'explicit:\n    path: ../',
      ),
      (
        name: 'example uses Very Good CLI Dart entrypoint',
        path: 'example/bin/explicit_example.dart',
        expectedContent: 'Future<void> main(List<String> args) async',
      ),
      (
        name: 'example keeps the Very Good CLI command runner structure',
        path: 'example/lib/src/command_runner.dart',
        expectedContent: 'extends CompletionCommandRunner<int>',
      ),
      (
        name: 'README enters the example directory before running the app',
        path: 'README.md',
        expectedContent: 'cd example',
      ),
      (
        name: 'README documents the dart run command',
        path: 'README.md',
        expectedContent: 'dart run',
      ),
      (
        name: 'README documents current lib line coverage',
        path: 'README.md',
        expectedContent: '100%** (75/75 lines)',
      ),
    ];

    for (final tc in testCases) {
      test(tc.name, () {
        final file = File(tc.path);

        expect(file.existsSync(), isTrue, reason: '${tc.path} must exist');
        expect(file.readAsStringSync(), contains(tc.expectedContent));
      });
    }
  });
}
