/// Deterministic growth seam: SEO metadata + referral loops
/// (ARCHITECTURE.md `lib/engine/growth_engine/`).
///
/// EP-03-19 populates the SEO half: [ListingSeoMeta] builders plus the
/// web-guarded [SeoHead]/[SeoService] head seam, reusable by EP-04
/// product/store routes. No ranking, pricing, or financial logic lives here.
library;

export 'listing_seo_meta.dart';
export 'seo_head.dart';
export 'seo_meta_view.dart';
export 'seo_service.dart';
