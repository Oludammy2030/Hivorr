import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/entities/public_credential.dart';
import 'package:hivorr/data/entities/public_profession.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/mappers/portfolio_mappers.dart';
import 'package:hivorr/data/models/portfolio_item_dto.dart';
import 'package:hivorr/data/models/public_credential_dto.dart';
import 'package:hivorr/data/models/public_profession_dto.dart';
import 'package:hivorr/data/models/public_profile_dto.dart';

import '../../support/fakes/fake_portfolio.dart';

void main() {
  group('PortfolioMappers.toPublicProfile', () {
    test('maps all entity-level fields', () {
      final PublicProfileDto dto = seedPublicProfileDto(
        entityId: 'ent-1',
        displayName: 'Grace Hopper',
        bio: 'Computing pioneer.',
        countryCode: 'US',
        kycTierCode: 'tier_2',
        kycStatus: 'active',
        professionSlug: 'computer-scientist',
        professionName: 'Computer Scientist',
        industrySlug: 'technology',
        industryName: 'Technology',
      );

      final PublicProfile profile = PortfolioMappers.toPublicProfile(dto);

      expect(profile.entityId, 'ent-1');
      expect(profile.displayName, 'Grace Hopper');
      expect(profile.bio, 'Computing pioneer.');
      expect(profile.countryCode, 'US');
      expect(profile.kycTierCode, 'tier_2');
      expect(profile.kycStatus, 'active');
      expect(profile.professionSlug, 'computer-scientist');
      expect(profile.professionName, 'Computer Scientist');
      expect(profile.industrySlug, 'technology');
      expect(profile.industryName, 'Technology');
    });

    test('maps professions sub-list', () {
      final PublicProfileDto dto = seedPublicProfileDto(
        professions: <PublicProfessionDto>[
          seedPublicProfessionDto(
            id: 'ep-1',
            professionId: 'p-1',
            isPrimary: true,
            professionSlug: 'plumber',
            professionName: 'Plumber',
            industrySlug: 'construction',
            industryName: 'Construction',
          ),
          seedPublicProfessionDto(
            id: 'ep-2',
            professionId: 'p-2',
            isPrimary: false,
            professionSlug: 'electrician',
            professionName: 'Electrician',
            industrySlug: 'construction',
            industryName: 'Construction',
          ),
        ],
      );

      final PublicProfile profile = PortfolioMappers.toPublicProfile(dto);

      expect(profile.professions, hasLength(2));
      expect(profile.professions[0].id, 'ep-1');
      expect(profile.professions[0].professionSlug, 'plumber');
      expect(profile.professions[1].isPrimary, isFalse);
    });

    test('maps credentials sub-list', () {
      final PublicProfileDto dto = seedPublicProfileDto(
        credentials: <PublicCredentialDto>[
          seedPublicCredentialDto(
            kind: 'identity_document',
            title: 'National ID',
            verificationStatus: 'approved',
          ),
        ],
      );

      final PublicProfile profile = PortfolioMappers.toPublicProfile(dto);

      expect(profile.credentials, hasLength(1));
      expect(profile.credentials[0].kind, 'identity_document');
      expect(profile.credentials[0].title, 'National ID');
      expect(profile.credentials[0].verificationStatus, 'approved');
    });

    test('maps portfolio items sub-list', () {
      final PublicProfileDto dto = seedPublicProfileDto(
        portfolioItems: <PortfolioItemDto>[
          seedPortfolioItemDto(
            id: 'item-1',
            itemType: 'video',
            title: 'Demo Reel',
            description: 'Showreel of recent work.',
            mediaPath: 'portfolio-items/ent-1/reel.mp4',
            sortOrder: 3,
          ),
        ],
      );

      final PublicProfile profile = PortfolioMappers.toPublicProfile(dto);

      expect(profile.portfolioItems, hasLength(1));
      expect(profile.portfolioItems[0].id, 'item-1');
      expect(profile.portfolioItems[0].itemType, 'video');
      expect(profile.portfolioItems[0].title, 'Demo Reel');
      expect(profile.portfolioItems[0].mediaPath, 'portfolio-items/ent-1/reel.mp4');
      expect(profile.portfolioItems[0].sortOrder, 3);
    });

    test('null optional fields map through as null', () {
      final PublicProfileDto dto = seedPublicProfileDto(
        avatarPath: null,
        bio: null,
        countryCode: null,
        kycTierCode: null,
        kycStatus: null,
        professionSlug: null,
        professionName: null,
        industrySlug: null,
        industryName: null,
        professions: <PublicProfessionDto>[],
        credentials: <PublicCredentialDto>[],
        portfolioItems: <PortfolioItemDto>[],
      );

      final PublicProfile profile = PortfolioMappers.toPublicProfile(dto);

      expect(profile.avatarPath, isNull);
      expect(profile.bio, isNull);
      expect(profile.countryCode, isNull);
      expect(profile.kycTierCode, isNull);
      expect(profile.kycStatus, isNull);
      expect(profile.professionSlug, isNull);
      expect(profile.professionName, isNull);
      expect(profile.professions, isEmpty);
      expect(profile.credentials, isEmpty);
      expect(profile.portfolioItems, isEmpty);
    });

    test('defaults sub-lists to empty when lists are absent from DTO', () {
      final PublicProfileDto dto = PublicProfileDto(
        entityId: 'e1',
        displayName: 'Empty List Test',
      );
      final PublicProfile profile = PortfolioMappers.toPublicProfile(dto);

      expect(profile.professions, isEmpty);
      expect(profile.credentials, isEmpty);
      expect(profile.portfolioItems, isEmpty);
    });
  });

  group('PortfolioMappers.toPublicProfession', () {
    test('maps all profession fields', () {
      final PublicProfessionDto dto = seedPublicProfessionDto(
        id: 'ep-1',
        professionId: 'prof-1',
        isPrimary: true,
        professionSlug: 'welder',
        professionName: 'Welder',
        industrySlug: 'manufacturing',
        industryName: 'Manufacturing',
      );

      final PublicProfession profession = PortfolioMappers.toPublicProfession(dto);

      expect(profession.id, 'ep-1');
      expect(profession.professionId, 'prof-1');
      expect(profession.isPrimary, isTrue);
      expect(profession.professionSlug, 'welder');
      expect(profession.professionName, 'Welder');
      expect(profession.industrySlug, 'manufacturing');
      expect(profession.industryName, 'Manufacturing');
    });
  });

  group('PortfolioMappers.toPublicCredential', () {
    test('maps all credential fields', () {
      final PublicCredentialDto dto = seedPublicCredentialDto(
        kind: 'trade_proof',
        title: 'Trade License',
        verificationStatus: 'approved',
      );

      final PublicCredential credential = PortfolioMappers.toPublicCredential(dto);

      expect(credential.kind, 'trade_proof');
      expect(credential.title, 'Trade License');
      expect(credential.verificationStatus, 'approved');
    });
  });

  group('PortfolioMappers.toPortfolioItem', () {
    test('maps all portfolio item fields', () {
      final PortfolioItemDto dto = seedPortfolioItemDto(
        id: 'item-2',
        itemType: 'link',
        title: 'Case Study',
        description: 'Client case study.',
        mediaPath: 'portfolio-items/ent-1/case.pdf',
        sortOrder: 5,
      );

      final PortfolioItem item = PortfolioMappers.toPortfolioItem(dto);

      expect(item.id, 'item-2');
      expect(item.itemType, 'link');
      expect(item.title, 'Case Study');
      expect(item.description, 'Client case study.');
      expect(item.mediaPath, 'portfolio-items/ent-1/case.pdf');
      expect(item.sortOrder, 5);
    });

    test('null optional fields map through as null', () {
      final PortfolioItemDto dto = seedPortfolioItemDto(
        itemType: null,
        title: null,
        description: null,
        mediaPath: null,
        sortOrder: null,
      );

      final PortfolioItem item = PortfolioMappers.toPortfolioItem(dto);

      expect(item.itemType, isNull);
      expect(item.title, isNull);
      expect(item.description, isNull);
      expect(item.mediaPath, isNull);
      expect(item.sortOrder, isNull);
    });
  });
}
