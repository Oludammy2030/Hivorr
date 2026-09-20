import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/shared/shared.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  group('PasswordRequirementsChecklist', () {
    testWidgets('shows all four requirements as unsatisfied when empty', (
      tester,
    ) async {
      final result = PasswordPolicy.supabase.evaluate('');
      await pumpTheme(
        tester,
        PasswordRequirementsChecklist(
          result: result,
          requirements: PasswordPolicy.supabase.required,
        ),
      );

      expect(find.text('Password requirements'), findsOneWidget);
      expect(find.text('Lowercase letter'), findsOneWidget);
      expect(find.text('Uppercase letter'), findsOneWidget);
      expect(find.text('Number'), findsOneWidget);
      expect(find.text('Symbol'), findsOneWidget);
    });

    testWidgets('marks satisfied requirements with check icon', (tester) async {
      final result = PasswordPolicy.supabase.evaluate('hello');
      await pumpTheme(
        tester,
        PasswordRequirementsChecklist(
          result: result,
          requirements: PasswordPolicy.supabase.required,
        ),
      );

      // Only lowercase satisfied
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(3));
    });

    testWidgets('all satisfied shows four check icons', (tester) async {
      final result = PasswordPolicy.supabase.evaluate('Hello123!');
      await pumpTheme(
        tester,
        PasswordRequirementsChecklist(
          result: result,
          requirements: PasswordPolicy.supabase.required,
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
    });
  });

  group('PasswordStrengthIndicator', () {
    testWidgets('shows Weak with one segment', (tester) async {
      await pumpTheme(
        tester,
        const PasswordStrengthIndicator(strength: PasswordStrength.weak),
      );

      expect(find.text('Password strength: Weak'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows Medium', (tester) async {
      await pumpTheme(
        tester,
        const PasswordStrengthIndicator(strength: PasswordStrength.medium),
      );

      expect(find.text('Password strength: Medium'), findsOneWidget);
    });

    testWidgets('shows Strong', (tester) async {
      await pumpTheme(
        tester,
        const PasswordStrengthIndicator(strength: PasswordStrength.strong),
      );

      expect(find.text('Password strength: Strong'), findsOneWidget);
    });
  });

  group('PasswordMatchIndicator', () {
    testWidgets('shows positive state when passwords match', (tester) async {
      await pumpTheme(tester, const PasswordMatchIndicator(matches: true));

      expect(find.text('Passwords match'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('shows error state when passwords do not match', (
      tester,
    ) async {
      await pumpTheme(tester, const PasswordMatchIndicator(matches: false));

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });
  });
}
