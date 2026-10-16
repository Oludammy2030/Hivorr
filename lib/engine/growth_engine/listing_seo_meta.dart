import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/shared/extensions/string_extensions.dart';

/// SEO metadata for the public listing detail route `/s/:slug/:id`
/// (EP-03-19 §7.3, closing the EP-03-15 `og:image` deferral).
///
/// Mirrors [PortfolioSeoMetaBuilder] conventions: `title` is
/// `{title} · {professionName}`, `description` is a truncated description
/// (≤ [maxDescriptionLength]), and `canonicalUrl` points at the stable
/// `/s/:profession_slug/:listing_id` URL (RPC `professionSlug` wins, route
/// slug is the fallback, listing slug is the last resort — `:id` is always
/// authoritative). Never contains `legal_name`, viewer identity, escrow, or
/// contact PII — only the public RPC payload plus an injectable origin.
class ListingSeoMeta {
  const ListingSeoMeta({
    required this.title,
    required this.description,
    required this.canonicalUrl,
    required this.ogImage,
  });

  /// `<title>` — `{title} · {professionName}` (falling back to title only).
  final String title;

  /// `<meta name="description">` — truncated description (≤ max length).
  final String description;

  /// `<link rel="canonical">` — absolute `/s/:slug/:listingId` URL.
  final String canonicalUrl;

  /// `og:image` — cover public URL or brand-logo fallback (absolute when
  /// [baseUrl] is absolute, app-relative otherwise).
  final String ogImage;
}

/// Builds [ListingSeoMeta] from public RPC payloads (EP-03-19 DoD FV-05).
abstract final class ListingSeoMetaBuilder {
  const ListingSeoMetaBuilder._();

  /// Description length cap (SEO guidance, portfolio parity).
  static const int maxDescriptionLength = 160;

  /// Brand-logo fallback for `og:image` (app-relative; callers prefix with
  /// the origin when an absolute URL is required).
  static const String logoFallbackPath = 'assets/images/logo_icon.png';

  /// Core builder over scalar public fields shared by ranked and owner rows.
  ///
  /// [baseUrl] is the canonical web origin (trailing slash optional, `''`
  /// yields a relative canonical — portfolio parity). [routeSlug] is the slug
  /// currently in the address bar and is used only as a fallback — the
  /// RPC-derived `professionSlug` wins when present (slug is cosmetic).
  /// [coverImageUrl] is the resolved public cover URL (or `null` for the
  /// brand-logo fallback). Never pass signed/private URLs.
  static ListingSeoMeta build({
    required String listingId,
    required String title,
    required String description,
    required String baseUrl,
    String? listingSlug,
    String? professionSlug,
    String? professionName,
    String? routeSlug,
    String? coverImageUrl,
  }) {
    final String cleanTitle = title.trim();
    final String name = (professionName ?? '').trim();
    final String metaTitle =
        name.isEmpty ? cleanTitle : '$cleanTitle · $name';

    final String slug = _resolveSlug(
      professionSlug: professionSlug,
      routeSlug: routeSlug,
      listingSlug: listingSlug,
      listingId: listingId,
    );
    final String origin = _trimSlashes(baseUrl);
    final String canonical = origin.isEmpty
        ? '/s/$slug/$listingId'
        : '$origin/s/$slug/$listingId';

    final String? cover = coverImageUrl?.trim();
    final String ogImage = (cover != null && cover.isNotEmpty)
        ? cover
        : (origin.isEmpty ? logoFallbackPath : '$origin/$logoFallbackPath');

    return ListingSeoMeta(
      title: metaTitle,
      description: _describe(description, name),
      canonicalUrl: canonical,
      ogImage: ogImage,
    );
  }

  /// Convenience over a ranked [ServiceListing] row plus resolved cover URL.
  static ListingSeoMeta buildFromListing(
    ServiceListing listing, {
    required String baseUrl,
    String? routeSlug,
    String? coverImageUrl,
  }) =>
      build(
        listingId: listing.id,
        title: listing.title,
        description: listing.description,
        baseUrl: baseUrl,
        listingSlug: listing.slug,
        professionSlug: listing.professionSlug,
        professionName: listing.professionName,
        routeSlug: routeSlug,
        coverImageUrl: coverImageUrl,
      );

  /// Convenience over an owner [MyServiceListing] row plus resolved cover URL.
  static ListingSeoMeta buildFromOwner(
    MyServiceListing listing, {
    required String baseUrl,
    String? routeSlug,
    String? coverImageUrl,
  }) =>
      build(
        listingId: listing.id,
        title: listing.title,
        description: listing.description,
        baseUrl: baseUrl,
        listingSlug: listing.slug,
        professionSlug: listing.professionSlug,
        professionName: listing.professionName,
        routeSlug: routeSlug,
        coverImageUrl: coverImageUrl,
      );

  /// Browse meta for `/s/:industrySlug` (EP-03-19 §7.4).
  static ListingSeoMeta buildBrowse({
    required String baseUrl,
    String? industrySlug,
    String? industryName,
  }) {
    final String slug = (industrySlug ?? '').trim().isEmpty
        ? 'services'
        : industrySlug!.trim();
    final String name = (industryName ?? '').trim();
    final String title =
        name.isEmpty ? 'Services on Hivorr' : '$name services on Hivorr';
    final String description = name.isEmpty
        ? 'Browse verified professional services on Hivorr.'
            .truncate(maxDescriptionLength)
        : 'Browse verified $name services on Hivorr — escrow-protected bookings.'
            .truncate(maxDescriptionLength);
    final String origin = _trimSlashes(baseUrl);
    final String canonical =
        origin.isEmpty ? '/s/$slug' : '$origin/s/$slug';
    final String ogImage =
        origin.isEmpty ? logoFallbackPath : '$origin/$logoFallbackPath';
    return ListingSeoMeta(
      title: title,
      description: description,
      canonicalUrl: canonical,
      ogImage: ogImage,
    );
  }

  /// Never contains `legal_name`; description is user-authored public text.
  static String _describe(String description, String professionName) {
    final String clean = description.trim();
    if (clean.isNotEmpty) {
      return clean.truncate(maxDescriptionLength);
    }
    final String noun =
        professionName.isEmpty ? 'service' : professionName;
    return 'Verified service — $noun on Hivorr.'.truncate(
      maxDescriptionLength,
    );
  }

  static String _resolveSlug({
    String? professionSlug,
    String? routeSlug,
    String? listingSlug,
    required String listingId,
  }) {
    final String rpc = (professionSlug ?? '').trim();
    if (rpc.isNotEmpty) return rpc;
    final String route = (routeSlug ?? '').trim();
    if (route.isNotEmpty) return route;
    final String listing = (listingSlug ?? '').trim();
    if (listing.isNotEmpty) return listing;
    return listingId;
  }

  static String _trimSlashes(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
