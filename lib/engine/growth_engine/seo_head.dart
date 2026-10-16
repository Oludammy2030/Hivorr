import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'package:hivorr/engine/growth_engine/seo_meta_view.dart';
import 'package:hivorr/engine/growth_engine/seo_service.dart';

/// Resolves the canonical web origin for SEO meta (EP-03-19 §7.3).
///
/// On web the live origin wins ([Uri.base.origin]); elsewhere the
/// compile-time `SEO_BASE_URL` is used (default `''` → relative canonical,
/// portfolio parity). Never hardcodes a prod origin in widgets.
String seoOrigin() {
  if (kIsWeb) {
    try {
      return Uri.base.origin;
    } on Object {
      return const String.fromEnvironment('SEO_BASE_URL', defaultValue: '');
    }
  }
  return const String.fromEnvironment('SEO_BASE_URL', defaultValue: '');
}

/// Mounts a [SeoMetaView] into the document head (web-only side effect).
///
/// Renders nothing. Safe to place alongside any screen — on non-web
/// platforms [build] is a plain [SizedBox.shrink], and in VM tests the
/// stub writer drops the update.
class SeoHead extends StatelessWidget {
  const SeoHead({super.key, required this.view});

  /// Head content to apply.
  final SeoMetaView view;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SeoService.update(view);
      });
    }
    return const SizedBox.shrink();
  }
}
