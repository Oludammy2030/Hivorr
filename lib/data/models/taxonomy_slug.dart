/// Shared slug contract for the two-tier taxonomy registry.
///
/// Mirrors the server-side `industries_slug_format` / `professions_slug_format`
/// CHECK constraints (EP-01-06): lowercase kebab-case, ≤ 140 chars. The DTOs use
/// this defensively during `fromJson` (EP-02-07 plan §12); the server remains
/// the authority and always enforces it on write.
library;

/// The slug character-set/format assertion shared by both taxonomy tiers.
final class TaxonomySlug {
  TaxonomySlug._();

  /// Regex matching the server-enforced slug format `^[a-z0-9]+(-[a-z0-9]+)*$`.
  static final RegExp format = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  /// Maximum allowed slug length (matches the server CHECK constraint ≤ 140).
  static const int maxLength = 140;

  /// Returns `true` when [slug] conforms to the taxonomy slug contract.
  static bool isValid(String slug) =>
      slug == slug.toLowerCase() &&
      format.hasMatch(slug) &&
      slug.length <= maxLength;
}
