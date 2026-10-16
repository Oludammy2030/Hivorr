import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/engine/growth_engine/seo_meta_view.dart';
import 'package:hivorr/engine/growth_engine/seo_service.dart';

void main() {
  group('SeoService', () {
    test('update is a safe no-op off web (VM stub)', () {
      const SeoMetaView view = SeoMetaView(
        title: 'Fix leaky tap fast · Plumber',
        description: 'Same-day tap repairs.',
        canonicalUrl: '/s/plumber/listing-1',
        ogImage: 'assets/images/logo_icon.png',
      );

      expect(() => SeoService.update(view), returnsNormally);
    });
  });
}
