import 'package:hivorr/core/api/supabase/supabase_initializer.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supplies the current auth access token and refreshes the session.
///
/// Decouples interceptors from the concrete auth backend so EP-01-09 can
/// replace/augment token sourcing without modifying interceptors (EP-01-07 §5.7).
abstract class AccessTokenProvider {
  const AccessTokenProvider();

  /// Returns the current access token, or `null` if unauthenticated.
  String? get currentToken;

  /// Refreshes the session and returns the new access token, or `null`.
  Future<String?> refresh();
}

/// Default [AccessTokenProvider] backed by Supabase Auth.
///
/// Reads the active session token and triggers Supabase's own refresh — never
/// a hardcoded credential. Safe no-ops before Supabase is initialized.
class SupabaseAccessTokenProvider implements AccessTokenProvider {
  const SupabaseAccessTokenProvider();

  @override
  String? get currentToken {
    if (!SupabaseInitializer.isSupabaseInitialized) {
      return null;
    }
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  @override
  Future<String?> refresh() async {
    if (!SupabaseInitializer.isSupabaseInitialized) {
      return null;
    }
    final response = await Supabase.instance.client.auth.refreshSession();
    return response.session?.accessToken;
  }
}
