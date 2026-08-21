import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/api_client/auth_interceptor.dart';
import 'package:hivorr/core/api/api_client/error_interceptor.dart';
import 'package:hivorr/core/api/api_client/logging_interceptor.dart';
import 'package:hivorr/core/api/api_client/retry_interceptor.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';

import 'test_helpers.dart';

void main() {
  group('AuthInterceptor', () {
    test('attaches bearer token to authenticated routes', () async {
      final provider = FakeTokenProvider(token: 'abc');
      final adapter = StubAdapter((options) async => jsonBody(200));
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(AuthInterceptor(tokenProvider: provider));

      await dio.get<dynamic>('/secure');

      expect(adapter.captured.last.headers['Authorization'], 'Bearer abc');
    });

    test('skips auth for explicitly public paths', () async {
      final provider = FakeTokenProvider(token: 'abc');
      final adapter = StubAdapter((options) async => jsonBody(200));
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(
          tokenProvider: provider,
          publicPaths: <String>{'/health'},
        ),
      );

      await dio.get<dynamic>('/health');

      expect(
        adapter.captured.last.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('omits header when no token is available', () async {
      final provider = FakeTokenProvider();
      final adapter = StubAdapter((options) async => jsonBody(200));
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(AuthInterceptor(tokenProvider: provider));

      await dio.get<dynamic>('/secure');

      expect(
        adapter.captured.last.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('LoggingInterceptor', () {
    test('logs method and path without leaking the token', () async {
      final sink = RecordingLogSink();
      final adapter = StubAdapter((options) async => jsonBody(200));
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(LoggingInterceptor(logSink: sink));
      dio.interceptors.add(
        AuthInterceptor(tokenProvider: FakeTokenProvider(token: 'secret-token')),
      );

      await dio.get<dynamic>('/secure');

      final all = sink.messages.join('\n');
      expect(all, contains('GET /secure'));
      expect(all, isNot(contains('secret-token')));
      expect(all, isNot(contains('Bearer')));
    });
  });

  group('RetryInterceptor', () {
    test('retries transient 500 then succeeds', () async {
      var calls = 0;
      final adapter = StubAdapter((options) async {
        calls++;
        if (calls < 3) return jsonBody(500);
        return jsonBody(200);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          retryPolicy: const RetryPolicy(),
          tokenProvider: FakeTokenProvider(),
          maxRetries: 3,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      dio.interceptors.add(
        ErrorInterceptor(exceptionMapper: const ApiExceptionMapper()),
      );

      final response = await dio.get<dynamic>('/x');

      expect(response.statusCode, 200);
      expect(calls, 3);
    });

    test('gives up after maxRetries and normalizes to server error', () async {
      final adapter = StubAdapter((options) async => jsonBody(500));
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          retryPolicy: const RetryPolicy(),
          tokenProvider: FakeTokenProvider(),
          maxRetries: 2,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      dio.interceptors.add(
        ErrorInterceptor(exceptionMapper: const ApiExceptionMapper()),
      );

      Object? caught;
      try {
        await dio.get<dynamic>('/x');
      } on DioException catch (e) {
        caught = e;
      }

      expect(caught, isA<DioException>());
      final apiErr = (caught as DioException).error;
      expect(apiErr, isA<ApiException>());
      expect((apiErr as ApiException).kind, ApiExceptionKind.server);
      expect(apiErr.code, 'PLT999');
    });

    test('refreshes exactly once on 401 then normalizes to auth', () async {
      final provider = FakeTokenProvider(token: 't');
      final adapter = StubAdapter((options) async => jsonBody(401));
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          retryPolicy: const RetryPolicy(),
          tokenProvider: provider,
          maxRetries: 2,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      dio.interceptors.add(
        ErrorInterceptor(exceptionMapper: const ApiExceptionMapper()),
      );

      Object? caught;
      try {
        await dio.get<dynamic>('/x');
      } on DioException catch (e) {
        caught = e;
      }

      expect(provider.refreshCount, 1);
      final apiErr = (caught as DioException).error;
      expect(apiErr, isA<ApiException>());
      expect((apiErr as ApiException).kind, ApiExceptionKind.auth);
      expect(apiErr.code, 'PLT001');
    });
  });
}
