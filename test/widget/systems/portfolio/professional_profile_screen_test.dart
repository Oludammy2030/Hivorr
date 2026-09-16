import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/models/portfolio_item_dto.dart';
import 'package:hivorr/data/models/public_credential_dto.dart';
import 'package:hivorr/data/models/public_profession_dto.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/portfolio/screens/professional_profile_screen.dart';
import 'package:hivorr/systems/portfolio/widgets/credential_card.dart';
import 'package:hivorr/systems/portfolio/widgets/portfolio_item_card.dart';
import 'package:hivorr/systems/portfolio/widgets/profile_header_card.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes/fake_portfolio.dart';
import '../../../support/portfolio/portfolio_test_support.dart';

void main() {
  String path({String slug = 'software-engineer', String id = 'entity-1'}) =>
      '/p/$slug/$id';

  group('ProfessionalProfileScreen', () {
    testWidgets('renders the branded loading state while fetching',
        (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      final stack = buildPortfolioStack(gate: gate);
      addTearDown(stack.provider.dispose);

      await pumpPortfolioScreen(tester, stack.buildProviders(), path());
      await tester.pump();

      expect(find.byType(HivorrLoadingState), findsOneWidget);
      expect(find.text('Loading profile…'), findsOneWidget);

      gate.complete();
      await tester.pump();
      await tester.pump();
    });

    testWidgets('renders header, badges, credentials and portfolio when loaded',
        (WidgetTester tester) async {
      final stack = buildPortfolioStack();
      addTearDown(stack.provider.dispose);

      await pumpPortfolioScreen(tester, stack.buildProviders(), path());
      await tester.pump();
      await tester.pump();

      // Header
      expect(find.byType(ProfileHeaderCard), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Analytical engine pioneer.'), findsOneWidget);
      expect(find.text('Software Engineer · Technology'), findsOneWidget);
      expect(find.textContaining('NG'), findsWidgets,
          reason: 'country chip renders');

      // Badges row
      expect(find.text('Identity Verified · TIER_1 · active'), findsOneWidget);
      expect(find.text('Trade Verified'), findsOneWidget);
      expect(find.text('2 Approved Credentials'), findsOneWidget);

      // Credentials section
      expect(find.text('Credentials'), findsOneWidget);
      expect(find.byType(CredentialCard), findsNWidgets(2));
      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('AWS Solutions Architect'), findsOneWidget);

      // Portfolio section (below the fold in the default 800x600 test surface —
      // scroll the lazy ListView so the trailing rows are built).
      await tester.scrollUntilVisible(find.text('Lakehouse Migration'), 200);

      expect(find.text('Portfolio'), findsOneWidget);
      expect(find.byType(PortfolioItemCard), findsNWidgets(2));
      expect(find.text('Escrow Platform'), findsOneWidget);
      expect(find.text('Lakehouse Migration'), findsOneWidget);
    });

    testWidgets('renders the not-found empty state when server returns PLT004',
        (WidgetTester tester) async {
      final stack = buildPortfolioStack(
        error: const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'not found',
          code: 'PLT004',
        ),
      );
      addTearDown(stack.provider.dispose);

      await pumpPortfolioScreen(tester, stack.buildProviders(), path());
      await tester.pump();
      await tester.pump();

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('Profile not found'), findsOneWidget);
      expect(
        find.textContaining('could not be found or is not currently public'),
        findsOneWidget,
      );
    });

    testWidgets('shows a retry state on network failure and recover on retry',
        (WidgetTester tester) async {
      final stack = buildPortfolioStack(
        error: const ApiException(
          kind: ApiExceptionKind.network,
          message: 'offline',
          code: 'PLT005',
        ),
      );
      addTearDown(stack.provider.dispose);

      await pumpPortfolioScreen(tester, stack.buildProviders(), path());
      await tester.pump();
      await tester.pump();

      expect(find.byType(HivorrErrorState), findsOneWidget);
      expect(
        find.text('Unable to load this profile. Please check your connection.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      // Recovery: clear the error and retry.
      stack.remote.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(stack.remote.callCount, 2);
    });

    testWidgets('guards the empty id and shows not-found without an RPC call',
        (WidgetTester tester) async {
      final stack = buildPortfolioStack();
      addTearDown(stack.provider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: stack.buildProviders(),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            home: const ProfessionalProfileScreen(
              profileId: '',
              routeSlug: 'software-engineer',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('Profile not found'), findsOneWidget);
      expect(stack.remote.callCount, 0,
          reason: 'FV-32: an empty id never issues an RPC');
    });

    testWidgets('renders cleanly with no credentials, no portfolio and no bio',
        (WidgetTester tester) async {
      final stack = buildPortfolioStack(
        result: seedPublicProfileDto(
          bio: null,
          countryCode: null,
          professions: <PublicProfessionDto>[
            seedPublicProfessionDto(),
          ],
          credentials: <PublicCredentialDto>[],
          portfolioItems: <PortfolioItemDto>[],
          kycTierCode: null,
          kycStatus: null,
        ),
      );
      addTearDown(stack.provider.dispose);

      await pumpPortfolioScreen(tester, stack.buildProviders(), path());
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProfileHeaderCard), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Credentials'), findsNothing);
      expect(find.text('Portfolio'), findsNothing);
      expect(find.byType(CredentialCard), findsNothing);
      expect(find.byType(PortfolioItemCard), findsNothing);
      expect(find.text('0 Approved Credentials'), findsOneWidget);
      expect(find.text('Trade Verified'), findsOneWidget);
      expect(find.textContaining('Identity Verified'), findsNothing,
          reason: 'no identity credential and no KYC tier → identity badge hidden');
    });

    testWidgets('renders the generic app bar title (no display-name leak)',
        (WidgetTester tester) async {
      final stack = buildPortfolioStack();
      addTearDown(stack.provider.dispose);

      await pumpPortfolioScreen(tester, stack.buildProviders(), path());
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Profile'),
        ),
        findsOneWidget,
        reason: 'route title stays generic; the display name renders in the '
            'header card only',
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Ada Lovelace'),
        ),
        findsNothing,
      );
    });
  });
}