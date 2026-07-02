// Example programs intentionally print output and use experimental APIs so the
// pub.dev Example tab shows the current public surface in an executable form.
// ignore_for_file: avoid_print, cascade_invocations, experimental_member_use
// ignore_for_file: prefer_const_constructors, prefer_final_locals
// ignore_for_file: unnecessary_lambdas, avoid_init_to_null

// Example demonstrating the explicit facade package: all outcome primitives
// plus convenience utilities for nullable conversion and async composition.

import 'package:explicit/explicit.dart';

// Simulated validation returning a Result.
Res<String, String> validateEmail(String email) {
  if (email.contains('@')) return Ok(email);
  return Err('Invalid email: $email');
}

// Simulated lookup returning a nullable value.
String? lookupNickname(String username) {
  final nicknames = {'alice': 'Al', 'bob': 'Bobby'};
  return nicknames[username.toLowerCase()];
}

// Async operation for demonstration.
Future<Res<int, String>> fetchUserId() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return Ok(42);
}

Future<Res<String, String>> fetchUserProfile() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return Ok('Profile for user 42');
}

Future<void> main() async {
  print('=== Nullable to Option (.toOpt) ===');

  // Convert nullable values to explicit Options
  String? maybeName = 'Alice';
  final nameOpt = maybeName.toOpt;
  nameOpt.when(
    onVal: (name) => print('Name: $name'),
    onNil: () => print('No name'),
  );

  String? noName = null;
  final nilOpt = noName.toOpt;
  print('Null converted: $nilOpt');

  print('\n=== Result Basics ===');

  // Success and error handling
  final email = validateEmail('user@example.com');
  email.when(
    onSuccess: (value) => print('Valid: $value'),
    onError: (error) => print('Invalid: $error'),
  );

  // Chaining with next
  final normalized = validateEmail('USER@Example.COM').next((email) {
    return Ok<String, String>(email.toLowerCase());
  });
  print('Normalized: $normalized');

  print('\n=== AsyncRes with .toAsyncRes() ===');

  // Convert a function returning Future<Res> to lazy AsyncRes
  final lazyFetch = fetchUserId.toAsyncRes();
  print('Created lazy recipe - no work done yet');

  // Execute and chain
  final userId = await lazyFetch.run();
  userId.when(
    onSuccess: (id) => print('User ID: $id'),
    onError: (err) => print('Error: $err'),
  );

  // Chain async operations
  final profile = fetchUserId.toAsyncRes().next((id) {
    return AsyncRes(() => fetchUserProfile());
  });
  final profileResult = await profile.run();
  print('Profile: $profileResult');

  print('\n=== ParallelRes2 (Concurrent Async Results) ===');

  // Run two async operations concurrently
  final parallel = ParallelRes2<int, String, String>(
    fetchUserId.toAsyncRes(),
    fetchUserProfile.toAsyncRes(),
  );

  final parallelResult = await parallel.run();
  parallelResult.when(
    onSuccess: (record) {
      final (userId, profile) = record;
      print('Parallel success - ID: $userId, Profile: $profile');
    },
    onError: (err) => print('Parallel error: $err'),
  );

  print('\n=== Option with .toOpt and Chaining ===');

  // Convert nullable and chain operations
  final nickname = lookupNickname('Alice').toOpt.next((nick) {
    return Val('Nickname: $nick');
  });
  nickname.when(
    onVal: (msg) => print(msg),
    onNil: () => print('No nickname'),
  );

  // Fallback with or
  final withFallback = lookupNickname('Charlie').toOpt.or(() {
    return Val('No nickname set');
  });
  print('With fallback: $withFallback');

  print('\n=== Pattern Matching ===');

  // Exhaustive switch on Result
  final res = validateEmail('test@example.com');
  switch (res) {
    case Ok(:final value):
      print('Matched Ok: $value');
    case Err(:final error):
      print('Matched Err: $error');
  }

  // Exhaustive switch on Option
  final opt = lookupNickname('Bob').toOpt;
  switch (opt) {
    case Val(:final value):
      print('Matched Val: $value');
    case Nil():
      print('Matched Nil');
  }
}
