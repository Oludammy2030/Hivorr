import 'dart:async';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/models/auth_session.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';

/// Result of an authentication attempt.
class AuthResult {
  const AuthResult({required this.status, this.session});

  final AuthStatus status;
  final AuthSession? session;
}

/// Authentication & authorization gateway for the client.
///
/// Owns session lifecycle (sign up, sign in, sign out, restore) and exposes the
/// current entity identity. Token injection and 401-refresh are delegated to the
/// EP-01-07 API layer via the shared Supabase session (EP-01-09 §5.4). All
/// errors are surfaced as [ApiException] (EP-01-09 §12).
abstract class AuthService {
  /// Current authentication status.
  AuthStatus get status;

  /// The active entity id (`auth.users.id`), or `null` when unauthenticated.
  String? get currentEntityId;

  /// Token-free view of the active session, or `null` when unauthenticated.
  AuthSession? get currentSession;

  /// Whether a valid session is currently active.
  bool get isSignedIn;

  /// Stream of [AuthStatus] changes (subscribe once; broadcast).
  Stream<AuthStatus> get onStatusChanged;

  /// Registers a new identity and returns the resulting status.
  Future<AuthResult> signUp(AuthCredentials credentials);

  /// Authenticates an existing identity and returns the resulting status.
  Future<AuthResult> signIn(AuthCredentials credentials);

  /// Ends the active session.
  Future<void> signOut();

  /// Restores any persisted session and starts observing auth-state changes.
  Future<void> initialize();

  /// Idempotently provisions the entity row + default `consumer` role for the
  /// signed-in identity. Self-scoped by RLS to `auth.uid()` (EP-01-09 §5.3, §8).
  Future<void> ensureEntityExists();

  /// Releases the auth-state subscription and status stream.
  ///
  /// Called by the bootstrap on teardown; not required for the normal app
  /// lifetime.
  Future<void> dispose();
}
