import 'package:hivorr/engine/growth_engine/listing_seo_meta.dart';
import 'package:hivorr/systems/portfolio/seo/portfolio_seo_meta.dart';

/// Lightweight web-document head view shared by listing, browse, and profile
/// SEO (EP-03-19 §7.4).
///
/// Pure-Dart value — safe to construct on all platforms. Application to the
/// live document happens only via `SeoService.update` (web-guarded,
/// conditional import so VM tests never compile `package:web`).
class SeoMetaView {
  const SeoMetaView({
    required this.title,
    required this.description,
    required this.canonicalUrl,
    required this.ogImage,
  });

  /// `<title>` / `og:title`.
  final String title;

  /// `meta[name=description]` / `og:description`.
  final String description;

  /// `link[rel=canonical]` / `og:url`.
  final String canonicalUrl;

  /// `og:image`.
  final String ogImage;

  /// Adapts a listing meta model to the head view.
  factory SeoMetaView.fromListing(ListingSeoMeta meta) => SeoMetaView(
        title: meta.title,
        description: meta.description,
        canonicalUrl: meta.canonicalUrl,
        ogImage: meta.ogImage,
      );

  /// Adapts a portfolio meta model to the head view (EP-02-19 retrofit).
  ///
  /// Portfolio meta carries no `og:image`, so the brand logo is used —
  /// [logoPath] may be absolute (preferred on web) or app-relative.
  factory SeoMetaView.fromPortfolio(
    PortfolioSeoMeta meta, {
    String logoPath = ListingSeoMetaBuilder.logoFallbackPath,
  }) =>
      SeoMetaView(
        title: meta.title,
        description: meta.description,
        canonicalUrl: meta.canonicalUrl,
        ogImage: logoPath,
      );

  /// Adapts a browse meta model to the head view.
  factory SeoMetaView.fromBrowse(ListingSeoMeta meta) =>
      SeoMetaView.fromListing(meta);
}
