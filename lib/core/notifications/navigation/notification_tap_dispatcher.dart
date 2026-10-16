import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/logging/logging.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';

/// Routes a tapped notification to its deep-link target.
///
/// Allowlist-only: [actionRoute] must start with a known prefix
/// (`/contracts`, `/dashboard`, `/appointments`, `/support`, `/finance`,
/// `/services`, `/s`, `/p`, `/c`). Anything else is logged and dropped — never
/// navigated (no open redirect). Auth preservation (`?next=` resume) stays
/// in `RouteGuard`; this dispatcher only validates and forwards.
class NotificationTapDispatcher {
  /// Creates the dispatcher with an optional logger.
  const NotificationTapDispatcher({this.logger});

  /// Optional PII-safe logger.
  final HivorrLogger? logger;

  /// Whether [actionRoute] is a known in-app deep-link.
  static bool isAllowedRoute(String? actionRoute) {
    if (actionRoute == null || actionRoute.isEmpty) return false;
    return actionRoute.startsWith('/contracts') ||
        actionRoute.startsWith('/dashboard') ||
        actionRoute.startsWith('/appointments') ||
        actionRoute.startsWith('/support') ||
        actionRoute.startsWith('/finance') ||
        actionRoute.startsWith('/services') ||
        actionRoute.startsWith('/s/') ||
        actionRoute.startsWith('/p/') ||
        actionRoute.startsWith('/c/');
  }

  /// Resolves the navigation target for [notification], or null to drop.
  String? resolveTarget(HivorrNotification notification) {
    final String? route = notification.actionRoute;
    if (!isAllowedRoute(route)) {
      logger?.warning(
        'Dropped notification tap with disallowed route',
        <String, Object?>{'hasRoute': route != null && route.isNotEmpty},
      );
      return null;
    }
    return route;
  }

  /// Canonical route builders mirrored from the server template registry.
  static String contractDetail(String id) => RoutePaths.contractDetail(id);
  static String messageThread(String conversationId) =>
      RoutePaths.dashboardMessageThread(conversationId);
  static String appointmentDetail(String id) =>
      RoutePaths.appointmentDetail(id);
  static String disputeDetail(String id) =>
      '/support/disputes/${Uri.encodeComponent(id)}';
  static String earnings({String? contractId}) =>
      RoutePaths.earningsHistoryFor(contractId: contractId);
  static String contractReviews(String contractId) =>
      RoutePaths.contractReviewsFor(contractId);
}
