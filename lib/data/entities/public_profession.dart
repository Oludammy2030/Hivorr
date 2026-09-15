/// Pure Dart domain model for a public profession badge on the professional
/// profile page (EP-02-19).
///
/// Derived from the `entity_professions` JOIN `professions` JOIN `industries`
/// projection inside the `portfolio_public_profile_get` RPC. Contains only
/// whitelisted fields — never `verified_at`, `verified_by`, or `sort_order`.
class PublicProfession {
  const PublicProfession({
    required this.id,
    required this.professionId,
    required this.isPrimary,
    required this.professionSlug,
    required this.professionName,
    required this.industrySlug,
    required this.industryName,
  });

  /// Row id from `entity_professions`.
  final String id;

  /// FK → `professions.id`.
  final String professionId;

  /// Whether this is the entity's primary profession.
  final bool isPrimary;

  /// SEO-stable profession slug (e.g. `software-developer`).
  final String professionSlug;

  /// Human-readable profession name.
  final String professionName;

  /// SEO-stable industry slug (e.g. `technology`).
  final String industrySlug;

  /// Human-readable industry name.
  final String industryName;
}
