import 'package:hivorr/engine/growth_engine/seo_meta_view.dart';
import 'package:web/web.dart' as web;

/// Applies [SeoMetaView] to the web document head (EP-03-19 §7.4).
///
/// Web-only implementation behind the [seo_service.dart] conditional export —
/// never compiled into VM tests. Never throws: DOM access is best-effort so
/// a blocked interop never breaks navigation.
abstract final class SeoService {
  const SeoService._();

  /// Writes title, description, canonical, and `og:*` tags.
  static void update(SeoMetaView view) {
    try {
      _apply(view);
    } on Object {
      // Best-effort SEO: stale head is preferable to a broken route.
    }
  }

  static void _apply(SeoMetaView view) {
    final web.Document document = web.window.document;
    document.title = view.title;
    _upsertMeta(document, 'name', 'description', view.description);
    _upsertMeta(document, 'property', 'og:title', view.title);
    _upsertMeta(document, 'property', 'og:description', view.description);
    _upsertMeta(document, 'property', 'og:url', view.canonicalUrl);
    _upsertMeta(document, 'property', 'og:type', 'website');
    _upsertMeta(document, 'property', 'og:image', view.ogImage);
    _upsertCanonical(document, view.canonicalUrl);
  }

  static void _upsertMeta(
    web.Document document,
    String attr,
    String key,
    String content,
  ) {
    final String selector = 'meta[$attr="$key"]';
    final web.Element? existing = document.querySelector(selector);
    if (existing != null) {
      existing.setAttribute('content', content);
      return;
    }
    final web.Element tag = document.createElement('meta');
    tag.setAttribute(attr, key);
    tag.setAttribute('content', content);
    document.head?.append(tag);
  }

  static void _upsertCanonical(
    web.Document document,
    String href,
  ) {
    final web.Element? existing =
        document.querySelector('link[rel="canonical"]');
    if (existing != null) {
      existing.setAttribute('href', href);
      return;
    }
    final web.Element link = document.createElement('link');
    link.setAttribute('rel', 'canonical');
    link.setAttribute('href', href);
    document.head?.append(link);
  }
}
