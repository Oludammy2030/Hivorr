import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/providers/conversion_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/screens/conversion_screen.dart';
import 'package:hivorr/systems/finance/services/conversion_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_conversion_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

/// Widget coverage for [ConversionScreen] (EP-02-15 §5.8, DoD ≥8 scenarios):
/// the flag-gated empty state, pair/amount entry, trusted rate card states
/// (loaded / loading / unavailable), zero-RPC estimate flow, execution result,
/// failure+retry, and the history list.
void main() {
  const WalletConversionPairsConfig enabledPairs = WalletConversionPairsConfig(
    enabled: true,
    baseCrossRates: <String, double>{
      'NGN|USD': 0.0007,
    },
  );

  ConversionProvider providerWith(
    FakeConversionRepository repo, {
    WalletConversionPairsConfig pairsConfig = enabledPairs,
  }) =>
      ConversionProvider(
        service: ConversionService(
          repository: repo,
          pairsConfig: pairsConfig,
        ),
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    ConversionProvider provider,
  ) async {
    await pumpApp(
      tester,
      const ConversionScreen(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ConversionProvider>.value(value: provider),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// Taps [from] in the From chip group and [to] in the To chip group.
  Future<void> selectPair(
    WidgetTester tester, {
    required String from,
    required String to,
  }) async {
    await tester.tap(find.widgetWithText(HivorrChip, from).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HivorrChip, to).last);
    await tester.pumpAndSettle();
  }

  FakeConversionRepository seededRepo() => FakeConversionRepository()
    ..setRate('NGN', 'USD', 0.0007);

  group('ConversionScreen', () {
    testWidgets('renders the Convert app bar title and the history header',
        (WidgetTester tester) async {
      final provider = providerWith(seededRepo());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);

      expect(find.widgetWithText(AppBar, 'Convert'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('shows the empty state while conversion is flag-gated off',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeConversionRepository(),
        pairsConfig: const WalletConversionPairsConfig(),
      );
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('Currency conversion unavailable'), findsOneWidget);
      expect(find.text('Convert now'), findsNothing);
    });

    testWidgets('selecting a pair reveals the trusted directed + inverse rate',
        (WidgetTester tester) async {
      final provider = providerWith(seededRepo());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      expect(find.text('Select a pair and an amount to see today\u2019s rate.'),
          findsOneWidget);

      await selectPair(tester, from: 'NGN', to: 'USD');

      expect(find.text('1 NGN = 0.0007 USD'), findsOneWidget);
      expect(find.text('Platform rate'), findsOneWidget);
    });

    testWidgets('amount entry prefixes the source currency symbol and label',
        (WidgetTester tester) async {
      final provider = providerWith(seededRepo());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await selectPair(tester, from: 'NGN', to: 'USD');

      expect(find.text('Amount (NGN)'), findsOneWidget);
      expect(find.text('\u20A6'), findsOneWidget);
    });

    testWidgets('shows the rate loading state while a rate fetch is in flight',
        (WidgetTester tester) async {
      final provider = providerWith(_HangingConversionRepository());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await tester.tap(find.widgetWithText(HivorrChip, 'NGN').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(HivorrChip, 'USD').last);
      await tester.pump();

      expect(find.byType(HivorrLoadingState), findsOneWidget);
      expect(find.text('Fetching rate...'), findsOneWidget);
    });

    testWidgets('shows the unavailable state when the pair has no configured '
        'rate', (WidgetTester tester) async {
      final provider = providerWith(FakeConversionRepository());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await selectPair(tester, from: 'NGN', to: 'USD');

      expect(find.text('Rate unavailable for this pair'), findsOneWidget);
    });

    testWidgets('a self-pair tap swaps safely without crashing and resolves',
        (WidgetTester tester) async {
      final provider = providerWith(seededRepo());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await tester.tap(find.widgetWithText(HivorrChip, 'NGN').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(HivorrChip, 'NGN').last);
      await tester.pumpAndSettle();

      // The temporary self-pair shows the placeholder rate card, then the
      // choice lands on a valid pair without throwing.
      expect(find.text('Select a pair and an amount to see today\u2019s rate.'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(HivorrChip, 'USD').last);
      await tester.pumpAndSettle();

      expect(find.text('1 NGN = 0.0007 USD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('See estimate computes the local zero-RPC estimate and the '
        'Convert now CTA', (WidgetTester tester) async {
      final provider = providerWith(seededRepo());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await selectPair(tester, from: 'NGN', to: 'USD');
      await tester.enterText(find.byType(TextField), '50000');
      await tester.pump();

      expect(find.text('See estimate'), findsOneWidget);
      await tester.tap(find.text('See estimate'));
      await tester.pumpAndSettle();

      expect(find.text('You give'), findsOneWidget);
      expect(find.text('You receive'), findsOneWidget);
      expect(find.text('\u20A650,000.00'), findsOneWidget);
      expect(find.text('\$35.00'), findsOneWidget);
      expect(find.text('Convert now'), findsOneWidget);
    });

    testWidgets('executing a conversion renders the completion result card',
        (WidgetTester tester) async {
      final repo = seededRepo()
        ..setConversion(seedConversionEntity(id: 'conversion-abc'));
      final provider = providerWith(repo);
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await selectPair(tester, from: 'NGN', to: 'USD');
      await tester.enterText(find.byType(TextField), '50000');
      await tester.pump();
      await tester.tap(find.text('See estimate'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Convert now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convert now'));
      await tester.pumpAndSettle();

      expect(find.text('Conversion complete'), findsOneWidget);
      expect(find.text('Reference: conversion-abc'), findsOneWidget);
      expect(find.text('View history'), findsOneWidget);
      expect(repo.executeCallCount, 1);
    });

    testWidgets('a failed estimate surfaces the inline error with retry',
        (WidgetTester tester) async {
      final repo = seededRepo()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'Insufficient source balance.',
          code: 'PLT006',
        );
      final provider = providerWith(repo);
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await selectPair(tester, from: 'NGN', to: 'USD');
      await tester.enterText(find.byType(TextField), '50000');
      await tester.pump();
      await tester.tap(find.text('See estimate'));
      await tester.pumpAndSettle();

      expect(find.text('Conversion not completed'), findsOneWidget);
      expect(find.text('Insufficient source balance.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry after a failed estimate recomputes the estimate',
        (WidgetTester tester) async {
      final repo = seededRepo()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'estimate down',
          code: 'PLT999',
        );
      final provider = providerWith(repo);
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await selectPair(tester, from: 'NGN', to: 'USD');
      await tester.enterText(find.byType(TextField), '50000');
      await tester.pump();
      await tester.tap(find.text('See estimate'));
      await tester.pumpAndSettle();
      expect(find.text('Conversion not completed'), findsOneWidget);

      repo.nextError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Conversion not completed'), findsNothing);
      expect(find.text('You receive'), findsOneWidget);
    });

    testWidgets('renders history tiles with status chips',
        (WidgetTester tester) async {
      final repo = FakeConversionRepository(
        history: <CurrencyConversion>[
          seedConversionEntity(id: 'c-1'),
          seedConversionEntity(
            id: 'c-2',
            fromCurrency: 'USD',
            toCurrency: 'GHS',
            fromAmount: 10,
            toAmount: 12.5,
          ),
        ],
      );
      final provider = providerWith(repo);
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);

      expect(find.text('\u20A650,000.00 \u2192 \$35.00'), findsOneWidget);
      expect(find.text('Completed'), findsNWidgets(2));
    });

    testWidgets('shows the empty history state when there are no conversions',
        (WidgetTester tester) async {
      final provider = providerWith(FakeConversionRepository());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);

      expect(find.text('No conversions yet'), findsOneWidget);
    });

    testWidgets('reloads history on pull-to-refresh',
        (WidgetTester tester) async {
      final repo = FakeConversionRepository(
        history: <CurrencyConversion>[seedConversionEntity()],
      );
      final provider = providerWith(repo);
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      final int initial = repo.historyCallCount;

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(repo.historyCallCount, greaterThan(initial));
    });

    testWidgets('reloads history when the app resumes from background',
        (WidgetTester tester) async {
      final repo = FakeConversionRepository(
        history: <CurrencyConversion>[seedConversionEntity()],
      );
      final provider = providerWith(repo);
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      final int initial = repo.historyCallCount;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repo.historyCallCount, greaterThan(initial));
    });

    testWidgets('uses AppTheme tokens for the preview, spacing, and card radius '
        '(TT-09)', (WidgetTester tester) async {
      final provider = providerWith(seededRepo());
      addTearDown(provider.dispose);

      await pumpScreen(tester, provider);
      await selectPair(tester, from: 'NGN', to: 'USD');
      await tester.enterText(find.byType(TextField), '50000');
      await tester.pump();
      await tester.tap(find.text('See estimate'));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(ConversionScreen));
      final AppThemeExtension ext = context.appExtension;

      // Net emphasized via textTheme.titleMedium + colorScheme.primary.
      final Text netText = tester.widget<Text>(find.text('\$35.00'));
      expect(
        netText.style?.fontSize,
        Theme.of(context).textTheme.titleMedium?.fontSize,
      );
      expect(netText.style?.color, Theme.of(context).colorScheme.primary);

      // Cards carry the AppTheme radiusMd (16dp) surface.
      final Iterable<Container> cardContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(HivorrCard),
          matching: find.byType(Container),
        ),
      );
      expect(
        cardContainers.any(
          (Container c) =>
              (c.decoration as BoxDecoration).borderRadius ==
              BorderRadius.circular(ext.radiusMd),
        ),
        isTrue,
      );
    });
  });
}

/// Repository whose rate fetch never completes — drives the loading state.
class _HangingConversionRepository extends FakeConversionRepository {
  @override
  Future<double> getRate({
    required String fromCurrency,
    required String toCurrency,
  }) =>
      Completer<double>().future;
}