import 'package:go_router/go_router.dart';

/// Query-parameter contract shared by the pre-onboarding doors (entry
/// architecture §4): the original destination preserved as `?next=` so the
/// invite/SEO flow resumes after sign-up (or the one-time intro).
abstract final class EntryQuery {
  const EntryQuery._();

  /// The key that carries the preserved destination.
  static const String nextKey = 'next';

  /// Reads the preserved destination from [state], or `null` when absent.
  static String? nextFrom(GoRouterState state) =>
      state.uri.queryParameters[nextKey];
}
