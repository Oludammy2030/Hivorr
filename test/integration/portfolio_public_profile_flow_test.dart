// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/providers/portfolio_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';
import 'package:hivorr/systems/portfolio/widgets/credential_card.dart';
import 'package:hivorr/systems/portfolio/widgets/portfolio_item_card.dart';
import 'package:hivorr/systems/portfolio/widgets/profile_header_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../support/portfolio/portfolio_test_support.dart';

/// Fake-E2E integration for EP-02-19 (DoD TT-10).
///
/// Exercises the real `/p/:slug/:id` route against a scripted fake data source,
/// driving the whole data → service → provider → screen stack:
///  - Flow 1: signed-out visitor opens `/p/:slug/:id`, the profile loads, and
///    the header + verification badges + credentials + portfolio grid render
///    with the authoritative entity id reaching the data source.
///  - Flow 2: a `PLT004` not-found response renders the SEO-404 empty state
///    (no leak of the queried id).
///  - Flow 3: a network/server failure renders a retry state, and tapping
///    Retry re-issues the load and recovers to the loaded profile.
void main() {
  Future<void> pumpProfile(
    WidgetTester tester,
    PortfolioProvider provider,
    ProfessionalProfileService service,
  ) async {
    await pumpPortfolioScreen(tester, <SingleChildWidget>[
      ChangeNotifierProvider<PortfolioProvider>.value(value: provider),
      Provider<ProfessionalProfileService>.value(value: service),
    ], '/p/software-engineer/entity-1');
    await tester.pump();
    await tester.pump();
  }

  group('EP-02-19 public profile flow', () {
    testWidgets(
      'Flow 1: signed-out visitor loads the full profile over the route',
      (WidgetTester tester) async {
        final stack = buildPortfolioStack();
        addTearDown(stack.provider.dispose);

        await pumpProfile(tester, stack.provider, stack.service);

        // The authoritative entity id reached the data source exactly once.
        expect(stack.remote.lastEntityId, 'entity-1');
        expect(stack.remote.callCount, 1);

        // Signed-out load resolves to the full content tree.
        expect(find.byType(HivorrLoadingState), findsNothing);
        expect(find.byType(HivorrEmptyState), findsNothing);
        expect(find.byType(ProfileHeaderCard), findsOneWidget);
        expect(find.text('Ada Lovelace'), findsOneWidget);
        expect(
          find.text('Identity Verified · TIER_1 · active'),
          findsOneWidget,
        );
        expect(find.text('Trade Verified'), findsOneWidget);
        expect(find.text('2 Approved Credentials'), findsOneWidget);
        expect(find.byType(CredentialCard), findsNWidgets(2));

        // Portfolio grid sits below the fold in the lazy ListView.
        await tester.scrollUntilVisible(find.text('Portfolio'), 200);
        expect(find.byType(PortfolioItemCard), findsNWidgets(2));
        expect(find.text('Portfolio'), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 2: PLT004 serves the null profile and the SEO-404 empty state',
      (WidgetTester tester) async {
        final stack = buildPortfolioStack(
          error: const ApiException(
            kind: ApiExceptionKind.notFound,
            message: 'not found',
            code: 'PLT004',
          ),
        );
        addTearDown(stack.provider.dispose);

        await pumpProfile(tester, stack.provider, stack.service);

        expect(stack.remote.lastEntityId, 'entity-1');
        expect(find.byType(HivorrEmptyState), findsOneWidget);
        expect(find.text('Profile not found'), findsOneWidget);
        expect(
          find.textContaining('could not be found or is not currently public'),
          findsOneWidget,
        );
        expect(find.byType(HivorrErrorState), findsNothing);
        expect(
          find.text('Ada Lovelace'),
          findsNothing,
          reason: 'no display-name leak on the not-found state',
        );
      },
    );

    testWidgets('Flow 3: network failure renders a retry state that recovers', (
      WidgetTester tester,
    ) async {
      final stack = buildPortfolioStack(
        error: const ApiException(
          kind: ApiExceptionKind.network,
          message: 'offline',
          code: 'PLT005',
        ),
      );
      addTearDown(stack.provider.dispose);

      await pumpProfile(tester, stack.provider, stack.service);

      // Failure state with a retry action.
      expect(stack.remote.callCount, 1);
      expect(find.byType(HivorrErrorState), findsOneWidget);
      expect(
        find.text('Unable to load this profile. Please check your connection.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
      expect(find.byType(PortfolioItemCard), findsNothing);

      // Succeed on the retry.
      stack.remote.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(stack.remote.callCount, 2);
      expect(stack.remote.lastEntityId, 'entity-1');
      expect(find.byType(HivorrErrorState), findsNothing);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.byType(CredentialCard), findsNWidgets(2));

      // Portfolio grid sits below the fold in the lazy ListView.
      await tester.scrollUntilVisible(find.text('Portfolio'), 200);
      expect(find.byType(PortfolioItemCard), findsNWidgets(2));
    });
  });
}
