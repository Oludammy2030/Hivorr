import 'package:hivorr/core/authentication/auth_config.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
import 'package:hivorr/core/authentication/services/supabase_auth_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:hivorr/core/authentication/auth_config.dart';
export 'package:hivorr/core/authentication/guards/auth_guard.dart';
export 'package:hivorr/core/authentication/models/auth_credentials.dart';
export 'package:hivorr/core/authentication/models/auth_session.dart';
export 'package:hivorr/core/authentication/providers/auth_provider.dart';
export 'package:hivorr/core/authentication/services/auth_service.dart';
export 'package:hivorr/core/authentication/services/supabase_auth_service.dart';
export 'package:hivorr/core/authentication/state/auth_status.dart';

/// Fully wired authentication layer returned to the bootstrap (EP-01-15).
class AuthLayer {
  const AuthLayer({required this.service, required this.provider});

  /// The authentication service (single session source).
  final AuthService service;

  /// The app-wide auth provider.
  final AuthProvider provider;
}

/// Wires the authentication framework.
///
/// Constructs [SupabaseAuthService] + [AuthProvider] from the shared Supabase
/// client. Intentionally does **not** modify `main.dart`/`app.dart` — EP-01-15
/// calls this during bootstrap (EP-01-09 §5.7).
AuthLayer initializeAuth({
  required GoTrueClient authClient,
  required SupabaseClient supabaseClient,
  required AuthConfig config,
}) {
  final AuthService service = SupabaseAuthService(
    authClient: authClient,
    supabaseClient: supabaseClient,
    config: config,
  );
  return AuthLayer(
    service: service,
    provider: AuthProvider(service: service),
  );
}
