import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/startup/error_screen.dart';

void main() {
  testWidgets('FatalErrorScreen renders the user-safe message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FatalErrorScreen(
          message: 'Something went wrong. Please try again.',
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
  });

  testWidgets('FatalErrorScreen renders a working Retry button', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FatalErrorScreen(
          message: 'Try again later.',
          onRetry: () => retryCount++,
        ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retryCount, 1);
  });
}
