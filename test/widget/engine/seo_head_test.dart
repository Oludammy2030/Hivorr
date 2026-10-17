import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/engine/growth_engine/seo_head.dart';
import 'package:hivorr/engine/growth_engine/seo_meta_view.dart';

void main() {
  group('SeoHead', () {
    testWidgets('renders nothing and applies head without throwing', (
      WidgetTester tester,
    ) async {
      const SeoMetaView view = SeoMetaView(
        title: 'Technology services on Hivorr',
        description: 'Browse verified Technology services on Hivorr.',
        canonicalUrl: '/s/technology',
        ogImage: 'assets/images/logo_icon.png',
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SeoHead(view: view))),
      );
      await tester.pump();

      // Renders as a zero-size box — no color, text, or layout of its own
      // (AGENT.md Rule 5: zero hardcoded visuals in the seam).
      expect(find.byType(SeoHead), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.textContaining('Technology'), findsNothing);
    });
  });
}
