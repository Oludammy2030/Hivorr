import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/providers/financial_provider.dart';
import 'package:hivorr/systems/finance/screens/financial_profile_creation_flow.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_financial_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

/// A repository whose profile creation never completes so the flow stays in its
/// loading state.
class _BlockingCreateRepo extends FakeFinancialRepository {
  _BlockingCreateRepo();
  final Completer<void> _never = Completer<void>();

  @override
  Future<FinancialProfile> createProfile({String defaultCurrency = 'NGN'}) =>
      _never.future.then((_) => throw StateError('never'));
}

void main() {
  Future<FinancialProvider> pumpFlowWith(
    WidgetTester tester, {
    FakeFinancialRepository? repo,
  }) async {
    final r = repo ?? FakeFinancialRepository();
    final FinancialProvider provider =
        FinancialProvider(service: FinancialService(repository: r));
    await pumpApp(
      tester,
      const FinancialProfileCreationFlow(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<FinancialProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  group('FinancialProfileCreationFlow', () {
    testWidgets('renders the app bar title', (WidgetTester tester) async {
      await pumpFlowWith(tester);
      await tester.pump();
      expect(find.text('Create Financial Profile'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows four currency options with symbols', (WidgetTester tester) async {
      await pumpFlowWith(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Nigerian Naira'), findsOneWidget);
      expect(find.textContaining('Ghanaian Cedi'), findsOneWidget);
      expect(find.textContaining('US Dollar'), findsOneWidget);
      expect(find.textContaining('British Pound'), findsOneWidget);
      expect(find.text('Create Profile'), findsOneWidget);
    });

    testWidgets('shows success state when profile already exists',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(defaultCurrency: 'NGN'),
      );
      final provider = await pumpFlowWith(tester, repo: repo);
      // The creation flow does not self-load; drive the provider manually.
      await provider.load();
      await tester.pumpAndSettle();

      expect(find.text('Profile created'), findsOneWidget);
      expect(find.text('View Profile'), findsOneWidget);
    });

    testWidgets('defaults the selected currency to NGN',
        (WidgetTester tester) async {
      await pumpFlowWith(tester);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    });

    testWidgets('creating with a selected currency delegates it to the repo',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository();
      await pumpFlowWith(tester, repo: repo);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.textContaining('Ghanaian Cedi'));
      await tester.tap(find.textContaining('Ghanaian Cedi'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create Profile'));
      await tester.tap(find.text('Create Profile'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The delegate was invoked with the newly selected currency.
      expect(repo.lastDefaultCurrency, 'GHS');
    });

    testWidgets('shows inline error on creation failure',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'Unsupported currency',
          code: 'PLT003',
        );
      await pumpFlowWith(tester, repo: repo);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create Profile'));
      await tester.tap(find.text('Create Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Unsupported currency'), findsOneWidget);
    });

    testWidgets('shows exactly the four supported currencies',
        (WidgetTester tester) async {
      await pumpFlowWith(tester);
      await tester.pumpAndSettle();

      expect(find.text('NGN'), findsOneWidget);
      expect(find.text('GHS'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('GBP'), findsOneWidget);
      expect(find.text('EUR'), findsNothing);
    });

    testWidgets('shows loading state while creation is in flight',
        (WidgetTester tester) async {
      await pumpFlowWith(tester, repo: _BlockingCreateRepo());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create Profile'));
      await tester.tap(find.text('Create Profile'));
      await tester.pump();

      expect(
        find.text('Creating your financial profile...'),
        findsOneWidget,
      );
      // Unmount to drop the pending never-completing future.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
