import 'package:hivorr/core/api/auth/access_token_provider.dart';

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
