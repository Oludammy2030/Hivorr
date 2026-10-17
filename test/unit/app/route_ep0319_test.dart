import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/core/notifications/navigation/notification_tap_dispatcher.dart';

import '../../test_helpers.dart';

void main() {
  group('EP-03-19 public listing routes', () {
    test('SEO route constants match the approved route table', () {
      expect(RoutePaths.serviceSeoDetailRoute, '/s/:slug/:id');
      expect(RoutePaths.serviceSeoBrowseRoute, '/s/:industrySlug');
      expect(RoutePaths.profileAliasRoute, '/c/:slug/:id');
      expect(RouteNames.serviceSeoBrowse, 'service-seo-browse');
      expect(RouteNames.profileAlias, 'profile-alias');
    });

    test('typed builders produce URL-encoded paths', () {
      expect(RoutePaths.serviceSeoBrowse('technology'), '/s/technology');
      expect(RoutePaths.serviceSeoBrowse('a b/c'), '/s/a%20b%2Fc');
      expect(
        RoutePaths.profileAlias(slug: 'electrician', id: 'abc-123'),
        '/c/electrician/abc-123',
      );
      expect(
        RoutePaths.profileAlias(slug: 'a b/c', id: 'x&y'),
        '/c/a%20b%2Fc/x%26y',
      );
    });

    test('unauthenticated viewers may open SEO browse and alias doors', () {
      final provider = FakeAuthProvider(
        initialStatus: AuthStatus.unauthenticated,
      );
      final guard = RouteGuard(authProvider: provider);

      expect(guard.redirectResolver('/s/technology'), isNull);
      expect(guard.redirectResolver('/s/plumber/abc-123'), isNull);
      expect(guard.redirectResolver('/c/electrician/abc-123'), isNull);
      // Owner routes stay protected.
      expect(
        guard.redirectResolver('/services/mine'),
        '/login?next=/services/mine',
      );
    });

    test('dispatcher allowlists the new public shapes', () {
      expect(
        NotificationTapDispatcher.isAllowedRoute('/s/technology'),
        isTrue,
      );
      expect(
        NotificationTapDispatcher.isAllowedRoute('/s/plumber/abc-123'),
        isTrue,
      );
      expect(
        NotificationTapDispatcher.isAllowedRoute('/c/electrician/abc-123'),
        isTrue,
      );
      expect(
        NotificationTapDispatcher.isAllowedRoute('/contracts/abc'),
        isTrue,
      );
      expect(
        NotificationTapDispatcher.isAllowedRoute('https://evil.example/x'),
        isFalse,
      );
      expect(NotificationTapDispatcher.isAllowedRoute(null), isFalse);
    });
  });
}
