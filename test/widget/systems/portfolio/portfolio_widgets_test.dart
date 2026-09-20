import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/entities/public_credential.dart';
import 'package:hivorr/data/entities/public_profession.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/systems/portfolio/widgets/credential_card.dart';
import 'package:hivorr/systems/portfolio/widgets/portfolio_grid.dart';
import 'package:hivorr/systems/portfolio/widgets/portfolio_item_card.dart';
import 'package:hivorr/systems/portfolio/widgets/profile_header_card.dart';
import 'package:hivorr/systems/portfolio/widgets/verification_badges_row.dart';

import '../../../support/harnesses/widget_harness.dart';

PublicProfile seedProfile({
  String displayName = 'Ada Lovelace',
  String? bio = 'Analytical engine pioneer.',
  String? countryCode = 'NG',
  List<PublicProfession>? professions,
  List<PublicCredential>? credentials,
  String? kycTierCode = 'tier_1',
  String? kycStatus = 'active',
}) => PublicProfile(
  entityId: 'entity-1',
  displayName: displayName,
  avatarPath: null,
  bio: bio,
  countryCode: countryCode,
  professions: professions ?? <PublicProfession>[seedProfession()],
  credentials: credentials ?? const <PublicCredential>[],
  kycTierCode: kycTierCode,
  kycStatus: kycStatus,
  portfolioItems: const <PortfolioItem>[],
);

PublicProfession seedProfession({
  String id = 'ep-1',
  String professionId = 'prof-1',
  bool isPrimary = true,
  String professionSlug = 'software-engineer',
  String professionName = 'Software Engineer',
  String industrySlug = 'technology',
  String industryName = 'Technology',
}) => PublicProfession(
  id: id,
  professionId: professionId,
  isPrimary: isPrimary,
  professionSlug: professionSlug,
  professionName: professionName,
  industrySlug: industrySlug,
  industryName: industryName,
);

PortfolioItem seedItem({
  String id = 'item-1',
  String? itemType = 'image',
  String? title = 'Escrow Platform',
  String? description = 'Milestone payment engine.',
  String? mediaPath = 'portfolio-items/entity-1/escrow.jpg',
  int? sortOrder = 1,
}) => PortfolioItem(
  id: id,
  itemType: itemType,
  title: title,
  description: description,
  mediaPath: mediaPath,
  sortOrder: sortOrder,
);

void main() {
  group('ProfileHeaderCard', () {
    testWidgets('renders display name, bio, country and profession badges', (
      WidgetTester tester,
    ) async {
      final PublicProfile profile = seedProfile(
        professions: <PublicProfession>[
          seedProfession(),
          seedProfession(
            id: 'ep-2',
            professionId: 'prof-2',
            isPrimary: false,
            professionSlug: 'electrician',
            professionName: 'Electrician',
            industrySlug: 'construction',
            industryName: 'Construction',
          ),
        ],
      );
      await pumpTheme(tester, ProfileHeaderCard(profile: profile));

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Analytical engine pioneer.'), findsOneWidget);
      expect(find.textContaining('NG'), findsOneWidget);
      expect(find.text('Software Engineer · Technology'), findsOneWidget);
      expect(find.text('Electrician · Construction'), findsOneWidget);
    });

    testWidgets('renders initials avatar when no avatar URL is provided', (
      WidgetTester tester,
    ) async {
      await pumpTheme(tester, ProfileHeaderCard(profile: seedProfile()));

      expect(
        find.text('AL'),
        findsOneWidget,
        reason: 'HivorrAvatar derives maximized 2-letter initials',
      );
    });

    testWidgets('omits country row and bio when absent', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        ProfileHeaderCard(profile: seedProfile(bio: null, countryCode: null)),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.byIcon(Icons.public), findsNothing);
    });

    testWidgets('renders profession name only when industry name is empty', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        ProfileHeaderCard(
          profile: seedProfile(
            professions: <PublicProfession>[seedProfession(industryName: '')],
          ),
        ),
      );

      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Software Engineer · '), findsNothing);
    });
  });

  group('VerificationBadgesRow', () {
    testWidgets('renders identity, trade and credential-count badges', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        VerificationBadgesRow(
          identityVerified: true,
          tradeVerified: true,
          credentialCount: 2,
          kycTierCode: 'tier_1',
          kycStatus: 'active',
        ),
      );

      expect(find.text('Identity Verified · TIER_1 · active'), findsOneWidget);
      expect(find.text('Trade Verified'), findsOneWidget);
      expect(find.text('2 Approved Credentials'), findsOneWidget);
    });

    testWidgets('singularizes the credential count at one', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        VerificationBadgesRow(
          identityVerified: false,
          tradeVerified: true,
          credentialCount: 1,
        ),
      );

      expect(find.text('1 Approved Credential'), findsOneWidget);
    });

    testWidgets('hides the identity badge when unverified and no KYC', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        VerificationBadgesRow(
          identityVerified: false,
          tradeVerified: true,
          credentialCount: 0,
          kycTierCode: null,
          kycStatus: null,
        ),
      );

      expect(find.textContaining('Identity'), findsNothing);
      expect(find.text('0 Approved Credentials'), findsOneWidget);
    });
  });

  group('CredentialCard', () {
    testWidgets('renders title, kind chip and approved badge', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const CredentialCard(
          credential: PublicCredential(
            kind: 'identity_document',
            title: 'National ID',
            verificationStatus: 'approved',
          ),
        ),
      );

      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('maps certification kind to a friendly label', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const CredentialCard(
          credential: PublicCredential(
            kind: 'certification',
            title: 'AWS Certified',
            verificationStatus: 'approved',
          ),
        ),
      );

      expect(find.text('AWS Certified'), findsOneWidget);
      expect(find.text('Certification'), findsOneWidget);
    });
  });

  group('PortfolioItemCard', () {
    testWidgets('renders title, description, type chip and image placeholder', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        PortfolioItemCard(
          item: seedItem(
            itemType: 'image',
            title: 'Kitchen Renovation',
            description: 'Full remodel of a 3-bedroom home.',
          ),
          mediaUrl: null,
        ),
      );

      expect(find.text('Kitchen Renovation'), findsOneWidget);
      expect(find.text('Full remodel of a 3-bedroom home.'), findsOneWidget);
      expect(find.text('image'), findsOneWidget);
      expect(
        find.byIcon(Icons.image_outlined),
        findsOneWidget,
        reason: 'missing media renders the neutral type placeholder',
      );
    });

    testWidgets('returns a permalink icon for link items', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        PortfolioItemCard(item: seedItem(itemType: 'link')),
      );

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('omits empty title/description/chips', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        PortfolioItemCard(
          item: seedItem(title: '', description: '  ', itemType: ''),
        ),
      );

      expect(find.text('Escrow Platform'), findsNothing);
    });
  });

  group('PortfolioGrid', () {
    testWidgets('renders nothing when the list is empty', (
      WidgetTester tester,
    ) async {
      await pumpTheme(tester, const PortfolioGrid(items: <PortfolioItem>[]));

      expect(find.byType(PortfolioItemCard), findsNothing);
    });

    testWidgets('sorts items by sort_order with nulls last', (
      WidgetTester tester,
    ) async {
      final List<PortfolioItem> items = <PortfolioItem>[
        seedItem(id: 'c', title: 'C', sortOrder: 3),
        seedItem(id: 'b', title: 'B', sortOrder: null),
        seedItem(id: 'a', title: 'A', sortOrder: 1),
      ];
      await pumpScreen(
        tester,
        Center(
          child: SingleChildScrollView(child: PortfolioGrid(items: items)),
        ),
        width: 390,
      );
      await tester.pump();

      final double aY = tester.getTopLeft(find.text('A')).dy;
      final double cY = tester.getTopLeft(find.text('C')).dy;
      final double bY = tester.getTopLeft(find.text('B')).dy;

      expect(aY, lessThan(cY), reason: 'sort_order 1 renders before 3');
      expect(cY, lessThan(bY), reason: 'null sort_order renders last');
    });

    testWidgets('lays out a single column on mobile width', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        SingleChildScrollView(
          child: PortfolioGrid(
            items: <PortfolioItem>[
              seedItem(id: 'a'),
              seedItem(id: 'b'),
              seedItem(id: 'c'),
            ],
          ),
        ),
        width: 390,
      );
      await tester.pump();

      final double firstWidth = tester
          .getSize(find.byType(PortfolioItemCard).first)
          .width;
      expect(firstWidth, closeTo(390, 1));
    });

    testWidgets('lays out two columns on tablet width', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        SingleChildScrollView(
          child: PortfolioGrid(
            items: <PortfolioItem>[
              seedItem(id: 'a'),
              seedItem(id: 'b'),
              seedItem(id: 'c'),
            ],
          ),
        ),
        width: 800,
      );
      await tester.pump();

      final double aWidth = tester
          .getSize(find.byType(PortfolioItemCard).at(0))
          .width;
      final double bWidth = tester
          .getSize(find.byType(PortfolioItemCard).at(1))
          .width;
      expect(aWidth, closeTo((800 - 16) / 2, 1));
      expect(bWidth, closeTo((800 - 16) / 2, 1));
    });

    testWidgets('lays out three columns on desktop width', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        SingleChildScrollView(
          child: PortfolioGrid(
            items: <PortfolioItem>[
              seedItem(id: 'a'),
              seedItem(id: 'b'),
              seedItem(id: 'c'),
            ],
          ),
        ),
        width: 1200,
      );
      await tester.pump();

      final double aWidth = tester
          .getSize(find.byType(PortfolioItemCard).at(0))
          .width;
      expect(aWidth, closeTo((1200 - 32) / 3, 1));
    });
  });
}
