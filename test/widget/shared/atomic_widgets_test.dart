import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/shared/shared.dart';

import 'test_helpers.dart';

void main() {
  group('HivorrButton', () {
    testWidgets('renders label and fires onPressed', (WidgetTester tester) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        HivorrButton(label: 'Tap', onPressed: () => tapped = true),
      );
      expect(find.text('Tap'), findsOneWidget);
      await tester.tap(find.byType(HivorrButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows loader when loading and hides label', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        HivorrButton(label: 'L', isLoading: true, onPressed: () {}),
      );
      expect(find.byType(HivorrLoader), findsOneWidget);
      expect(find.text('L'), findsNothing);
    });

    testWidgets('is disabled when onPressed is null', (WidgetTester tester) async {
      await pumpTheme(tester, HivorrButton(label: 'D', onPressed: null));
      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('renders in dark theme without throwing', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        HivorrButton(label: 'Dark', onPressed: () {}),
        dark: true,
      );
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('primary variant background uses colorScheme.primary', (WidgetTester tester) async {
      await pumpTheme(tester, HivorrButton(label: 'X', onPressed: () {}));
      final ElevatedButton btn = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      final Color? bg = btn.style?.backgroundColor?.resolve(<WidgetState>{});
      expect(bg, AppTheme.lightTheme.colorScheme.primary);
    });
  });

  group('HivorrTextField', () {
    testWidgets('fires onChanged and shows error', (WidgetTester tester) async {
      String? changed;
      await pumpTheme(
        tester,
        HivorrTextField(
          label: 'Email',
          errorText: 'bad',
          onChanged: (String v) => changed = v,
        ),
      );
      expect(find.text('Email'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abc');
      expect(changed, 'abc');
      expect(find.text('bad'), findsOneWidget);
    });

    testWidgets('fill uses colorScheme.surface', (WidgetTester tester) async {
      await pumpTheme(tester, const HivorrTextField());
      final TextField tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.decoration?.fillColor, AppTheme.lightTheme.colorScheme.surface);
    });
  });

  group('HivorrCard', () {
    testWidgets('renders child and fires onTap', (WidgetTester tester) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        HivorrCard(child: const Text('inner'), onTap: () => tapped = true),
      );
      expect(find.text('inner'), findsOneWidget);
      await tester.tap(find.byType(HivorrCard));
      expect(tapped, isTrue);
    });
  });

  group('HivorrBadge', () {
    testWidgets('renders label for every variant', (WidgetTester tester) async {
      for (final HivorrBadgeVariant variant in HivorrBadgeVariant.values) {
        await pumpTheme(
          tester,
          HivorrBadge(label: 'X', variant: variant),
        );
        expect(find.text('X'), findsOneWidget);
      }
    });
  });

  group('HivorrChip', () {
    testWidgets('fires onSelected', (WidgetTester tester) async {
      bool selected = false;
      await pumpTheme(
        tester,
        HivorrChip(label: 'C', onSelected: (bool b) => selected = b),
      );
      await tester.tap(find.byType(HivorrChip));
      expect(selected, isTrue);
    });

    testWidgets('fires onDismissed', (WidgetTester tester) async {
      bool dismissed = false;
      await pumpTheme(
        tester,
        HivorrChip(label: 'C', onDismissed: () => dismissed = true),
      );
      await tester.tap(find.byIcon(Icons.cancel));
      expect(dismissed, isTrue);
    });
  });

  group('HivorrDivider', () {
    testWidgets('renders with thickness', (WidgetTester tester) async {
      await pumpTheme(tester, const HivorrDivider(thickness: 2));
      final Divider divider = tester.widget(find.byType(Divider));
      expect(divider.thickness, 2);
    });
  });

  group('HivorrAvatar', () {
    testWidgets('shows initials', (WidgetTester tester) async {
      await pumpTheme(tester, const HivorrAvatar(name: 'John Doe'));
      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('shows person icon when name empty', (WidgetTester tester) async {
      await pumpTheme(tester, const HivorrAvatar(name: ''));
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });

  group('HivorrLoadingState', () {
    testWidgets('shows loader and message', (WidgetTester tester) async {
      await pumpTheme(tester, const HivorrLoadingState(message: 'Wait'));
      expect(find.byType(HivorrLoader), findsOneWidget);
      expect(find.text('Wait'), findsOneWidget);
    });
  });

  group('HivorrEmptyState', () {
    testWidgets('shows title, subtitle and action', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        HivorrEmptyState(
          title: 'None',
          subtitle: 'sub',
          actionButton: HivorrButton(label: 'Add', onPressed: () {}),
        ),
      );
      expect(find.text('None'), findsOneWidget);
      expect(find.text('sub'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('HivorrErrorState', () {
    testWidgets('shows message and retry', (WidgetTester tester) async {
      bool retried = false;
      await pumpTheme(
        tester,
        HivorrErrorState(message: 'Oops', onRetry: () => retried = true),
      );
      expect(find.text('Oops'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('HivorrSnackbar', () {
    testWidgets('builds a SnackBar with the message', (WidgetTester tester) async {
      late SnackBar sb;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                sb = HivorrSnackbar.show(
                  context,
                  message: 'Hi',
                  variant: HivorrSnackbarVariant.success,
                );
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      expect(sb, isA<SnackBar>());
      expect((sb.content as Text).data, 'Hi');
    });
  });
}
