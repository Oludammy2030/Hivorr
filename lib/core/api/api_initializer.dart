import 'package:dio/dio.dart';

import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/core/api/api_client/api_client_factory.dart';
import 'package:hivorr/core/api/api_client/auth_interceptor.dart';
import 'package:hivorr/core/api/api_client/error_interceptor.dart';
import 'package:hivorr/core/api/api_client/logging_interceptor.dart';
import 'package:hivorr/core/api/api_client/retry_interceptor.dart';
import 'package:hivorr/core/api/api_config.dart';
import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/api/logging/api_log_sink.dart';
import 'package:hivorr/core/api/supabase/supabase_initializer.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Holds the fully wired API layer artifacts.
///
/// Returned by [ApiInitializer.initializeApi] so consumers (repositories,
/// bootstrap) obtain the configured [dio] and [supabaseClient] together.
class ApiLayer {
  const ApiLayer({
    required this.dio,
    required this.supabaseClient,
    required this.tokenProvider,
    required this.exceptionMapper,
  });

  /// The configured singleton [Dio] instance.
  final Dio dio;

  /// The initialized Supabase client.
  final SupabaseClient supabaseClient;

  /// The active access-token provider.
  final AccessTokenProvider tokenProvider;

  /// Mapper used to normalize transport failures.
  final ApiExceptionMapper exceptionMapper;
}

/// Top-level entrypoint that wires the API layer.
///
/// Initializes Supabase, builds the singleton [Dio] with the ordered
/// interceptor chain (auth → logging → retry → error), and returns an
/// [ApiLayer]. `main.dart`/bootstrap is **not** modified by this task; the
/// initializer is exported for EP-01-15 to call (EP-01-07 §5.8).
///
/// EP-01-15 bootstrap should obtain the [EnvironmentConfig] from the
/// application configuration façade: `ApiInitializer.initializeApi(
/// appConfig.environmentConfig)`.
class ApiInitializer {
  const ApiInitializer._();

  /// Initializes the full API layer from the validated [config].
  ///
  /// The [config] is sourced exclusively from the EP-01-03
  /// [EnvironmentConfig] contract (URL + public anon key). Supabase is
  /// initialized first; the Dio chain is then assembled and returned.
  static Future<ApiLayer> initializeApi(EnvironmentConfig config) async {
    final supabaseClient = await SupabaseInitializer.initialize(config);
    final apiConfig = ApiConfig.forEnvironment(config.environment);

    final tokenProvider = const SupabaseAccessTokenProvider();
    final logSink = const DeveloperLogSink('hivorr.api');
    final exceptionMapper = const ApiExceptionMapper();

    final auth = AuthInterceptor(tokenProvider: tokenProvider);
    final logging = LoggingInterceptor(logSink: logSink);
    final error = ErrorInterceptor(exceptionMapper: exceptionMapper);

    final dio = ApiClientFactory.create(
      baseUrl: config.supabaseConfig.url,
      config: apiConfig,
      interceptors: const <Interceptor>[],
    );

    final retry = RetryInterceptor(
      dio: dio,
      retryPolicy: const RetryPolicy(),
      tokenProvider: tokenProvider,
      maxRetries: apiConfig.maxRetries,
      baseDelay: apiConfig.baseRetryDelay,
      maxDelay: apiConfig.maxRetryDelay,
    );

    dio.interceptors.addAll(<Interceptor>[auth, logging, retry, error]);

    return ApiLayer(
      dio: dio,
      supabaseClient: supabaseClient,
      tokenProvider: tokenProvider,
      exceptionMapper: exceptionMapper,
    );
  }
}
