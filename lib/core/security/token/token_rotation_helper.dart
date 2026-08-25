import 'dart:async';

import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/secure_token_store.dart';

/// Consolidates token rotation for the client.
///
/// Reuses the EP-01-07 [AccessTokenProvider] refresh seam (never reimplements
/// auth refresh) and persists the rotated access token through
/// [SecureTokenStore]. Refresh is lock-guarded so concurrent callers share a
/// single refresh — preventing refresh storms on unreliable networks
/// (EP-01-10 §5.5).
class TokenRotationHelper {
  TokenRotationHelper({
    required this.accessTokenProvider,
    required this.tokenStore,
    this.expiryBuffer = const Duration(minutes: 5),
  });

  /// The access-token source/refresher (EP-01-07 seam).
  final AccessTokenProvider accessTokenProvider;

  /// Where rotated tokens are persisted.
  final SecureTokenStore tokenStore;

  /// How soon before expiry a proactive rotation is triggered.
  final Duration expiryBuffer;

  Future<String?>? _inflight;

  /// Rotates the token if [expiry] is within [expiryBuffer], or immediately
  /// when [expiry] is `null`. Returns the (possibly refreshed) current token.
  Future<String?> rotateIfNeeded(DateTime? expiry) {
    if (expiry != null && expiry.isAfter(DateTime.now().add(expiryBuffer))) {
      return Future<String?>.value(accessTokenProvider.currentToken);
    }
    return _refreshOnce();
  }

  /// Forces a refresh and persists the new access token.
  Future<String?> onRefresh() => _refreshOnce();

  Future<String?> _refreshOnce() {
    final Future<String?>? inflight = _inflight;
    if (inflight != null) {
      return inflight;
    }
    final Future<String?> pending = _doRefresh();
    _inflight = pending;
    // Clear the in-flight guard on both success and failure. Use `then` with an
    // error handler (rather than `whenComplete`) so the cleanup future never
    // re-propagates the refresh error as an unhandled future.
    unawaited(
      pending.then<void>(
        (_) => _inflight = null,
        onError: (Object _, StackTrace _) => _inflight = null,
      ),
    );
    return pending;
  }

  Future<String?> _doRefresh() async {
    final String? previous = accessTokenProvider.currentToken;
    String? newToken;
    try {
      newToken = await accessTokenProvider.refresh();
    } catch (error) {
      // Surface a typed, non-sensitive failure. No token is persisted, so there
      // is no partial/corrupt token state (EP-01-10 DoD: refresh failure).
      throw ApiException(
        kind: ApiExceptionKind.auth,
        message: 'Token rotation failed during refresh.',
        data: const <String, dynamic>{'reason': 'refresh_error'},
      );
    }
    if (newToken == null) {
      throw ApiException(
        kind: ApiExceptionKind.auth,
        message: 'Token rotation failed: refresh returned no token.',
        data: const <String, dynamic>{'reason': 'no_token'},
      );
    }
    // Avoid a redundant write when the session was already fresh.
    if (newToken != previous) {
      await tokenStore.writeAccessToken(newToken);
    }
    return newToken;
  }
}
