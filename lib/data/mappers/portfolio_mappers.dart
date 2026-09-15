import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/entities/public_credential.dart';
import 'package:hivorr/data/entities/public_profession.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/models/portfolio_item_dto.dart';
import 'package:hivorr/data/models/public_credential_dto.dart';
import 'package:hivorr/data/models/public_profession_dto.dart';
import 'package:hivorr/data/models/public_profile_dto.dart';

/// Transforms public profile/portfolio DTOs ↔ domain entities (EP-02-19).
///
/// The single transformation boundary between the transport DTOs and the
/// pure-Dart domain entities. No I/O and no business logic.
class PortfolioMappers {
  const PortfolioMappers._();

  /// Maps [PublicProfileDto] → [PublicProfile].
  static PublicProfile toPublicProfile(PublicProfileDto dto) => PublicProfile(
    entityId: dto.entityId,
    displayName: dto.displayName,
    avatarPath: dto.avatarPath,
    bio: dto.bio,
    countryCode: dto.countryCode,
    professions: dto.professions.map(toPublicProfession).toList(growable: false),
    credentials:
        dto.credentials.map(toPublicCredential).toList(growable: false),
    kycTierCode: dto.kycTierCode,
    kycStatus: dto.kycStatus,
    portfolioItems:
        dto.portfolioItems.map(toPortfolioItem).toList(growable: false),
    professionSlug: dto.professionSlug,
    professionName: dto.professionName,
    industrySlug: dto.industrySlug,
    industryName: dto.industryName,
  );

  /// Maps [PublicProfessionDto] → [PublicProfession].
  static PublicProfession toPublicProfession(PublicProfessionDto dto) =>
      PublicProfession(
        id: dto.id,
        professionId: dto.professionId,
        isPrimary: dto.isPrimary,
        professionSlug: dto.professionSlug,
        professionName: dto.professionName,
        industrySlug: dto.industrySlug,
        industryName: dto.industryName,
      );

  /// Maps [PublicCredentialDto] → [PublicCredential].
  static PublicCredential toPublicCredential(PublicCredentialDto dto) =>
      PublicCredential(
        kind: dto.kind,
        title: dto.title,
        verificationStatus: dto.verificationStatus,
      );

  /// Maps [PortfolioItemDto] → [PortfolioItem].
  static PortfolioItem toPortfolioItem(PortfolioItemDto dto) => PortfolioItem(
    id: dto.id,
    itemType: dto.itemType,
    title: dto.title,
    description: dto.description,
    mediaPath: dto.mediaPath,
    sortOrder: dto.sortOrder,
  );
}
