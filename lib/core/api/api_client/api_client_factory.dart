import 'package:dio/dio.dart';

import 'package:hivorr/core/api/api_config.dart';

/// Builds the singleton [Dio] instance for the API layer.
///
/// Configures timeouts from [ApiConfig] and attaches the supplied,
/// already-ordered interceptor chain. Callers must pass interceptors in the
/// required order: auth → logging → retry → error (EP-01-07 §5.2, §5.4).
class ApiClientFactory {
  const ApiClientFactory._();

  /// Creates a configured [Dio] with the provided [interceptors].
  static Dio create({
    required String baseUrl,
    required ApiConfig config,
    required List<Interceptor> interceptors,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: <String, String>{'Accept': 'application/json'},
      ),
    );
    dio.interceptors.addAll(interceptors);
    return dio;
  }
}
