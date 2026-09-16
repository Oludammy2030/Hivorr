import 'dart:async';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/portfolio_remote_data_source.dart';
import 'package:hivorr/data/models/portfolio_item_dto.dart';
import 'package:hivorr/data/models/public_credential_dto.dart';
import 'package:hivorr/data/models/public_profession_dto.dart';
import 'package:hivorr/data/models/public_profile_dto.dart';

/// Scriptable [PortfolioRemoteDataSource] for portfolio unit/widget/integration
/// tests (EP-02-19).
///
/// Returns the seeded [result] DTO on every call; set [error] to exercise the
/// failure path exactly as the real RPC layer throws [ApiException]. When
/// [gate] is set, the fetch waits on the completer before resolving so tests
/// can hold the loading state open.
class FakePortfolioRemoteDataSource implements PortfolioRemoteDataSource {
  FakePortfolioRemoteDataSource({
    PublicProfileDto? result,
    this.error,
  }) : result = result ?? seedPublicProfileDto();

  /// The DTO served on every successful fetch.
  PublicProfileDto result;

  /// When non-null, thrown (once per call) instead of [result].
  ApiException? error;

  /// Optional gate held by the load under test (loading-state assertions).
  Completer<void>? gate;

  /// Number of `fetchPublicProfile` invocations.
  int callCount = 0;

  /// The last entity id requested.
  String? lastEntityId;

  /// Whether the last call hit the error path.
  bool lastThrew = false;

  @override
  Future<PublicProfileDto> fetchPublicProfile(String entityId) async {
    callCount++;
    lastEntityId = entityId;
    final Completer<void>? pending = gate;
    if (pending != null) await pending.future;
    final ApiException? failure = error;
    if (failure != null) {
      lastThrew = true;
      throw failure;
    }
    return result;
  }
}

/// A default approved professional profile DTO (identity + trade-verified,
/// one approved credential, two portfolio items).
PublicProfileDto seedPublicProfileDto({
  String entityId = 'entity-1',
  String displayName = 'Ada Lovelace',
  String? avatarPath = 'avatars/entity-1.png',
  String? bio = 'Analytical engine pioneer.',
  String? countryCode = 'NG',
  List<PublicProfessionDto>? professions,
  List<PublicCredentialDto>? credentials,
  String? kycTierCode = 'tier_1',
  String? kycStatus = 'active',
  List<PortfolioItemDto>? portfolioItems,
  String? professionSlug = 'software-engineer',
  String? professionName = 'Software Engineer',
  String? industrySlug = 'technology',
  String? industryName = 'Technology',
}) =>
    PublicProfileDto(
      entityId: entityId,
      displayName: displayName,
      avatarPath: avatarPath,
      bio: bio,
      countryCode: countryCode,
      professions: professions ??
          <PublicProfessionDto>[seedPublicProfessionDto()],
      credentials: credentials ??
          <PublicCredentialDto>[
            seedPublicCredentialDto(),
            seedPublicCredentialDto(
              kind: 'certification',
              title: 'AWS Solutions Architect',
            ),
          ],
      kycTierCode: kycTierCode,
      kycStatus: kycStatus,
      portfolioItems: portfolioItems ??
          <PortfolioItemDto>[
            seedPortfolioItemDto(
              id: 'item-2',
              title: 'Lakehouse Migration',
              description: 'Data lakehouse migration for a fintech.',
              sortOrder: 2,
              mediaPath: 'portfolio-items/entity-1/lakehouse.jpg',
            ),
            seedPortfolioItemDto(
              id: 'item-1',
              title: 'Escrow Platform',
              description: 'Milestone payment engine.',
              sortOrder: 1,
              mediaPath: 'portfolio-items/entity-1/escrow.jpg',
            ),
          ],
      professionSlug: professionSlug,
      professionName: professionName,
      industrySlug: industrySlug,
      industryName: industryName,
    );

/// A default approved public profession badge.
PublicProfessionDto seedPublicProfessionDto({
  String id = 'entity-prof-1',
  String professionId = 'prof-1',
  bool isPrimary = true,
  String professionSlug = 'software-engineer',
  String professionName = 'Software Engineer',
  String industrySlug = 'technology',
  String industryName = 'Technology',
}) =>
    PublicProfessionDto(
      id: id,
      professionId: professionId,
      isPrimary: isPrimary,
      professionSlug: professionSlug,
      professionName: professionName,
      industrySlug: industrySlug,
      industryName: industryName,
    );

/// A default approved credential DTO.
PublicCredentialDto seedPublicCredentialDto({
  String kind = 'identity_document',
  String title = 'National ID',
  String verificationStatus = 'approved',
}) =>
    PublicCredentialDto(
      kind: kind,
      title: title,
      verificationStatus: verificationStatus,
    );

/// A default portfolio item DTO.
PortfolioItemDto seedPortfolioItemDto({
  String id = 'item-1',
  String? itemType = 'image',
  String? title = 'Escrow Platform',
  String? description = 'Milestone payment engine.',
  String? mediaPath = 'portfolio-items/entity-1/escrow.jpg',
  int? sortOrder = 1,
}) =>
    PortfolioItemDto(
      id: id,
      itemType: itemType,
      title: title,
      description: description,
      mediaPath: mediaPath,
      sortOrder: sortOrder,
    );