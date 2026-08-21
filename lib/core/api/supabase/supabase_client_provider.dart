import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/supabase/supabase_initializer.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Safe accessor for the initialized Supabase client.
///
/// Fails closed with [ApiInitializationException] (never a raw Supabase
/// assertion) when accessed before initialization. Exposes the active session
/// access token through the API layer's token provider contract
/// (EP-01-07 §5.3, §12).
class SupabaseClientProvider {
  const SupabaseClientProvider._();

  /// Returns the initialized [SupabaseClient].
  ///
  /// Throws [ApiInitializationException] if the API layer has not been
  /// initialized. The message never reveals configuration values.
  static SupabaseClient get client {
    if (!SupabaseInitializer.isSupabaseInitialized) {
      throw const ApiInitializationException(
        'Supabase client accessed before initialization.',
      );
    }
    return Supabase.instance.client;
  }

  /// The current session access token, or `null` if unauthenticated.
  static String? get currentAccessToken {
    if (!SupabaseInitializer.isSupabaseInitialized) {
      return null;
    }
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }
}
