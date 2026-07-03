import 'dart:io' as io;

import 'package:explicit_example/src/command_runner.dart';

Future<void> main(List<String> args) async {
  io.exitCode = await ExplicitExampleCommandRunner().run(args);
}
