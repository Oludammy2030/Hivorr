import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hivorr/core/api/api_client/auth_interceptor.dart';
import 'package:hivorr/core/api/api_client/logging_interceptor.dart';
import 'package:hivorr/core/api/api_client/retry_interceptor.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/api/logging/api_log_sink.dart';
import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_supabase.dart';

/// A single scripted HTTP response matched by method + path.
class ScriptedResponse {
  const ScriptedResponse({
    this.method = '*',
    required this.path,
    this.statusCode = 200,
    this.body = '{}',
    this.headers,
  });

  /// HTTP method to match (`'*'` matches any).
  final String method;

  /// Path (relative) or [RegExp] to match against [RequestOptions.path].
  final Pattern path;

  /// HTTP status code of the scripted response.
  final int statusCode;

  /// Response body: a [String] is used verbatim, any other value is JSON
  /// encoded.
  final Object body;

  /// Optional response headers.
  final Map<String, List<String>>? headers;
}

/// One-call factory for a fully configured, network-free [Dio] and a
/// [BaseApiService] built on top of it.
///
/// Uses the real EP-01-07 interceptors (`AuthInterceptor`, `RetryInterceptor`,
/// `LoggingInterceptor`) and the real [ApiExceptionMapper] — never fakes of
/// those (EP-01-19 Module Integration).
class MockApiServiceFactory {
  MockApiServiceFactory._();

  /// Creates a [Dio] wired with a [ScriptedAdapter] and optional interceptors.
  ///
  /// Unmatched requests throw a descriptive [StateError] so failures surface
  /// loudly instead of silently returning null.
  static Dio create({
    List<ScriptedResponse>? responses,
    String? accessToken,
    bool enableAuthInterceptor = false,
    bool enableRetryInterceptor = false,
    bool enableLoggingInterceptor = false,
    ApiLogSink? logSink,
  }) {
    final FakeTokenProvider tokenProvider = FakeTokenProvider(
      token: accessToken,
    );
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    dio.httpClientAdapter = ScriptedAdapter((RequestOptions options) async {
      final ScriptedResponse? match = _match(responses, options);
      if (match == null) {
        throw StateError(
          'No scripted response registered for ${options.method} '
          '${options.path}. Register a ScriptedResponse or a catch-all.',
        );
      }
      return jsonBody(match.statusCode, body: _encodeBody(match.body));
    });

    if (enableAuthInterceptor) {
      dio.interceptors.add(AuthInterceptor(tokenProvider: tokenProvider));
    }
    if (enableRetryInterceptor) {
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          retryPolicy: const RetryPolicy(),
          tokenProvider: tokenProvider,
          maxRetries: 3,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
    }
    if (enableLoggingInterceptor) {
      dio.interceptors.add(
        LoggingInterceptor(logSink: logSink ?? RecordingLogSink()),
      );
    }
    return dio;
  }

  /// Creates a [BaseApiService] with a scripted [Dio], a fake [SupabaseClient],
  /// and the real [ApiExceptionMapper].
  static BaseApiService createService({
    List<ScriptedResponse>? responses,
    String? accessToken,
    bool enableAuthInterceptor = false,
    bool enableRetryInterceptor = false,
    bool enableLoggingInterceptor = false,
    ApiLogSink? logSink,
    SupabaseClient? supabase,
  }) {
    final Dio dio = create(
      responses: responses,
      accessToken: accessToken,
      enableAuthInterceptor: enableAuthInterceptor,
      enableRetryInterceptor: enableRetryInterceptor,
      enableLoggingInterceptor: enableLoggingInterceptor,
      logSink: logSink,
    );
    return TestApiService(
      dio: dio,
      supabase: supabase ?? FakeSupabaseClient(),
      exceptionMapper: const ApiExceptionMapper(),
    );
  }

  static ScriptedResponse? _match(
    List<ScriptedResponse>? responses,
    RequestOptions options,
  ) {
    if (responses == null || responses.isEmpty) {
      return null;
    }
    for (final ScriptedResponse r in responses) {
      final bool methodOk = r.method == '*' ||
          r.method.toUpperCase() == options.method.toUpperCase();
      final bool pathOk = r.path is RegExp
          ? (r.path as RegExp).hasMatch(options.path)
          : r.path == options.path;
      if (methodOk && pathOk) {
        return r;
      }
    }
    return null;
  }

  static String _encodeBody(Object body) =>
      body is String ? body : jsonEncode(body);
}

/// Concrete [BaseApiService] exposed by [MockApiServiceFactory.createService]
/// with typed convenience wrappers that normalize failures to [ApiException].
class TestApiService extends BaseApiService {
  TestApiService({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
  });

  /// Performs a GET and returns the decoded response body.
  Future<dynamic> getJson(String path) =>
      invoke(() async => (await dio.get<dynamic>(path)).data);

  /// Performs a POST and returns the decoded response body.
  Future<dynamic> postJson(String path, {dynamic data}) =>
      invoke(() async => (await dio.post<dynamic>(path, data: data)).data);

  /// Performs a PUT and returns the decoded response body.
  Future<dynamic> putJson(String path, {dynamic data}) =>
      invoke(() async => (await dio.put<dynamic>(path, data: data)).data);

  /// Performs a DELETE and returns the decoded response body.
  Future<dynamic> deleteJson(String path) =>
      invoke(() async => (await dio.delete<dynamic>(path)).data);
}
