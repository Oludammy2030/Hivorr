import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/models/auth_session.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';

/// App-wide authentication state exposed to the widget tree.
///
/// Wraps an [AuthService], mirrors its [AuthStatus] via the status stream, and
/// surfaces failures as a single [ApiException]. No Supabase/Dio imports beyond
/// the injected service (EP-01-09 §5.5).
class AuthProvider extends ChangeNotifier {
  /// Creates the provider bound to [service].
  AuthProvider({required this.service}) {
    service.onStatusChanged.listen((AuthStatus status) {
      _status = status;
      _currentEntityId = service.currentEntityId;
      notifyListeners();
    });
  }

  /// The authentication service backing this provider.
  final AuthService service;

  AuthStatus _status = AuthStatus.initial;
  String? _currentEntityId;
  ApiException? _error;

  /// Current lifecycle state.
  AuthStatus get status => _status;

  /// The active entity id, if [status] is [AuthStatus.authenticated].
  String? get currentEntityId => _currentEntityId;

  /// The latest error, if the last operation failed (EP-01-09 §2, §9).
  ApiException? get lastError => _error;

  /// The stable platform code of the latest error (e.g.
  /// `user_already_exists`, `email_not_confirmed`), when available.
  String? get lastErrorCode => _error?.code;

  /// Token-free view of the active session, or `null` when unauthenticated.
  AuthSession? get currentSession => service.currentSession;

  /// Whether a valid session is currently active.
  bool get isSignedIn => _status == AuthStatus.authenticated;

  /// Restores any persisted session and begins observing auth changes.
  Future<void> initialize() async {
    await service.initialize();
    _syncFromService();
  }

  /// Registers a new identity.
  Future<void> signUp(AuthCredentials credentials) =>
      _run(() => service.signUp(credentials));

  /// Sends a one-time verification code to [email] (DEV email-OTP).
  Future<void> sendEmailVerificationOtp(String email) =>
      _run(() => service.sendEmailVerificationOtp(email));

  /// Verifies the code delivered to [email] and activates the session.
  ///
  /// The registration password is assigned at account creation ([signUp]), so
  /// no additional credential is carried through the verification gate.
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) =>
      _run(() => service.verifyEmailOtp(
            email: email,
            code: code,
          ));

  /// Authenticates an existing identity.
  Future<void> signIn(AuthCredentials credentials) =>
      _run(() => service.signIn(credentials));

  /// Ends the active session.
  Future<void> signOut() => _run(() => service.signOut());

  /// Sends a password-reset (recovery) email for [email].
  Future<void> requestPasswordReset(String email) =>
      _run(() => service.requestPasswordReset(email));

  /// Updates the active user's password (recovery-session empowered).
  Future<void> updatePassword(String newPassword) =>
      _run(() => service.updatePassword(newPassword));

  void _syncFromService() {
    _status = service.status;
    _currentEntityId = service.currentEntityId;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _error = null;
    notifyListeners();
    try {
      await action();
      _syncFromService();
    } on ApiException catch (e) {
      _error = e;
      _status = service.status;
      _currentEntityId = service.currentEntityId;
      notifyListeners();
    }
  }
}
