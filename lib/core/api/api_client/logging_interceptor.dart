import 'package:dio/dio.dart';

import 'package:hivorr/core/api/logging/api_log_sink.dart';

/// Records structured, secret-free request/response/error logs.
///
/// Logs only method, path, status, and duration. The `Authorization` header
/// and any body are never logged, satisfying the redaction requirement
/// (EP-01-07 §5.4, §12).
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({required this.logSink});

  /// Sink that receives structured log records.
  final ApiLogSink logSink;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startTimeKey] = DateTime.now().microsecondsSinceEpoch;
    logSink.log('REQUEST', '${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logOutcome(response.requestOptions, response.statusCode, null);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logOutcome(err.requestOptions, err.response?.statusCode, err.type.name);
    handler.next(err);
  }

  void _logOutcome(RequestOptions options, int? statusCode, String? errorType) {
    final start = options.extra[_startTimeKey] as int?;
    final duration = start == null
        ? '?'
        : '${((DateTime.now().microsecondsSinceEpoch - start) / 1000).toStringAsFixed(0)}ms';
    final status = statusCode?.toString() ?? errorType ?? 'ERROR';
    logSink.log(
      'RESPONSE',
      '${options.method} ${options.path} -> $status ($duration)',
    );
  }

  static const String _startTimeKey = 'hivorr_api_start_time';
}
