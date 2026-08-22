import 'dart:async';

// ignore_for_file: prefer_initializing_formals
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/auth_config.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/models/auth_session.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
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
  })  : _authClient = authClient,
        _supabaseClient = supabaseClient,
        _config = config;

  final GoTrueClient _authClient;
  final SupabaseClient _supabaseClient;
  final AuthConfig _config;

  final StreamController<AuthStatus> _statusController =
      StreamController<AuthStatus>.broadcast();

  AuthStatus _status = AuthStatus.initial;
  String? _currentEntityId;
  String? _provisionedUserId;
  StreamSubscription<AuthState>? _subscription;
  bool _initialized = false;

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
  Stream<AuthStatus> get onStatusChanged => _statusController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final Session? session = _authClient.currentSession;
    if (session != null && session.user.id.isNotEmpty) {
      _applyAuthenticated(session.user.id);
      // Best-effort: ensure the entity exists without blocking startup.
      unawaited(_provisionIfNeeded(session.user.id, rethrowOnError: false));
    } else {
      _applyStatus(AuthStatus.unauthenticated, null);
    }

    _subscription = _authClient.onAuthStateChange.listen(_handleAuthState);
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
      await _supabaseClient
          .from('entities')
          .upsert(<String, dynamic>{'id': user.id});
      await _supabaseClient.rpc<void>(
        'entity_roles_activate',
        params: <String, dynamic>{'p_role': 'consumer'},
      );
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  AuthResult _handleAuthResponse(AuthResponse response) {
    final Session? session = response.session;
    if (session == null || session.user.id.isEmpty) {
      final AuthStatus status = _config.emailConfirmationRequired
          ? AuthStatus.awaitingEmailConfirmation
          : AuthStatus.unauthenticated;
      _applyStatus(status, null);
      return AuthResult(status: status);
    }
    _applyAuthenticated(session.user.id);
    unawaited(_provisionIfNeeded(session.user.id, rethrowOnError: false));
    return AuthResult(
      status: AuthStatus.authenticated,
      session: _toAuthSession(session),
    );
  }

  void _handleAuthState(AuthState state) {
    final Session? session = state.session;
    final bool hasSession =
        session != null && session.user.id.isNotEmpty;

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
      case AuthChangeEvent.passwordRecovery:
        if (hasSession) {
          _applyAuthenticated(session.user.id);
        } else {
          _applyStatus(AuthStatus.unauthenticated, null);
        }
      default:
        if (hasSession) {
          _applyAuthenticated(session.user.id);
        } else {
          _applyStatus(AuthStatus.unauthenticated, null);
        }
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
      final String? status = error.statusCode;
      final ApiExceptionKind kind = switch (status) {
        '401' => ApiExceptionKind.auth,
        '403' => ApiExceptionKind.forbidden,
        '400' || '422' => ApiExceptionKind.validation,
        _ => ApiExceptionKind.unknown,
      };
      return ApiException(
        kind: kind,
        message: _safeMessage(kind),
        code: status,
      );
    }
    return const ApiException(
      kind: ApiExceptionKind.unknown,
      message: 'An unexpected authentication error occurred.',
    );
  }

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
