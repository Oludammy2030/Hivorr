import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/authentication/authentication.dart';

export 'fake_supabase.dart';

/// Inert [AuthService] for bootstrap tests.
class FakeAuthService implements AuthService {
  @override
  AuthStatus get status => AuthStatus.unauthenticated;

  @override
  String? get currentEntityId => null;

  @override
  AuthSession? get currentSession => null;

  @override
  bool get isSignedIn => false;

  @override
  Stream<AuthStatus> get onStatusChanged =>
      const Stream<AuthStatus>.empty();

  @override
  Future<AuthResult> signUp(AuthCredentials credentials) async =>
      AuthResult(status: AuthStatus.unauthenticated);

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) async =>
      AuthResult(status: AuthStatus.unauthenticated);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> ensureEntityExists() async {}

  @override
  Future<void> dispose() async {}
}

/// [AuthProvider] whose [status] is directly controllable for routing tests.
class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider({AuthStatus initialStatus = AuthStatus.unauthenticated})
      : _status = initialStatus,
        super(service: FakeAuthService());

  AuthStatus _status;

  @override
  AuthStatus get status => _status;

  @override
  bool get isSignedIn => _status == AuthStatus.authenticated;

  /// Drives the provider's reported status (and notifies listeners).
  void setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
}

/// Controllable [AccessTokenProvider] for unit tests.
class FakeAccessTokenProvider implements AccessTokenProvider {
  FakeAccessTokenProvider({
    this.currentToken,
    this.nextToken = 'refreshed-token',
    this.refreshDelay = Duration.zero,
    this.refreshError,
  });

  @override
  String? currentToken;

  /// Token returned by [refresh]; `null` simulates a failed/no-token refresh.
  final String? nextToken;

  /// Simulated network latency for [refresh].
  final Duration refreshDelay;

  /// When set, [refresh] throws this instead of returning a token.
  final Object? refreshError;

  int refreshCalls = 0;

  @override
  Future<String?> refresh() async {
    refreshCalls++;
    if (refreshError != null) {
      throw refreshError!;
    }
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    currentToken = nextToken;
    return nextToken;
  }
}
