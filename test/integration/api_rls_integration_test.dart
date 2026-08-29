import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/environments/environment_loader.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/api/api_client/auth_interceptor.dart';
import 'package:hivorr/core/api/api_client/error_interceptor.dart';
import 'package:hivorr/core/api/api_client/logging_interceptor.dart';
import 'package:hivorr/core/api/api_client/retry_interceptor.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';

import '../support/factories/mock_api_service_factory.dart';
import '../support/fakes/fake_api.dart';
import '../support/matchers/api_matchers.dart';

/// Integration validation for the API request pipeline with zero-trust / RLS
/// enforcement (EP-01-20 Validation Point 2, plan §5.4).
///
/// Composes the REAL EP-01-07 interceptors (`AuthInterceptor`,
/// `RetryInterceptor`, `LoggingInterceptor`, `ErrorInterceptor`) and the real
/// `ApiExceptionMapper` with the EP-01-19 `MockApiServiceFactory` and fakes.
/// No interceptor or mapper is faked.
void main() {
  group('API + RLS integration (§5.4)', () {
    // ── Scenario 1: authenticated request injects token & returns data ──
    test('authenticated request attaches bearer token and returns mapped '
        'response', () async {
      // Real AuthInterceptor + a scripted adapter to capture outgoing headers.
      final tokenProvider = FakeTokenProvider(token: 'tok');
      final captureAdapter = StubAdapter(
        (RequestOptions options) async => jsonBody(200, body: '{"ok":true}'),
      );
      final captureDio = Dio()..httpClientAdapter = captureAdapter;
      captureDio.interceptors.add(
        AuthInterceptor(tokenProvider: tokenProvider),
      );

      await captureDio.get<dynamic>('/secure');

      expect(
        captureAdapter.captured.last.headers['Authorization'],
        'Bearer tok',
      );

      // The same composition through the factory yields a typed response.
      final service = MockApiServiceFactory.createService(
        accessToken: 'tok',
        enableAuthInterceptor: true,
        responses: const <ScriptedResponse>[
          ScriptedResponse(path: '/secure', body: '{"ok":true}'),
        ],
      ) as TestApiService;

      final dynamic result = await service.getJson('/secure');
      final Map<String, dynamic> body = result as Map<String, dynamic>;
      expect(body['ok'], isTrue);
    });

    // ── Scenario 2: unauthenticated request denied (401 -> auth, no header) ──
    test('unauthenticated request is denied and omits the auth header', ()
        async {
      // No token available -> real AuthInterceptor must not attach a header.
      final noTokenProvider = FakeTokenProvider();
      final noHeaderAdapter = StubAdapter(
        (RequestOptions options) async => jsonBody(401),
      );
      final noHeaderDio = Dio()..httpClientAdapter = noHeaderAdapter;
      noHeaderDio.interceptors.add(
        AuthInterceptor(tokenProvider: noTokenProvider),
      );
      // 401 is expected here; accept it so we can assert on the captured
      // request headers rather than letting Dio throw on the status code.
      noHeaderDio.options.validateStatus = (_) => true;

      await noHeaderDio.get<dynamic>('/secure');

      expect(
        noHeaderAdapter.captured.last.headers.containsKey('Authorization'),
        isFalse,
      );

      // A 401 from the server is normalized to a typed auth ApiException.
      final dio = MockApiServiceFactory.create(
        accessToken: null,
        enableAuthInterceptor: true,
        responses: const <ScriptedResponse>[
          ScriptedResponse(path: '/secure', statusCode: 401, body: '{}'),
        ],
      );
      dio.interceptors.add(
        ErrorInterceptor(exceptionMapper: const ApiExceptionMapper()),
      );

      Object? caught;
      try {
        await dio.get<dynamic>('/secure');
      } on DioException catch (e) {
        caught = e;
      }

      expect(caught, isA<DioException>());
      expect(
        (caught as DioException).error,
        isApiException(kind: ApiExceptionKind.auth),
      );
    });

    // ── Scenario 3: error normalization across status codes ──
    test('error responses are normalized to the correct ApiException kind', ()
        async {
      final dio = MockApiServiceFactory.create(
        enableRetryInterceptor: true,
        responses: const <ScriptedResponse>[
          ScriptedResponse(path: '/bad', statusCode: 400, body: '{}'),
          ScriptedResponse(path: '/forbidden', statusCode: 403, body: '{}'),
          ScriptedResponse(path: '/missing', statusCode: 404, body: '{}'),
          ScriptedResponse(path: '/server', statusCode: 500, body: '{}'),
        ],
      );
      dio.interceptors.add(
        ErrorInterceptor(exceptionMapper: const ApiExceptionMapper()),
      );

      final Map<String, ApiExceptionKind> expectations =
          <String, ApiExceptionKind>{
        '/bad': ApiExceptionKind.validation,
        '/forbidden': ApiExceptionKind.forbidden,
        '/missing': ApiExceptionKind.notFound,
        '/server': ApiExceptionKind.server,
      };

      for (final MapEntry<String, ApiExceptionKind> entry
          in expectations.entries) {
        Object? caught;
        try {
          await dio.get<dynamic>(entry.key);
        } on DioException catch (e) {
          caught = e;
        }

        expect(caught, isA<DioException>(), reason: 'expected failure for '
            '${entry.key}');
        expect(
          (caught as DioException).error,
          isApiException(kind: entry.value),
          reason: 'status ${entry.key} should map to ${entry.value}',
        );
      }
    });

    // ── Scenario 4: retry on transient failure ──
    test('retries transient 500 failures then succeeds', () async {
      var attempts = 0;
      final logSink = RecordingLogSink();
      final adapter = StubAdapter((RequestOptions options) async {
        attempts++;
        if (attempts < 3) return jsonBody(500);
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
      dio.interceptors.add(LoggingInterceptor(logSink: logSink));
      dio.interceptors.add(
        ErrorInterceptor(exceptionMapper: const ApiExceptionMapper()),
      );

      final Response<dynamic> response = await dio.get<dynamic>('/retry');

      expect(response.statusCode, 200);
      expect(attempts, 3);
      final List<String> requestLogs = logSink.messages
          .where((String m) => m.contains('REQUEST'))
          .toList();
      expect(requestLogs.length, 3);
    });

    // ── Scenario 5: environment-aware endpoints ──
    test('dev and staging configs load distinct, isolated Supabase URLs', () {
      final EnvironmentConfig devConfig = EnvironmentLoader.load(
        source: MapEnvironmentValueSource(<String, String>{
          AppConstants.envEnvironment: 'development',
          AppConstants.envSupabaseUrl: 'https://dev.hivorr.app',
          AppConstants.envSupabaseAnonKey:
              'devAnonKeyDevEnv00000000000000000000000000000000',
          AppConstants.envConfigSchemaVersion: '1',
        }),
      );

      final EnvironmentConfig stagingConfig = EnvironmentLoader.load(
        source: MapEnvironmentValueSource(<String, String>{
          AppConstants.envEnvironment: 'staging',
          AppConstants.envSupabaseUrl: 'https://staging.hivorr.app',
          AppConstants.envSupabaseAnonKey:
              'stagingAnonKeyStgEnv0000000000000000000000000',
          AppConstants.envConfigSchemaVersion: '1',
        }),
      );

      expect(devConfig.environment, AppEnvironment.development);
      expect(stagingConfig.environment, AppEnvironment.staging);
      expect(devConfig.supabaseConfig.url, 'https://dev.hivorr.app');
      expect(stagingConfig.supabaseConfig.url, 'https://staging.hivorr.app');

      // Distinct base URLs, and no cross-contamination of secrets/URLs.
      expect(
        devConfig.supabaseConfig.url,
        isNot(stagingConfig.supabaseConfig.url),
      );
      expect(
        devConfig.supabaseConfig.anonKey,
        isNot(stagingConfig.supabaseConfig.anonKey),
      );
      expect(devConfig.supabaseConfig.url, isNot(contains('staging')));
      expect(stagingConfig.supabaseConfig.url, isNot(contains('dev')));
      expect(devConfig.supabaseConfig.anonKey, isNot(contains('staging')));
      expect(stagingConfig.supabaseConfig.anonKey, isNot(contains('dev')));
    });
  });
}
