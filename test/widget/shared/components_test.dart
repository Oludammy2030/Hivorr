import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/shared/shared.dart';

import 'test_helpers.dart';

void main() {
  group('HivorrFormField', () {
    testWidgets('shows validation error on invalid input', (WidgetTester tester) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              key: formKey,
              child: HivorrFormField(
                validator: (String? v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Required'), findsNothing);
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('surfaces typed text to onChanged', (WidgetTester tester) async {
      String? value;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: HivorrFormField(onChanged: (String v) => value = v),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'hi');
      expect(value, 'hi');
    });
  });

  group('HivorrListTile', () {
    testWidgets('renders title/subtitle and taps', (WidgetTester tester) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        HivorrListTile(
          title: 'T',
          subtitle: 'S',
          onTap: () => tapped = true,
        ),
      );
      expect(find.text('T'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      await tester.tap(find.byType(HivorrListTile));
      expect(tapped, isTrue);
    });
  });

  group('HivorrSectionHeader', () {
    testWidgets('renders title and optional action', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        HivorrSectionHeader(
          title: 'Head',
          action: HivorrButton(label: 'Act', onPressed: () {}),
        ),
      );
      expect(find.text('Head'), findsOneWidget);
      expect(find.text('Act'), findsOneWidget);
    });

    testWidgets('renders without action', (WidgetTester tester) async {
      await pumpTheme(tester, const HivorrSectionHeader(title: 'Head'));
      expect(find.text('Head'), findsOneWidget);
    });
  });

  group('HivorrDialog', () {
    testWidgets('shows title, content and actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => HivorrDialog(
                    title: 'T',
                    content: const Text('C'),
                    actions: <Widget>[
                      HivorrButton(label: 'OK', onPressed: () {}),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });
  });

  group('HivorrBottomSheet', () {
    testWidgets('shows title and child', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => HivorrBottomSheet.show<void>(
                  context: context,
                  title: 'S',
                  child: const Text('child'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('S'), findsOneWidget);
      expect(find.text('child'), findsOneWidget);
    });
  });

  _formValidationTests();
}

class _Holder with FormValidationMixin {}

void _formValidationTests() {
  group('FormValidationMixin', () {
    testWidgets('validate returns false for invalid form', (WidgetTester tester) async {
      final _Holder holder = _Holder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: holder.formKey,
              child: TextFormField(validator: (_) => 'bad'),
            ),
          ),
        ),
      );
      expect(holder.validate(), isFalse);
      holder.reset();
    });

    testWidgets('validate returns true for valid form', (WidgetTester tester) async {
      final _Holder holder = _Holder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(key: holder.formKey, child: TextFormField()),
          ),
        ),
      );
      expect(holder.validate(), isTrue);
    });
  });
}
