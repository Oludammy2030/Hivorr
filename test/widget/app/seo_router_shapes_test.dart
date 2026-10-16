import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';

import '../../support/harnesses/router_harness.dart';

void main() {
  group('EP-03-19 SEO router shapes (doorRouter)', () {
    testWidgets('two-segment /s/:slug/:id wins over one-segment browse', (
      WidgetTester tester,
    ) async {
      final GoRouter router = doorRouter(
        initialLocation: '/s/plumber/abc-123',
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Service SEO detail'), findsOneWidget);
      expect(find.text('Service SEO browse'), findsNothing);
    });

    testWidgets('one-segment /s/:industrySlug renders the browse door', (
      WidgetTester tester,
    ) async {
      final GoRouter router = doorRouter(initialLocation: '/s/technology');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Service SEO browse'), findsOneWidget);
    });

    testWidgets('/c/:slug/:id redirects single-hop to /p/:slug/:id', (
      WidgetTester tester,
    ) async {
      final GoRouter router = doorRouter(
        initialLocation:
            RoutePaths.profileAlias(slug: 'electrician', id: 'abc-123'),
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Public profile'), findsOneWidget);
      expect(
        router.state.matchedLocation,
        RoutePaths.publicProfile(slug: 'electrician', id: 'abc-123'),
      );
    });
  });
}
