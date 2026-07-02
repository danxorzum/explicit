// Example programs intentionally print output so the pub.dev Example tab shows
// the current public surface in an executable form.
// ignore_for_file: avoid_print, cascade_invocations, prefer_const_constructors

// Example demonstrating explicit_outcome primitives: Result and Option types
// for explicit, predictable error and absence handling.

import 'package:explicit_outcome/explicit_outcome.dart';

// Simulated parsing that returns a Result instead of throwing.
Res<int, String> parseAge(String input) {
  final parsed = int.tryParse(input);
  if (parsed == null) return Err('Invalid number: $input');
  if (parsed < 0 || parsed > 150) return Err('Age out of range: $parsed');
  return Ok(parsed);
}

// Simulated lookup that returns an Option instead of null.
Opt<String> findUsername(int id) {
  final users = {1: 'Alice', 2: 'Bob'};
  final name = users[id];
  return name == null ? const Nil() : Val(name);
}

// Async operation returning AsyncRes for lazy composition.
AsyncRes<String, String> fetchGreeting(int userId) {
  return AsyncRes(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return userId > 0 ? Ok('Hello, user $userId!') : Err('Invalid user ID');
  });
}

Future<void> main() async {
  print('=== Result (Res) ===');

  // Success case
  final age1 = parseAge('25');
  age1.when(
    onSuccess: (value) => print('Parsed age: $value'),
    onError: (error) => print('Parse failed: $error'),
  );

  // Error case
  final age2 = parseAge('abc');
  age2.when(
    onSuccess: (value) => print('Parsed age: $value'),
    onError: (error) => print('Parse failed: $error'),
  );

  // Chaining with next
  final validated = parseAge('30').next<String>((age) {
    if (age >= 18) return Ok<String, String>('Adult');
    return Err('Minor');
  });
  print('Validation: $validated');

  // Transforming errors with mapError
  final mapped = parseAge('-5').mapError((e) => 'ValidationError: $e');
  print('Mapped error: $mapped');

  print('\n=== Option (Opt) ===');

  // Present value
  final user1 = findUsername(1);
  user1.when(
    onVal: (name) => print('Found: $name'),
    onNil: () => print('User not found'),
  );

  // Absent value
  final user2 = findUsername(99);
  user2.when(
    onVal: (name) => print('Found: $name'),
    onNil: () => print('User not found'),
  );

  // Providing a fallback with getOrElse
  final name = findUsername(99).getOrElse(() => 'Anonymous');
  print('Fallback name: $name');

  // Chaining with next
  final greeting = findUsername(2).next((name) => Val('Hello, $name!'));
  print('Greeting: $greeting');

  print('\n=== AsyncRes (Lazy Async Result) ===');

  // AsyncRes is lazy - work only happens when .run() is called
  final asyncGreeting = fetchGreeting(1);
  print('Before run - no work done yet');

  final result = await asyncGreeting.run();
  result.when(
    onSuccess: (msg) => print('Async success: $msg'),
    onError: (err) => print('Async error: $err'),
  );

  // Chaining async operations
  final chained = fetchGreeting(2).next((msg) {
    return AsyncRes(() async => Ok('$msg (processed)'));
  });
  final chainedResult = await chained.run();
  print('Chained: $chainedResult');

  print('\n=== Pattern Matching ===');

  // Exhaustive pattern matching with switch
  final res = parseAge('42');
  switch (res) {
    case Ok(:final value):
      print('Matched Ok: $value');
    case Err(:final error):
      print('Matched Err: $error');
  }

  final opt = findUsername(1);
  switch (opt) {
    case Val(:final value):
      print('Matched Val: $value');
    case Nil():
      print('Matched Nil');
  }
}
