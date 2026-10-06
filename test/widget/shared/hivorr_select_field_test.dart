import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/shared/components/hivorr_bottom_sheet.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/components/hivorr_select_field.dart';

import '../../support/harnesses/widget_harness.dart';

/// Option rows in the select surfaces carry stable keys.
Finder selectOption(String label) =>
    find.byKey(ValueKey<String>('hivorr-select-option-$label'));

const List<SelectOption<String>> colors = <SelectOption<String>>[
  SelectOption<String>(value: 'r', label: 'Red'),
  SelectOption<String>(value: 'g', label: 'Green'),
  SelectOption<String>(value: 'b', label: 'Blue'),
];

List<SelectOption<String>> manyOptions() => <SelectOption<String>>[
  for (int i = 0; i < 12; i++)
    SelectOption<String>(value: 'v$i', label: 'Option $i'),
];

void main() {
  group('HivorrSelectField', () {
    testWidgets('trigger opens the option surface and reports the pick', (
      WidgetTester tester,
    ) async {
      String? picked = 'sentinel';
      await pumpApp(
        tester,
        HivorrSelectField<String>(
          label: 'Color',
          hint: 'Select color',
          options: colors,
          selected: null,
          onSelected: (String? value) => picked = value,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select color'), findsOneWidget);
      await tester.tap(find.text('Select color'));
      await tester.pumpAndSettle();

      // 800px default viewport → desktop dialog branch.
      expect(find.byType(HivorrDialog), findsOneWidget);
      expect(selectOption('Green'), findsOneWidget);
      await tester.tap(selectOption('Green'));
      await tester.pumpAndSettle();

      expect(picked, 'g');
      expect(find.byType(HivorrDialog), findsNothing);
    });

    testWidgets('selected value renders in the trigger', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        HivorrSelectField<String>(
          label: 'Color',
          hint: 'Select color',
          options: colors,
          selected: 'b',
          onSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Select color'), findsNothing);
    });

    testWidgets('disabled trigger does not open', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        HivorrSelectField<String>(
          label: 'Profession',
          hint: 'Select industry first',
          helperText: 'Choose an industry first.',
          enabled: false,
          options: colors,
          selected: null,
          onSelected: (_) => fail('must not fire while disabled'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select industry first'));
      await tester.pumpAndSettle();
      expect(find.byType(HivorrDialog), findsNothing);
      expect(find.byType(HivorrBottomSheet), findsNothing);
    });

    testWidgets('mobile trigger opens a bottom sheet', (
      WidgetTester tester,
    ) async {
      String? picked;
      await pumpScreen(
        tester,
        HivorrSelectField<String>(
          label: 'Color',
          hint: 'Select color',
          options: colors,
          selected: null,
          onSelected: (String? value) => picked = value,
        ),
        width: 390,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select color'));
      await tester.pumpAndSettle();

      expect(find.byType(HivorrBottomSheet), findsOneWidget);
      await tester.tap(selectOption('Red'));
      await tester.pumpAndSettle();

      expect(picked, 'r');
      expect(find.byType(HivorrBottomSheet), findsNothing);
    });
  });

  group('HivorrSelectField.showOptions', () {
    Future<SelectResult<String>?> show(
      WidgetTester tester,
      BuildContext context, {
      List<SelectOption<String>> options = colors,
      String? clearLabel,
    }) {
      return HivorrSelectField.showOptions<String>(
        context: context,
        title: 'Color',
        options: options,
        selected: null,
        clearLabel: clearLabel,
      );
    }

    testWidgets('clear row reports an explicit reset', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const SizedBox.shrink());
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.byType(SizedBox));

      SelectResult<String>? result;
      unawaited(show(tester, context, clearLabel: 'Any color').then(
        (SelectResult<String>? value) => result = value,
      ));
      await tester.pumpAndSettle();

      await tester.tap(selectOption('Any color'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.value, isNull);
    });

    testWidgets('barrier dismissal returns null (state untouched)', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const SizedBox.shrink());
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.byType(SizedBox));

      SelectResult<String>? result = const SelectResult<String>('sentinel');
      unawaited(show(tester, context).then(
        (SelectResult<String>? value) => result = value,
      ));
      await tester.pumpAndSettle();
      expect(selectOption('Green'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('long lists become searchable, short lists stay plain', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const SizedBox.shrink());
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.byType(SizedBox));

      // Short list: no search field.
      unawaited(show(tester, context));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Search…'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Long list: searchable, filters as you type.
      unawaited(show(tester, context, options: manyOptions()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Search…'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search…'),
        'Option 1',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(selectOption('Option 1'), findsOneWidget);
      expect(selectOption('Option 2'), findsNothing);

      SelectResult<String>? result;
      // Re-open to capture the pick cleanly.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      unawaited(show(tester, context, options: manyOptions()).then(
        (SelectResult<String>? value) => result = value,
      ));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search…'),
        'Option 11',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(selectOption('Option 11'));
      await tester.pumpAndSettle();
      expect(result?.value, 'v11');
    });
  });
}
