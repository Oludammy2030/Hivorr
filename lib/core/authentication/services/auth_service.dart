import 'dart:async';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/models/auth_session.dart';
import 'package:hivorr/core/authentication/models/registration_identity.dart';
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

  /// Whether the active session is a password-recovery session
  /// ([AuthStatus.recovery]).
  ///
  /// Single-purpose: it only empowers [updatePassword] and is consumed by the
  /// route guard to confine the user to the reset door. The default mirrors
  /// [status] so fakes that set status directly stay correct.
  bool get isRecoverySession => status == AuthStatus.recovery;

  /// A failed password-recovery deep-link exchange surfaced at bootstrap —
  /// i.e. an expired, invalid, or already-used recovery `code` — or `null`
  /// when no recovery callback landed (or the exchange succeeded).
  ///
  /// Read by the reset screen to render the "request a new link" guidance
  /// instead of a broken password form.
  ApiException? get recoveryCallbackError;

  /// Stream of [AuthStatus] changes (subscribe once; broadcast).
  Stream<AuthStatus> get onStatusChanged;

  /// Registers a new identity and returns the resulting status.
  ///
  /// When [identity] is provided, basic account identity (first/middle/last,
  /// displayName, phone) is staged via GoTrue `user_metadata` so the OTP gap
  /// (no JWT) does not lose data; hydrated post-verification into
  /// `entity_profiles`.
  Future<AuthResult> signUp(AuthCredentials credentials);

  /// Registers with staged identity; default delegates to [signUp].
  Future<AuthResult> signUpWithIdentity(RegistrationIdentity identity) =>
      signUp(AuthCredentials(email: identity.email, password: identity.password));

  /// Sends a one-time verification code to [email] (email-OTP sign-in).
  ///
  /// Used by the verification gate for an identity that already exists
  /// [AuthStatus.awaitingEmailConfirmation]. [createIfMissing] keeps the
  /// registration single-purpose: account creation happens in [signUp], never
  /// through a code send.
  Future<void> sendEmailVerificationOtp(
    String email, {
    bool createIfMissing = false,
  });

  /// Verifies the code delivered to [email] and activates the session.
  ///
  /// When [newPassword] is provided it is assigned to the just-verified identity
  /// after verification — registration keeps password and OTP as separate
  /// credentials.
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
    String? newPassword,
  });

  /// Authenticates an existing identity and returns the resulting status.
  Future<AuthResult> signIn(AuthCredentials credentials);

  /// Ends the active session.
  Future<void> signOut();

  /// Restores any persisted session and starts observing auth-state changes.
  Future<void> initialize();

  /// Idempotently provisions the entity row + default `consumer` role for the
  /// signed-in identity. Self-scoped by RLS to `auth.uid()` (EP-01-09 §5.3, §8).
  Future<void> ensureEntityExists();

  /// Sends a password-reset (recovery) email to [email]; the reset deep link
  /// carries the recovery session used by [updatePassword].
  ///
  /// The embedded link targets [AuthConfig.recoveryRedirectUrl] (the
  /// `/reset-password` landing page), which GoTrue allow-lists per project.
  Future<void> requestPasswordReset(String email);

  /// Updates the active user's password.
  ///
  /// Empowering session is the recovery session issued by the reset deep link
  /// (see [isRecoverySession]). Fail-closed without one: an authenticated
  /// user's password is never changed outside a recovery flow.
  Future<void> updatePassword(String newPassword);

  /// Releases the auth-state subscription and status stream.
  ///
  /// Called by the bootstrap on teardown; not required for the normal app
  /// lifetime.
  Future<void> dispose();
}
