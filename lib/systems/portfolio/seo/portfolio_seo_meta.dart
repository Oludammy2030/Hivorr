import 'package:hivorr/data/entities/public_profession.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/shared/extensions/string_extensions.dart';

/// SEO metadata for the public professional profile route `/p/:slug/:id`
/// (EP-02-19 §5.5, DoD FV-17/UA-04).
///
/// Derived exclusively from the RPC payload + an injectable origin — never from
/// `legal_name` or any guarded column. `title` is `displayName · professionName`,
/// `description` is a truncated bio, and `canonicalUrl` points at the stable
/// `/p/:profession_slug/:entity_id` URL (slug is cosmetic, entity id is
/// authoritative).
class PortfolioSeoMeta {
  const PortfolioSeoMeta({
    required this.title,
    required this.description,
    required this.canonicalUrl,
  });

  /// `<title>` — `displayName · professionName` (falling back to display name).
  final String title;

  /// `<meta name="description">` — truncated bio (≤ [maxDescriptionLength]).
  final String description;

  /// `<link rel="canonical">` — absolute `/p/:slug/:entityId` URL.
  final String canonicalUrl;
}

/// Builds [PortfolioSeoMeta] from the RPC payload (EP-02-19 DoD FV-17).
abstract final class PortfolioSeoMetaBuilder {
  const PortfolioSeoMetaBuilder._();

  /// Description length cap (SEO guidance).
  static const int maxDescriptionLength = 160;

  /// Builds the SEO vocab for [profile].
  ///
  /// [baseUrl] is the canonical web origin (trailing slash optional); [routeSlug]
  /// is the slug currently in the address bar and is used only as a fallback —
  /// the RPC-derived `professionSlug` wins when present (slug is cosmetic).
  static PortfolioSeoMeta build({
    required PublicProfile profile,
    required String baseUrl,
    String? routeSlug,
  }) {
    final PublicProfession? primary = _primaryProfession(profile);
    final String professionName =
        profile.professionName ?? primary?.professionName ?? '';
    final String title = professionName.isEmpty
        ? profile.displayName
        : '${profile.displayName} · $professionName';

    final String slug = profile.professionSlug ??
        ((routeSlug == null || routeSlug.isEmpty)
            ? profile.entityId
            : routeSlug);
    final String origin = _trimSlashes(baseUrl);
    final String canonical = origin.isEmpty
        ? '/p/$slug/${profile.entityId}'
        : '$origin/p/$slug/${profile.entityId}';

    return PortfolioSeoMeta(
      title: title,
      description: _describe(profile, professionName),
      canonicalUrl: canonical,
    );
  }

  /// Never contains `legal_name`; bio is user-authored public text (SV-08).
  static String _describe(PublicProfile profile, String professionName) {
    final String? bio = profile.bio?.trim();
    if (bio != null && bio.isNotEmpty) {
      return bio.truncate(maxDescriptionLength);
    }
    final String noun = professionName.isEmpty ? 'professional' : professionName;
    return 'Verified professional profile of ${profile.displayName} — $noun.'
        .truncate(maxDescriptionLength);
  }

  static PublicProfession? _primaryProfession(PublicProfile profile) {
    for (final PublicProfession entry in profile.professions) {
      if (entry.isPrimary) {
        return entry;
      }
    }
    if (profile.professions.isNotEmpty) {
      return profile.professions.first;
    }
    return null;
  }

  static String _trimSlashes(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}