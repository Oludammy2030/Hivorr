import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';
import 'package:hivorr/core/sync/sync_config.dart';

/// Builds a [SyncConfig] with small values for fast unit tests.
SyncConfig testSyncConfig({
  int maxQueueDepth = 10,
  int maxRetries = 3,
  int drainBatchSize = 5,
}) {
  return SyncConfig(
    maxQueueDepth: maxQueueDepth,
    defaultMaxRetries: maxRetries,
    baseDelay: const Duration(milliseconds: 10),
    maxDelay: const Duration(milliseconds: 100),
    jitterMax: const Duration(milliseconds: 10),
    defaultPriority: 10,
    drainBatchSize: drainBatchSize,
  );
}

/// Creates a [SyncAction] with sensible defaults for tests.
SyncAction testAction({
  String endpoint = '/rpc/test',
  String method = 'POST',
  SyncActionType type = SyncActionType.update,
  int priority = 10,
  Map<String, dynamic>? payload,
  int? lastKnownVersion,
  int maxRetries = 0,
  String id = '',
}) {
  return SyncAction(
    id: id,
    type: type,
    endpoint: endpoint,
    method: method,
    payload: payload,
    priority: priority,
    status: SyncActionStatus.pending,
    retryCount: 0,
    maxRetries: maxRetries,
    lastKnownVersion: lastKnownVersion,
    createdAt: DateTime.now(),
  );
}

/// Scripted HTTP adapter that returns a predefined [Response] for each
/// request. If [errorStatus] is non-null, it returns a response with that
/// status code, causing Dio to throw a [DioException].
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
