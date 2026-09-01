import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned [HttpClientAdapter] that returns a scripted JSON [ResponseBody]
/// per request and records every [RequestOptions] for spy assertions.
///
/// Used to unit-test the payment gateway adapters (EP-02-09 §14.2) without a
/// live provider. No `supabase_flutter` mock is needed — the gateways are pure
/// `Dio`.
///
/// Usage:
/// ```dart
/// final httpMock = MockDioAdapter(statusCode: 200, body: <String, dynamic>{
///   'status': true, 'data': {...},
/// });
/// final dio = Dio(BaseOptions(baseUrl: 'https://api.paystack.co'))
///   ..httpClientAdapter = httpMock;
/// ```
class MockDioAdapter implements HttpClientAdapter {
  MockDioAdapter({
    this.statusCode = 200,
    this.body,
    this.error,
    this.thrown,
  });

  /// HTTP status code returned for every request.
  int statusCode;

  /// JSON response body returned for every request.
  Map<String, dynamic>? body;

  /// Optional raw error string returned as the response body (used to simulate
  /// malformed payloads).
  String? error;

  /// Optional [DioException] thrown by [fetch] to simulate transport errors.
  DioException? thrown;

  /// Every [RequestOptions] seen by [fetch], in call order.
  final List<RequestOptions> requests = <RequestOptions>[];

  bool _closed = false;

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// The most recent request's requested URI.
  String get capturedUrl =>
      requests.isEmpty ? '' : requests.last.uri.toString();

  /// The most recent request's absolute path (baseUrl + path).
  String get capturedPath =>
      requests.isEmpty ? '' : requests.last.path;

  /// The most recent request's query parameters.
  Map<String, dynamic>? get capturedQueryParameters =>
      requests.isEmpty ? null : requests.last.queryParameters;

  /// The most recent request's `Authorization` header value.
  String? get capturedAuthorizationHeader =>
      _header(requests, 'Authorization');

  /// The most recent request's decoded JSON body.
  Map<String, dynamic>? get capturedBody {
    if (requests.isEmpty) return null;
    final dynamic data = requests.last.data;
    if (data is Map) {
      return data.map<String, dynamic>(
        (dynamic k, dynamic v) => MapEntry(k.toString(), v as dynamic),
      );
    }
    return null;
  }

  String? _header(List<RequestOptions> list, String name) {
    if (list.isEmpty) return null;
    final Object? value = list.last.headers[name];
    if (value is String) return value;
    if (value is Iterable) {
      final String? first = value.isEmpty ? null : value.first.toString();
      return first;
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (thrown != null) {
      throw thrown!;
    }

    final String payload;
    if (error != null) {
      payload = error!;
    } else {
      payload = jsonEncode(body ?? <String, dynamic>{});
    }

    return ResponseBody.fromString(
      payload,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }
}

/// Convenience constructor alias for terser test setup.
MockDioAdapter mockDio({
  int statusCode = 200,
  Map<String, dynamic>? body,
  String? error,
  DioException? thrown,
}) {
  return MockDioAdapter(
    statusCode: statusCode,
    body: body,
    error: error,
    thrown: thrown,
  );
}
