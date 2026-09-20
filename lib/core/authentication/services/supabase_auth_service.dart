import 'dart:async';

// ignore_for_file: prefer_initializing_formals
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/auth_config.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/models/auth_session.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
import 'package:hivorr/core/authentication/services/clear_auth_url_parameters.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed implementation of [AuthService].
///
/// Uses the injected [authClient] for all auth operations and [supabaseClient]
/// for self-scoped entity provisioning. Never constructs its own Supabase/Dio
/// client — the session is the single instance shared with the EP-01-07 API
/// layer (EP-01-09 §5.3). All failures normalize to [ApiException].
class SupabaseAuthService implements AuthService {
  SupabaseAuthService({
    required GoTrueClient authClient,
    required SupabaseClient supabaseClient,
    required AuthConfig config,
    Uri Function()? callbackUriResolver,
  }) : _authClient = authClient,
       _supabaseClient = supabaseClient,
       _config = config,
       _callbackUriResolver = callbackUriResolver ?? _defaultCallbackUri;

  /// The Supabase instance performing the recovery exchange, so this service
  /// and the EP-01-07 API layer share one network session (EP-01-09 §5.3).
  final GoTrueClient _authClient;
  final SupabaseClient _supabaseClient;
  final AuthConfig _config;

  /// Resolves the current page URL at recovery-callback handling time.
  ///
  /// Injected for tests; defaults to [Uri.base] (the browser URL on Web).
  final Uri Function() _callbackUriResolver;

  /// The recovery deep link must end on the Web client; non-Web builds never
  /// observe a `code` callback, so the resolver is only exercised on Web.
  static Uri _defaultCallbackUri() => Uri.base;

  final StreamController<AuthStatus> _statusController =
      StreamController<AuthStatus>.broadcast();

  AuthStatus _status = AuthStatus.initial;
  String? _currentEntityId;
  String? _provisionedUserId;
  StreamSubscription<AuthState>? _subscription;
  bool _initialized = false;

  /// A failed recovery deep-link exchange (expired/invalid/already-used code)
  /// surfaced at bootstrap, or `null` when nothing landed or it succeeded.
  ApiException? _lastRecoveryError;

  @override
  AuthStatus get status => _status;

  @override
  String? get currentEntityId => _currentEntityId;

  @override
  AuthSession? get currentSession {
    final Session? session = _authClient.currentSession;
    return session == null ? null : _toAuthSession(session);
  }

  @override
  bool get isSignedIn => _status == AuthStatus.authenticated;

  @override
  bool get isRecoverySession => _status == AuthStatus.recovery;

  @override
  ApiException? get recoveryCallbackError => _lastRecoveryError;

  @override
  Stream<AuthStatus> get onStatusChanged => _statusController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    // Consume a password-recovery callback from the boot URL before restoring
    // the persisted session: the exchange is single-use and must win over any
    // stale persisted session (which is also why restore is skipped once a
    // callback was handled).
    final bool recoveryCallbackHandled = await _consumeRecoveryCallbackIfPresent();
    if (!recoveryCallbackHandled) {
      final Session? session = _authClient.currentSession;
      if (session != null && session.user.id.isNotEmpty) {
        _applyAuthenticated(session.user.id);
        // Best-effort: ensure the entity exists without blocking startup.
        unawaited(_provisionIfNeeded(session.user.id, rethrowOnError: false));
      } else {
        _applyStatus(AuthStatus.unauthenticated, null);
      }
    }

    _subscription = _authClient.onAuthStateChange.listen(_handleAuthState);
  }

  /// Exchanges a recovery `code` present in the current URL (PKCE deep link).
  ///
  /// Returns `true` when a recovery code was found (and therefore handled —
  /// success applies [AuthStatus.recovery], failure stays unauthenticated and
  /// stashes [recoveryCallbackError]).
  ///
  /// On success the recovery session is applied so the reset door is reachable
  /// even for accounts whose email is unverified (the recovery flow keeps
  /// `email_confirmed_at` untouched). The `code` parameter is always stripped
  /// from the address bar so a refresh never re-exchanges it.
  Future<bool> _consumeRecoveryCallbackIfPresent() async {
    final Uri callback = _callbackUriResolver();
    final String? code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      return false;
    }
    try {
      await _authClient.exchangeCodeForSession(code);
      clearAuthUrlParameters();
      _lastRecoveryError = null;
      final Session? session = _authClient.currentSession;
      if (session != null && session.user.id.isNotEmpty) {
        _applyStatus(AuthStatus.recovery, session.user.id);
      } else {
        _applyStatus(AuthStatus.unauthenticated, null);
      }
      return true;
    } on Object catch (e) {
      clearAuthUrlParameters();
      _lastRecoveryError = _mapError(e);
      _applyStatus(AuthStatus.unauthenticated, null);
      return true;
    }
  }

  @override
  Future<AuthResult> signUp(AuthCredentials credentials) async {
    try {
      final AuthResponse response = await _authClient.signUp(
        email: credentials.email,
        password: credentials.password,
      );
      return _handleAuthResponse(response);
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) async {
    try {
      final AuthResponse response = await _authClient.signInWithPassword(
        email: credentials.email,
        password: credentials.password,
      );
      return _handleAuthResponse(response);
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  @override
  /// Sends a one-time verification code to [email] (email-OTP sign-in).
  ///
  /// Used by the verification gate after an account was created via [signUp]:
  /// it targets an existing identity, so [createIfMissing] stays `false` — the
  /// code must never mint an account behind the gate's back.
  @override
  Future<void> sendEmailVerificationOtp(
    String email, {
    bool createIfMissing = false,
  }) async {
    try {
      await _authClient.signInWithOtp(
        email: email,
        shouldCreateUser: createIfMissing,
      );
      final AuthStatus status = _config.emailConfirmationRequired
          ? AuthStatus.awaitingEmailConfirmation
          : AuthStatus.unauthenticated;
      _applyStatus(status, null);
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
    String? newPassword,
  }) async {
    try {
      final AuthResponse response = await _authClient.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      _applySession(response);
      if (newPassword != null && newPassword.isNotEmpty) {
        await _authClient.updateUser(UserAttributes(password: newPassword));
      }
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authClient.signOut();
      // The `signedOut` event (if emitted) also updates status; this is the
      // authoritative local reset regardless of event ordering.
      _applyStatus(AuthStatus.unauthenticated, null);
      _provisionedUserId = null;
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _authClient.resetPasswordForEmail(
        email,
        redirectTo: _config.recoveryRedirectUrl,
      );
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    // Fail-closed: only a recovery session may change the password. A user
    // landing on /reset-password without a live recovery link gets the
    // "request a new link" guidance, never a silent read-write from a stale
    // session.
    if (!isRecoverySession) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message:
            'This reset link is invalid or has expired. Request a new one.',
        code: 'invalid_grant',
      );
    }
    try {
      await _authClient.updateUser(UserAttributes(password: newPassword));
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> ensureEntityExists() async {
    final User? user = _authClient.currentUser;
    if (user == null || user.id.isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.auth,
        message: 'Authentication required.',
        code: 'PLT001',
      );
    }
    try {
      await _supabaseClient.from('entities').upsert(<String, dynamic>{
        'id': user.id,
      });
      await _supabaseClient.rpc<void>(
        'entity_roles_activate',
        params: <String, dynamic>{'p_role': 'consumer'},
      );
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  AuthResult _handleAuthResponse(AuthResponse response) {
    _applySession(response);
    final Session? session = response.session;
    if (session == null || session.user.id.isEmpty) {
      return AuthResult(status: _status);
    }
    return AuthResult(
      status: AuthStatus.authenticated,
      session: _toAuthSession(session),
    );
  }

  /// Applies an authenticated session — or the awaiting-confirmation state when
  /// the response carries none — and schedules entity provisioning.
  void _applySession(AuthResponse response) {
    final Session? session = response.session;
    if (session == null || session.user.id.isEmpty) {
      final AuthStatus status = _config.emailConfirmationRequired
          ? AuthStatus.awaitingEmailConfirmation
          : AuthStatus.unauthenticated;
      _applyStatus(status, null);
      return;
    }
    _applyAuthenticated(session.user.id);
    unawaited(_provisionIfNeeded(session.user.id, rethrowOnError: false));
  }

  void _handleAuthState(AuthState state) {
    final Session? session = state.session;
    final bool hasSession = session != null && session.user.id.isNotEmpty;

    switch (state.event) {
      case AuthChangeEvent.signedOut:
        _applyStatus(AuthStatus.unauthenticated, null);
        _provisionedUserId = null;
      case AuthChangeEvent.signedIn:
        if (hasSession) {
          _applyAuthenticated(session.user.id);
          unawaited(_provisionIfNeeded(session.user.id, rethrowOnError: false));
        } else {
          _applyStatus(AuthStatus.unauthenticated, null);
        }
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        if (hasSession) {
          _applyAuthenticated(session.user.id);
        } else {
          _applyStatus(AuthStatus.unauthenticated, null);
        }
      case AuthChangeEvent.passwordRecovery:
        // The recovery deep link issued a session; it only empowers the reset
        // door until [updatePassword] completes.
        _applyRecoveryOrUnauthenticated(session);
      default:
        if (hasSession) {
          _applyAuthenticated(session.user.id);
        } else {
          _applyStatus(AuthStatus.unauthenticated, null);
        }
    }
  }

  void _applyRecoveryOrUnauthenticated(Session? session) {
    if (session != null && session.user.id.isNotEmpty) {
      _applyStatus(AuthStatus.recovery, session.user.id);
    } else {
      _applyStatus(AuthStatus.unauthenticated, null);
    }
  }

  Future<void> _provisionIfNeeded(
    String userId, {
    required bool rethrowOnError,
  }) async {
    if (_provisionedUserId == userId) {
      return;
    }
    try {
      await ensureEntityExists();
      _provisionedUserId = userId;
    } on Object catch (e) {
      if (rethrowOnError) {
        throw _mapError(e);
      }
    }
  }

  void _applyAuthenticated(String userId) {
    _applyStatus(AuthStatus.authenticated, userId);
  }

  void _applyStatus(AuthStatus status, String? entityId) {
    _status = status;
    _currentEntityId = entityId;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  AuthSession _toAuthSession(Session session) => AuthSession(
    entityId: session.user.id,
    expiresAt: session.expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
    provider: session.user.appMetadata['provider'] as String?,
    email: session.user.email,
    isEmailConfirmed: session.user.emailConfirmedAt != null,
  );

  ApiException _mapError(Object error) {
    if (error is ApiException) {
      return error;
    }
    if (error is PostgrestException) {
      final String code = error.code ?? '';
      final ApiExceptionKind kind = switch (code) {
        'PLT001' => ApiExceptionKind.auth,
        'PLT002' => ApiExceptionKind.forbidden,
        'PLT003' => ApiExceptionKind.validation,
        'PLT004' => ApiExceptionKind.notFound,
        'PLT005' => ApiExceptionKind.conflict,
        _ => ApiExceptionKind.server,
      };
      return ApiException(
        kind: kind,
        message: _safeMessage(kind),
        code: code.isNotEmpty ? code : null,
      );
    }
    if (error is AuthException) {
      final String? code = (error.code != null && error.code!.isNotEmpty)
          ? error.code
          : null;
      final int? status = int.tryParse(error.statusCode ?? '');
      if (code != null) {
        return _mapAuthCode(code, status);
      }
      final ApiExceptionKind kind = switch (status) {
        401 => ApiExceptionKind.auth,
        403 => ApiExceptionKind.forbidden,
        400 || 422 => ApiExceptionKind.validation,
        _ => ApiExceptionKind.unknown,
      };
      return ApiException(
        kind: kind,
        message: _safeMessage(kind),
        code: code ?? status?.toString(),
      );
    }
    return const ApiException(
      kind: ApiExceptionKind.unknown,
      message: 'An unexpected authentication error occurred.',
    );
  }

  /// Maps a gotrue error code to a typed [ApiException].
  ///
  /// Distinct codes drive the account-lifecycle UX: an existing identity
  /// (`user_already_exists`), an unverified email on sign-in
  /// (`email_not_confirmed`), an expired/disabled code (`otp_expired`,
  /// `otp_disabled`), and provider rate limits all resolve to safe copy with a
  /// stable [ApiException.code] the screens can branch on.
  ///
  /// Supabase Auth conflates invalid, expired and already-used email OTPs into
  /// a single `otp_expired` code with message "Token has expired or is invalid"
  /// (see `supabase/auth` `internal/api/verify.go:verifyUserAndToken` and
  /// `verifyTokenHash` — both return `ErrorCodeOTPExpired` for `!isValid` and
  /// `isExpired`). `invalid_otp` is not emitted by modern GoTrue for
  /// `POST /auth/v1/verify` with `type=email` (checked against
  /// `gotrue-2.27.2` `ErrorCode` enum and server `errorcode.go`). To avoid
  /// misclassifying a typo as expiry (report: wrong OTP showed “expired”),
  /// `otp_expired` is now mapped to a combined, non-committal message that
  /// covers both cases without auto-invalidating the valid OTP. The stable
  /// `code` (`otp_expired`) is preserved so screens can still branch if needed,
  /// but the human message no longer claims expiry when it may be a mismatch.
  ApiException _mapAuthCode(String code, int? status) {
    final ApiExceptionKind kind = switch (code) {
      'user_already_exists' => ApiExceptionKind.conflict,
      'email_not_confirmed' ||
      'email_not_verified' ||
      'invalid_otp' => ApiExceptionKind.auth,
      'otp_expired' || 'otp_disabled' => ApiExceptionKind.validation,
      'invalid_grant' => ApiExceptionKind.validation,
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' ||
      'over_sms_send_rate_limit' => ApiExceptionKind.validation,
      'invalid_credentials' ||
      'wrong_password' ||
      'email_address_changed' => ApiExceptionKind.auth,
      'user_not_found' ||
      'user_has_active_session' ||
      'signup_disabled' => ApiExceptionKind.validation,
      _ => _safeKindForStatus(status),
    };
    final String message = switch (kind) {
      ApiExceptionKind.conflict => 'An account already exists with this '
          'email address. Please log in to continue.',
      ApiExceptionKind.auth => _emailAuthMessage(code),
      ApiExceptionKind.validation when code == 'otp_expired' =>
        'The code you entered is incorrect or has expired. Please check the code and try again. If it has expired, request a new code.',
      ApiExceptionKind.validation when code == 'otp_disabled' =>
        'Code verification is currently unavailable.',
      ApiExceptionKind.validation when code == 'invalid_grant' =>
        'This reset link is invalid or has expired. Request a new one.',
      ApiExceptionKind.validation when _isRateLimit(code) =>
        'Too many requests. Please wait a moment and try again.',
      _ => _safeMessage(kind),
    };
    return ApiException(
      kind: kind,
      message: message,
      code: code,
      statusCode: status,
    );
  }

  bool _isRateLimit(String code) =>
      code == 'over_request_rate_limit' ||
      code == 'over_email_send_rate_limit' ||
      code == 'over_sms_send_rate_limit';

  /// Extended-validation login failures keep a neutral, single message so the
  /// login form never leaks which part of the credentials was wrong.
  ///
  /// `invalid_otp` is retained for forward-compatibility (legacy clients) even
  /// though the current OTP verification endpoint emits `otp_expired` for
  /// mismatches. Its message is aligned with the `otp_expired` combined copy
  /// in [_mapAuthCode] to satisfy the “incorrect OTP” UX without claiming
  /// expiry.
  String _emailAuthMessage(String code) => switch (code) {
    'email_not_confirmed' ||
    'email_not_verified' => 'Your email address has not been verified yet.',
    'invalid_otp' => 'The code you entered is incorrect. Please check the code and try again.',
    _ => 'Invalid email or password.',
  };

  ApiExceptionKind _safeKindForStatus(int? status) => switch (status) {
    401 => ApiExceptionKind.auth,
    403 => ApiExceptionKind.forbidden,
    400 || 422 => ApiExceptionKind.validation,
    429 => ApiExceptionKind.validation,
    _ => ApiExceptionKind.unknown,
  };

  String _safeMessage(ApiExceptionKind kind) {
    switch (kind) {
      case ApiExceptionKind.auth:
        return 'Authentication required.';
      case ApiExceptionKind.forbidden:
        return 'Operation not permitted.';
      case ApiExceptionKind.validation:
        return 'Validation failed.';
      case ApiExceptionKind.notFound:
        return 'Resource not found.';
      case ApiExceptionKind.conflict:
        return 'Conflict with current state.';
      case ApiExceptionKind.server:
        return 'A server error occurred.';
      case ApiExceptionKind.network:
        return 'A network error occurred.';
      case ApiExceptionKind.timeout:
        return 'The request timed out.';
      case ApiExceptionKind.unknown:
        return 'An unexpected error occurred.';
    }
  }

  /// Releases the auth-state subscription and status stream.
  ///
  /// Called by the bootstrap (EP-01-15) on teardown; not required for the
  /// normal app lifetime.
  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    if (!_statusController.isClosed) {
      await _statusController.close();
    }
  }
}
