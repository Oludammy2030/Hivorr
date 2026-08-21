import 'package:hivorr/config/environments/environment_config.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes the Supabase client for the active environment.
///
/// Reads the endpoint and public anon key **only** from [EnvironmentConfig]
/// (EP-01-03 contract). Uses `publishableKey` to avoid the deprecated
/// `anonKey` parameter. Never reads compile-time variables directly.
/// Idempotent and guarded so repeated calls are safe (EP-01-07 §5.3).
class SupabaseInitializer {
  const SupabaseInitializer._();

  static bool _isInitialized = false;

  /// Whether the Supabase client has been initialized.
  static bool get isSupabaseInitialized => _isInitialized;

  /// Initializes Supabase from the validated [config].
  ///
  /// Returns the initialized [SupabaseClient]. If already initialized, the
  /// existing client is returned without re-initializing.
  static Future<SupabaseClient> initialize(EnvironmentConfig config) async {
    if (_isInitialized) {
      return Supabase.instance.client;
    }
    await Supabase.initialize(
      url: config.supabaseConfig.url,
      publishableKey: config.supabaseConfig.anonKey,
    );
    _isInitialized = true;
    return Supabase.instance.client;
  }
}
