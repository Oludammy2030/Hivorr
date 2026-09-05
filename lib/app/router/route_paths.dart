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

  /// Identity-verification standalone screens (EP-02-10).
  static const String verificationIdentity = '/verification/identity';
  static const String verificationStatus = '/verification/status';

  /// Trade-verification screens (EP-02-11).
  static const String tradeProofUpload = '/verification/trade-proof';
  static const String tradeVerificationStatus = '/verification/trade/status';

  /// Admin review queue (EP-02-11, simplified internal screen).
  static const String adminReviewQueue = '/admin/review-queue';

  /// KYC status + upgrade screens (EP-02-12).
  static const String kycStatus = '/verification/kyc';
  static const String kycUpgrade = '/verification/kyc/upgrade';

  /// Financial profile screens (EP-02-13).
  static const String finance = '/finance';
  static const String financeCreate = '/finance/create';

  /// Escrow screens (EP-02-14).
  static const String escrow = '/finance/escrow';
  static const String escrowDetail = '/finance/escrow/:id';

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
