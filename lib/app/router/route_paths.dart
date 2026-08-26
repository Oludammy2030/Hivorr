/// Compile-time route path constants (GoRouter path patterns).
///
/// Path parameters use GoRouter syntax (`:param`). Use the typed builders
/// [publicProfile] / [publicStore] to produce fully-qualified, URL-encoded
/// paths for navigation and deep links (EP-01-15 §5.5).
abstract final class RoutePaths {
  const RoutePaths._();

  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String profile = '/profile';
  static const String settings = '/settings';

  /// Public profile route. Parameters: `slug`, `id`.
  static const String publicProfileRoute = '/p/:slug/:id';

  /// Public store route. Parameter: `storeId`.
  static const String publicStoreRoute = '/store/:storeId';

  /// Builds a URL-encoded public profile path, e.g.
  /// `publicProfile(slug: 'electrician', id: 'abc-123')` → `/p/electrician/abc-123`.
  static String publicProfile({
    required String slug,
    required String id,
  }) =>
      '/p/${Uri.encodeComponent(slug)}/${Uri.encodeComponent(id)}';

  /// Builds a URL-encoded public store path, e.g.
  /// `publicStore(storeId: 'xyz-456')` → `/store/xyz-456`.
  static String publicStore({required String storeId}) =>
      '/store/${Uri.encodeComponent(storeId)}';
}
