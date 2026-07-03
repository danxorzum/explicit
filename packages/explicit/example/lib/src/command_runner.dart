// coverage:ignore-file

import 'dart:io';

import 'package:cli_completion/cli_completion.dart';
import 'package:explicit/explicit.dart';

/// Command runner for the explicit example app.
class ExplicitExampleCommandRunner extends CompletionCommandRunner<int> {
  /// Creates the command runner.
  ExplicitExampleCommandRunner()
    : super('explicit_example', 'Example command-line app for explicit.') {
    argParser.addOption(
      'name',
      abbr: 'n',
      help: 'Name to greet.',
      defaultsTo: 'explicit',
    );
  }

  @override
  Future<int> run(Iterable<String> args) async {
    final results = parse(args);
    final name = results['name'] as String;

    Val('Hello, $name!').when(
      onVal: stdout.writeln,
      onNil: () => stdout.writeln('Hello!'),
    );

    return 0;
  }
}
