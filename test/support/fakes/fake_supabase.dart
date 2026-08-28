import 'dart:async';

import 'package:hivorr/core/authentication/services/supabase_auth_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a [User] with the minimal fields the auth framework reads.
User fakeUser(String id) => User(
      id: id,
      appMetadata: <String, dynamic>{},
      userMetadata: null,
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

/// Builds a [Session] with a non-JWT access token (expiry stays null).
Session fakeSession(String id) => Session(
      accessToken: 'fake-access-token',
      tokenType: 'bearer',
      user: fakeUser(id),
    );

/// Controllable [GoTrueClient] for unit tests.
///
/// Mirrors only the surface the auth framework uses; auth operations return
/// canned [AuthResponse]s and state changes are driven by [seedSession] /
/// [emit]. No network is involved (EP-01-09 Testing Verification).
class FakeGoTrueClient extends GoTrueClient {
  FakeGoTrueClient() : super(autoRefreshToken: false);

  // Suppress the background auto-refresh timer so tests under fake_async don't
  // leak pending timers.
  @override
  Future<void> startAutoRefresh() async {}

  @override
  void stopAutoRefresh() {}

  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  Session? _session;
  User? _seededUser;
  bool returnSessionOnSignUp = true;
  AuthException? nextError;

  /// Plants a current session (e.g. a persisted cold-start session).
  void seedSession(Session session) => _session = session;

  /// Plants a signed-in user without a full session, for factory scaffolding.
  void seedUser(User user) => _seededUser = user;

  /// Pushes an auth-state event to listeners.
  void emit(AuthChangeEvent event, [Session? session]) =>
      _controller.add(AuthState(event, session));

  /// Closes the underlying event stream.
  Future<void> close() => _controller.close();

  @override
  User? get currentUser => _seededUser ?? _session?.user;

  @override
  Session? get currentSession => _session;

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    if (nextError != null) {
      final AuthException e = nextError!;
      nextError = null;
      throw e;
    }
    if (returnSessionOnSignUp) {
      _session = fakeSession('u1');
      return AuthResponse(session: _session, user: _session!.user);
    }
    return AuthResponse(session: null, user: null);
  }

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    if (nextError != null) {
      final AuthException e = nextError!;
      nextError = null;
      throw e;
    }
    _session = fakeSession('u1');
    return AuthResponse(session: _session, user: _session!.user);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {
    _session = null;
  }

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    if (_session == null) {
      throw const AuthException('No session to refresh.');
    }
    return AuthResponse(session: _session, user: _session!.user);
  }
}

/// [SupabaseClient] stub used only to satisfy the type in unit tests.
///
/// [SupabaseAuthService.ensureEntityExists] is either overridden in tests or
/// its failure is intentionally swallowed (best-effort provisioning), so these
/// methods are never exercised.
class FakeSupabaseClient extends SupabaseClient {
  FakeSupabaseClient()
      : super('https://example.supabase.co', 'public-anon-key');

  @override
  SupabaseQueryBuilder from(String table) =>
      throw UnimplementedError('from() is not exercised in unit tests');

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String functionName, {
    dynamic get,
    Map<String, dynamic>? params,
  }) =>
      throw UnimplementedError('rpc() is not exercised in unit tests');
}

/// [SupabaseAuthService] whose [ensureEntityExists] is recorded (no network),
/// used to verify idempotent provisioning.
class FakeSupabaseAuthService extends SupabaseAuthService {
  FakeSupabaseAuthService({
    required super.authClient,
    required super.supabaseClient,
    required super.config,
  });

  int provisionCallCount = 0;

  @override
  Future<void> ensureEntityExists() async {
    provisionCallCount++;
  }
}
