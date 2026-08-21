import 'package:dio/dio.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';

/// Normalizes transport and server failures into a typed [ApiException].
///
/// Runs last in the error chain (added after [RetryInterceptor]); on giving
/// up, it rejects with a [DioException] whose [DioException.error] carries
/// the typed [ApiException] so callers can unwrap it (EP-01-07 §5.4, §5.5).
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({required this.exceptionMapper});

  /// Maps [DioException]s into typed [ApiException]s.
  final ApiExceptionMapper exceptionMapper;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If the error was already normalized upstream, preserve it.
    final existing = err.error;
    if (existing is ApiException) {
      handler.reject(err);
      return;
    }
    final apiException = exceptionMapper.map(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        message: apiException.message,
        error: apiException,
      ),
    );
  }
}
