import 'dart:async';

import 'package:hivorr/core/authentication/services/supabase_auth_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a [User] with the minimal fields the auth framework reads.
User fakeUser(String id, {bool emailConfirmed = false}) => User(
  id: id,
  appMetadata: <String, dynamic>{},
  userMetadata: null,
  aud: 'authenticated',
  emailConfirmedAt: emailConfirmed ? DateTime.now().toIso8601String() : null,
  createdAt: DateTime.now().toIso8601String(),
);

/// Builds a [Session] with a non-JWT access token (expiry stays null).
Session fakeSession(String id, {bool emailConfirmed = false}) => Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: fakeUser(id, emailConfirmed: emailConfirmed),
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
  bool returnSessionOnVerify = true;
  bool returnSessionOnExchange = true;
  AuthException? nextError;
  AuthException? exchangeError;

  /// Controls the `email_confirmed_at` flag on the session produced by
  /// [signUp], [signInWithPassword] and [verifyOTP], so the service maps the
  /// confirmed/unconfirmed session correctly in widget and unit tests.
  bool emailConfirmedInSession = false;

  /// Email of the most recent [resetPasswordForEmail] call, if any.
  String? resetEmail;

  /// `redirectTo` argument of the most recent [resetPasswordForEmail] call.
  String? resetRedirectTo;

  /// Number of [resetPasswordForEmail] calls observed.
  int resetCallCount = 0;

  /// Code passed to the most recent [exchangeCodeForSession] call, if any.
  String? exchangedCode;

  /// Number of [exchangeCodeForSession] calls observed.
  int exchangeCallCount = 0;

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

  Map<String, dynamic>? lastSignUpData;

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
    lastSignUpData = data;
    if (returnSessionOnSignUp) {
      final User base = fakeUser('u1', emailConfirmed: emailConfirmedInSession);
      final User withMeta = data == null || data.isEmpty
          ? base
          : User(
              id: base.id,
              appMetadata: base.appMetadata,
              userMetadata: data,
              aud: base.aud,
              emailConfirmedAt: base.emailConfirmedAt,
              createdAt: base.createdAt,
              email: email,
            );
      _session = Session(
        accessToken: 'fake-access-token',
        tokenType: 'bearer',
        user: withMeta,
      );
      _seededUser = withMeta;
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
    _session = fakeSession('u1', emailConfirmed: emailConfirmedInSession);
    return AuthResponse(session: _session, user: _session!.user);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {
    _session = null;
  }

  /// Email passed to the most recent [signInWithOtp] call, if any.
  String? otpEmail;

  /// `shouldCreateUser` argument of the most recent [signInWithOtp] call.
  bool? otpShouldCreateUser;

  /// Number of [signInWithOtp] calls observed.
  int otpCallCount = 0;

  @override
  Future<void> signInWithOtp({
    String? email,
    String? phone,
    String? emailRedirectTo,
    bool? shouldCreateUser,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    if (nextError != null) {
      final AuthException e = nextError!;
      nextError = null;
      throw e;
    }
    otpCallCount++;
    otpEmail = email;
    otpShouldCreateUser = shouldCreateUser;
  }

  /// Token passed to the most recent [verifyOTP] call, if any.
  String? verifiedToken;

  /// Type of the most recent [verifyOTP] call.
  OtpType? verifiedType;

  /// Number of [verifyOTP] calls observed.
  int verifyCallCount = 0;

  @override
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    if (nextError != null) {
      final AuthException e = nextError!;
      nextError = null;
      throw e;
    }
    verifyCallCount++;
    verifiedToken = token;
    verifiedType = type;
    if (returnSessionOnVerify) {
      _session = fakeSession('u1', emailConfirmed: emailConfirmedInSession);
      return AuthResponse(session: _session, user: _session!.user);
    }
    return AuthResponse(session: null, user: null);
  }

  @override
  Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
    String? captchaToken,
  }) async {
    if (nextError != null) {
      final AuthException e = nextError!;
      nextError = null;
      throw e;
    }
    resetCallCount++;
    resetEmail = email;
    resetRedirectTo = redirectTo;
  }

  @override
  Future<AuthSessionUrlResponse> exchangeCodeForSession(String authCode) async {
    exchangeCallCount++;
    exchangedCode = authCode;
    if (exchangeError != null) {
      final AuthException e = exchangeError!;
      exchangeError = null;
      throw e;
    }
    final Session session = fakeSession(
      'u1',
      emailConfirmed: emailConfirmedInSession,
    );
    if (returnSessionOnExchange) {
      _session = session;
      emit(AuthChangeEvent.passwordRecovery, _session);
    }
    return AuthSessionUrlResponse(
      session: session,
      redirectType: AuthChangeEvent.passwordRecovery.name,
    );
  }

  /// Password submitted to the most recent [updateUser] call, if any.
  String? updatedPassword;

  @override
  Future<UserResponse> updateUser(
    UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    updatedPassword = attributes.password;
    return UserResponse.fromJson((_seededUser ?? fakeUser('u1')).toJson());
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
  }) => throw UnimplementedError('rpc() is not exercised in unit tests');
}

/// [SupabaseAuthService] whose [ensureEntityExists] is recorded (no network),
/// used to verify idempotent provisioning.
class FakeSupabaseAuthService extends SupabaseAuthService {
  FakeSupabaseAuthService({
    required super.authClient,
    required super.supabaseClient,
    required super.config,
    super.callbackUriResolver,
  });

  int provisionCallCount = 0;

  @override
  Future<void> ensureEntityExists() async {
    provisionCallCount++;
  }
}
