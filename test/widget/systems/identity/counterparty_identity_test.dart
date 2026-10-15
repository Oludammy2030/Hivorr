import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/systems/identity/widgets/counterparty_identity.dart';

import '../../../support/harnesses/widget_harness.dart';

void main() {
  Future<void> pumpIdentity(
    WidgetTester tester,
    CounterpartyIdentity identity,
  ) {
    return pumpApp(
      tester,
      Scaffold(body: identity),
    );
  }

  group('CounterpartyIdentity', () {
    testWidgets('shows fallback while loading, then the resolved face', (
      WidgetTester tester,
    ) async {
      final Completer<CounterpartyFace?> gate = Completer<CounterpartyFace?>();
      await pumpIdentity(
        tester,
        CounterpartyIdentity(
          fallbackLabel: 'Professional',
          load: () => gate.future,
        ),
      );
      await tester.pump();
      expect(find.text('Professional'), findsOneWidget);

      gate.complete(const CounterpartyFace(name: 'Adaeze Fixes It'));
      await tester.pumpAndSettle();
      expect(find.text('Adaeze Fixes It'), findsOneWidget);
      expect(find.text('Professional'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back on error', (tester) async {
      await pumpIdentity(
        tester,
        CounterpartyIdentity(
          fallbackLabel: 'Client',
          load: () => Future<CounterpartyFace?>.error(StateError('denied')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Client'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back on null with caption otherwise', (tester) async {
      await pumpIdentity(
        tester,
        CounterpartyIdentity(
          fallbackLabel: 'Professional',
          load: () async => null,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Professional'), findsOneWidget);
    });

    testWidgets('renders caption when resolved', (tester) async {
      await pumpIdentity(
        tester,
        const CounterpartyIdentity(
          fallbackLabel: 'Client',
          load: _businessFace,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amara Foods'), findsOneWidget);
      expect(find.text('Hiring as a business'), findsOneWidget);
    });

    testWidgets('uses the brand theme without exceptions', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: CounterpartyIdentity(
            fallbackLabel: 'Professional',
            load: _neverFace,
          ),
        ),
        dark: false,
      );
      await tester.pumpAndSettle();
      expect(AppTheme.lightTheme.colorScheme.primary, const Color(0xFF2D3FE7));
      expect(tester.takeException(), isNull);
    });
  });
}

Future<CounterpartyFace?> _businessFace() async =>
    const CounterpartyFace(
      name: 'Amara Foods',
      caption: 'Hiring as a business',
    );

Future<CounterpartyFace?> _neverFace() async => null;
