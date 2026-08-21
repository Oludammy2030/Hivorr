import 'package:dio/dio.dart';

import 'package:hivorr/core/api/auth/access_token_provider.dart';

/// Decides whether a failure should be retried and how auth failures recover.
///
/// Retries idempotent transient failures (timeouts, connection errors, 5xx)
/// with exponential backoff + jitter, bounded by [maxRetries]. On `401` it
/// performs exactly one token refresh and a single retry; persistent `401`
/// is surfaced for normalization (EP-01-07 §5.4, §13).
class RetryPolicy {
  const RetryPolicy({
    this.retryOnTransient = true,
    this.retryOnServerError = true,
  });

  /// Whether transient (timeout/connection) failures are retried.
  final bool retryOnTransient;

  /// Whether 5xx server failures are retried.
  final bool retryOnServerError;

  /// Whether a [DioException] is eligible for a transient retry.
  bool shouldRetry(DioException exception) {
    final statusCode = exception.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
      return retryOnServerError;
    }
    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown =>
        retryOnTransient,
      DioExceptionType.badCertificate ||
      DioExceptionType.badResponse ||
      DioExceptionType.cancel =>
        false,
    };
  }
}

/// Interceptor that retries transient failures and recovers from `401`.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    required this.retryPolicy,
    required this.tokenProvider,
    required this.maxRetries,
    required this.baseDelay,
    required this.maxDelay,
  });

  /// The [Dio] instance used to reissue requests.
  final Dio dio;

  /// Retry eligibility policy.
  final RetryPolicy retryPolicy;

  /// Provider used to refresh the session on `401`.
  final AccessTokenProvider tokenProvider;

  /// Maximum number of transient/5xx retry attempts.
  final int maxRetries;

  /// Base delay for exponential backoff.
  final Duration baseDelay;

  /// Upper bound for a single backoff delay.
  final Duration maxDelay;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = _readAttempt(options);

    if (_isAuthFailure(err) && !_authRefreshed(options)) {
      options.extra[_authRefreshedKey] = true;
      await _refreshToken();
      return _reissue(options, handler);
    }

    if (retryPolicy.shouldRetry(err) && attempt < maxRetries) {
      options.extra[_retryCountKey] = attempt + 1;
      await Future<void>.delayed(_backoff(attempt + 1));
      return _reissue(options, handler);
    }

    handler.next(err);
  }

  Future<void> _reissue(
    RequestOptions options,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<void> _refreshToken() async {
    try {
      await tokenProvider.refresh();
    } on Object {
      // Refresh failures are intentionally swallowed; the reissued request
      // will carry the existing (stale) token and ultimately fail, which the
      // error interceptor normalizes. This avoids leaking refresh internals.
    }
  }

  Duration _backoff(int attempt) {
    final exponential = baseDelay * (1 << (attempt - 1));
    final capped = exponential > maxDelay ? maxDelay : exponential;
    final jitter = (capped.inMilliseconds * 0.25).round();
    final offset = jitter <= 0
        ? 0
        : (DateTime.now().microsecondsSinceEpoch % (2 * jitter)) - jitter;
    final total = capped.inMilliseconds + offset;
    return Duration(milliseconds: total < 0 ? 0 : total);
  }

  int _readAttempt(RequestOptions options) {
    final value = options.extra[_retryCountKey];
    return value is int ? value : 0;
  }

  bool _authRefreshed(RequestOptions options) {
    final value = options.extra[_authRefreshedKey];
    return value is bool && value;
  }

  bool _isAuthFailure(DioException err) => err.response?.statusCode == 401;

  static const String _retryCountKey = 'hivorr_api_retry_count';
  static const String _authRefreshedKey = 'hivorr_api_auth_refreshed';
}
