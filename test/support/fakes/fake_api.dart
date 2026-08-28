import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/api/logging/api_log_sink.dart';

/// Scripted HTTP adapter for interceptor tests.
///
/// Records every dispatched [RequestOptions] so tests can assert on the
/// headers attached by upstream interceptors.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.onFetch);

  /// Handler invoked for each request; returns the scripted [ResponseBody].
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  /// All request options observed since construction.
  final List<RequestOptions> captured = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a [ResponseBody] with the given status and optional JSON body.
ResponseBody jsonBody(int statusCode, {String body = '{}'}) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

/// Token provider that records [refresh] invocations, for tests.
class FakeTokenProvider implements AccessTokenProvider {
  FakeTokenProvider({this.token});

  /// Current access token returned by [currentToken].
  String? token;

  /// Number of times [refresh] was invoked.
  int refreshCount = 0;

  @override
  String? get currentToken => token;

  @override
  Future<String?> refresh() async {
    refreshCount++;
    return token;
  }
}

/// [ApiLogSink] that records every emitted message, for tests.
class RecordingLogSink implements ApiLogSink {
  RecordingLogSink();

  /// All messages logged so far, formatted as `LEVEL MESSAGE`.
  final List<String> messages = <String>[];

  @override
  void log(String level, String message) {
    messages.add('$level $message');
  }
}

/// Alias kept for source-compatibility with the EP-01-19 plan naming.
typedef FakeApiLogSink = RecordingLogSink;

/// Scripted HTTP adapter that returns a predefined [ResponseBody] per request.
///
/// The handler receives every [RequestOptions] and returns the scripted
/// response. Reused by the legacy `sync_test_helpers` and by
/// [MockApiServiceFactory].
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions) _handler;

  final List<RequestOptions> captured = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a success [ResponseBody] (200 OK).
ResponseBody successBody({String body = '{"ok":true}'}) {
  return ResponseBody.fromString(
    body,
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

/// Builds an error [ResponseBody] with the given status code and optional
/// JSON body. Dio will throw a [DioException] wrapping this response.
ResponseBody errorBody(int statusCode, {String body = '{}'}) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

/// Builds a [Dio] instance backed by [adapter] and no interceptors.
Dio buildTestDio(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
  dio.httpClientAdapter = adapter;
  return dio;
}
