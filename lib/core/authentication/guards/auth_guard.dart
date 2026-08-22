/// Route authorization helper for EP-01-15 GoRouter.
///
/// Pure and testable: it does not depend on a router. It fails **closed** —
/// any protected route requested while unauthenticated resolves to the login
/// route (EP-01-09 §5.6, §12).
class AuthGuard {
  /// Creates the guard.
  ///
  /// [isAuthenticated] supplies the live authentication state; it is a callback
  /// (not a captured bool) so the guard reflects changes over time.
  /// [publicRoutePrefixes] lists routes always accessible without a session.
  AuthGuard({
    required this.isAuthenticated,
    this.publicRoutePrefixes = _defaultPublicPrefixes,
  });

  /// Supplier of the current authentication state.
  final bool Function() isAuthenticated;

  /// Route prefixes that are always publicly accessible.
  final List<String> publicRoutePrefixes;

  static const List<String> _defaultPublicPrefixes = <String>[
    '/login',
    '/signup',
    '/auth',
    '/forgot-password',
    '/reset-password',
  ];

  /// Whether [location] is a public route.
  bool isPublicRoute(String location) =>
      publicRoutePrefixes.any((String prefix) => location.startsWith(prefix));

  /// Whether [location] requires authentication.
  bool requiresAuth(String location) => !isPublicRoute(location);

  /// Resolves the redirect target, or `null` when access is allowed.
  ///
  /// Returns the login path when an unauthenticated user requests a protected
  /// route; otherwise `null` (allow). Never grants access by default.
  String? redirectResolver(String location) {
    if (!isAuthenticated() && requiresAuth(location)) {
      return '/login';
    }
    return null;
  }
}
