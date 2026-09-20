import 'package:hivorr/data/models/portfolio_item_dto.dart';
import 'package:hivorr/data/models/public_credential_dto.dart';
import 'package:hivorr/data/models/public_profession_dto.dart';

/// DTO for the full `portfolio_public_profile_get` RPC envelope `data` payload
/// (EP-02-19).
///
/// Maps the snake_case JSON keys from the RPC projection exactly.
class PublicProfileDto {
  const PublicProfileDto({
    required this.entityId,
    required this.displayName,
    this.avatarPath,
    this.bio,
    this.countryCode,
    this.professions = const <PublicProfessionDto>[],
    this.credentials = const <PublicCredentialDto>[],
    this.kycTierCode,
    this.kycStatus,
    this.portfolioItems = const <PortfolioItemDto>[],
    this.professionSlug,
    this.professionName,
    this.industrySlug,
    this.industryName,
  });

  factory PublicProfileDto.fromJson(Map<String, dynamic> json) =>
      PublicProfileDto(
        entityId: json['entity_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        avatarPath: json['avatar_path'] as String?,
        bio: json['bio'] as String?,
        countryCode: json['country_code'] as String?,
        professions:
            (json['professions'] as List<dynamic>?)
                ?.map(
                  (e) =>
                      PublicProfessionDto.fromJson(e as Map<String, dynamic>),
                )
                .toList(growable: false) ??
            const <PublicProfessionDto>[],
        credentials:
            (json['credentials'] as List<dynamic>?)
                ?.map(
                  (e) =>
                      PublicCredentialDto.fromJson(e as Map<String, dynamic>),
                )
                .toList(growable: false) ??
            const <PublicCredentialDto>[],
        kycTierCode: json['kyc'] is Map
            ? (json['kyc'] as Map<String, dynamic>)['tier_code'] as String?
            : null,
        kycStatus: json['kyc'] is Map
            ? (json['kyc'] as Map<String, dynamic>)['status'] as String?
            : null,
        portfolioItems:
            (json['portfolio_items'] as List<dynamic>?)
                ?.map(
                  (e) => PortfolioItemDto.fromJson(e as Map<String, dynamic>),
                )
                .toList(growable: false) ??
            const <PortfolioItemDto>[],
        professionSlug: json['profession_slug'] as String?,
        professionName: json['profession_name'] as String?,
        industrySlug: json['industry_slug'] as String?,
        industryName: json['industry_name'] as String?,
      );

  final String entityId;
  final String displayName;
  final String? avatarPath;
  final String? bio;
  final String? countryCode;
  final List<PublicProfessionDto> professions;
  final List<PublicCredentialDto> credentials;
  final String? kycTierCode;
  final String? kycStatus;
  final List<PortfolioItemDto> portfolioItems;
  final String? professionSlug;
  final String? professionName;
  final String? industrySlug;
  final String? industryName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'entity_id': entityId,
    'display_name': displayName,
    if (avatarPath != null) 'avatar_path': avatarPath,
    if (bio != null) 'bio': bio,
    if (countryCode != null) 'country_code': countryCode,
    'professions': professions.map((e) => e.toJson()).toList(growable: false),
    'credentials': credentials.map((e) => e.toJson()).toList(growable: false),
    'kyc': <String, dynamic>{
      if (kycTierCode != null) 'tier_code': kycTierCode,
      if (kycStatus != null) 'status': kycStatus,
    },
    'portfolio_items': portfolioItems
        .map((e) => e.toJson())
        .toList(growable: false),
    if (professionSlug != null) 'profession_slug': professionSlug,
    if (professionName != null) 'profession_name': professionName,
    if (industrySlug != null) 'industry_slug': industrySlug,
    if (industryName != null) 'industry_name': industryName,
  };
}
