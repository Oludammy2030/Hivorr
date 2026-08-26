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
}
