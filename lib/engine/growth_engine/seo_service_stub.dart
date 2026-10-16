import 'package:hivorr/engine/growth_engine/seo_meta_view.dart';

/// No-op head writer for non-web platforms and VM tests.
///
/// The browser document does not exist here; updates are dropped silently so
/// navigation never breaks outside Web.
abstract final class SeoService {
  const SeoService._();

  /// Drops [view] (non-web no-op).
  static void update(SeoMetaView view) {}
}
