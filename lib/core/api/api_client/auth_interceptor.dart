import 'package:dio/dio.dart';

import 'package:hivorr/core/api/auth/access_token_provider.dart';

/// Injects the current auth access token into outbound requests.
///
/// Reads the token from an [AccessTokenProvider] (default Supabase-backed).
/// Routes explicitly marked public are skipped. Tokens are attached at
/// request time; never cached on the interceptor (EP-01-07 §5.4).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenProvider,
    this.publicPaths = const <String>{},
  });

  /// Source of the current access token.
  final AccessTokenProvider tokenProvider;

  /// Request paths that must not receive an auth header.
  final Set<String> publicPaths;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (publicPaths.contains(options.path)) {
      return handler.next(options);
    }
    final token = tokenProvider.currentToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
