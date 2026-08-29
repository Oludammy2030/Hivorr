import 'package:flutter_test/flutter_test.dart';

/// Repeatedly pumps the widget tree until [condition] is satisfied or
/// [timeout] elapses.
///
/// Polls by advancing the clock with [interval] between checks. Fails with a
/// descriptive message if the condition is never met within [timeout].
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final DateTime deadline = tester.binding.clock.now().add(timeout);
  while (!condition()) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw Exception(
        'pumpUntil timed out after $timeout waiting for the expected '
        'condition to become true.',
      );
    }
    await tester.pump(interval);
  }
}
