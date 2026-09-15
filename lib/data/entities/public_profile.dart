import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/entities/public_credential.dart';
import 'package:hivorr/data/entities/public_profession.dart';

/// Pure Dart domain model for the full public professional profile (EP-02-19).
///
/// Assembled by the `portfolio_public_profile_get` SECURITY DEFINER RPC.
/// Contains only whitelisted columns — never `legal_name`, `document_path`,
/// review metadata, or KYC limits.
class PublicProfile {
  const PublicProfile({
    required this.entityId,
    required this.displayName,
    this.avatarPath,
    this.bio,
    this.countryCode,
    this.professions = const <PublicProfession>[],
    this.credentials = const <PublicCredential>[],
    this.kycTierCode,
    this.kycStatus,
    this.portfolioItems = const <PortfolioItem>[],
    this.professionSlug,
    this.professionName,
    this.industrySlug,
    this.industryName,
  });

  /// Entity UUID (authoritative; slug is cosmetic).
  final String entityId;

  /// Public display name (never `legal_name`).
  final String displayName;

  /// Optional avatar storage path.
  final String? avatarPath;

  /// Optional user-authored bio text.
  final String? bio;

  /// Optional ISO 3166-1 alpha-2 country code.
  final String? countryCode;

  /// Approved profession badges with taxonomy slugs.
  final List<PublicProfession> professions;

  /// Approved credentials (read-only chips).
  final List<PublicCredential> credentials;

  /// KYC tier code (e.g. `tier_1`), when assigned.
  final String? kycTierCode;

  /// KYC level status (e.g. `active`).
  final String? kycStatus;

  /// Owner-managed portfolio work samples.
  final List<PortfolioItem> portfolioItems;

  /// Primary profession slug for the SEO route `/p/:profession_slug/:entity_id`.
  final String? professionSlug;

  /// Primary profession display name.
  final String? professionName;

  /// Primary industry slug.
  final String? industrySlug;

  /// Primary industry display name.
  final String? industryName;
}
