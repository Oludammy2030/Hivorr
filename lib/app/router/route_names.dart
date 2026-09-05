/// Compile-time route name constants (GoRouter route identifiers).
///
/// Use these instead of string literals to avoid typos and to enable
/// rename-safe navigation (e.g. `context.goNamed(RouteNames.profile)`).
abstract final class RouteNames {
  const RouteNames._();

  static const String home = 'home';
  static const String login = 'login';
  static const String signup = 'signup';
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';
  static const String profile = 'profile';
  static const String settings = 'settings';
  static const String publicProfile = 'public-profile';
  static const String publicStore = 'public-store';
  static const String verificationIdentity = 'verification-identity';
  static const String verificationStatus = 'verification-status';
  static const String tradeProofUpload = 'trade-proof-upload';
  static const String tradeVerificationStatus = 'trade-verification-status';
  static const String adminReviewQueue = 'admin-review-queue';

  /// Financial profile routes (EP-02-13).
  static const String finance = 'finance';
  static const String financeCreate = 'finance-create';

  /// Escrow routes (EP-02-14).
  static const String escrow = 'escrow';
  static const String escrowDetail = 'escrow-detail';

  /// KYC status + upgrade routes (EP-02-12).
  static const String kycStatus = 'kyc-status';
  static const String kycUpgrade = 'kyc-upgrade';
}
