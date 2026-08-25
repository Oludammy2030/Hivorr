import 'package:dio/dio.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Maps transport and server failures into a typed [ApiException].
///
/// Consumes the EP-01-05 server-side error contract (`PLT001`–`PLT999`):
/// HTTP status codes are mapped to their corresponding platform code, and a
/// platform `code` found in a PostgREST/RPC error body is honored when
/// present.
///
/// No raw values, SQL, or sensitive data are surfaced in the resulting
/// [ApiException.message] (EP-01-07 §5.5, §12).
class ApiExceptionMapper {
  const ApiExceptionMapper();

  /// Maps a [DioException] into a typed [ApiException].
  ApiException map(DioException exception) {
    final response = exception.response;
    if (response != null) {
      return _mapResponse(response);
    }
    return _mapTransport(exception);
  }

  ApiException _mapResponse(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 0;
    final platformCode = _extractPlatformCode(response.data);
    final platformMessage = _extractPlatformMessage(response.data);

    return switch (statusCode) {
      401 => ApiException(
        kind: ApiExceptionKind.auth,
        message: platformMessage ?? 'Authentication required.',
        code: platformCode ?? 'PLT001',
        statusCode: statusCode,
      ),
      403 => ApiException(
        kind: ApiExceptionKind.forbidden,
        message: platformMessage ?? 'Operation not permitted.',
        code: platformCode ?? 'PLT002',
        statusCode: statusCode,
      ),
      404 => ApiException(
        kind: ApiExceptionKind.notFound,
        message: platformMessage ?? 'Resource not found.',
        code: platformCode ?? 'PLT004',
        statusCode: statusCode,
      ),
      409 => ApiException(
        kind: ApiExceptionKind.conflict,
        message: platformMessage ?? 'Conflict with current state.',
        code: platformCode ?? 'PLT005',
        statusCode: statusCode,
      ),
      400 || 422 =>
        platformCode == 'PLT003'
            ? ApiException(
                kind: ApiExceptionKind.validation,
                message: platformMessage ?? 'Validation failed.',
                code: 'PLT003',
                statusCode: statusCode,
              )
            : ApiException(
                kind: ApiExceptionKind.validation,
                message: platformMessage ?? 'The request was rejected.',
                code: platformCode ?? 'PLT003',
                statusCode: statusCode,
              ),
      _ when statusCode >= 500 && statusCode <= 599 => ApiException(
        kind: ApiExceptionKind.server,
        message: platformMessage ?? 'A server error occurred.',
        code: platformCode ?? 'PLT999',
        statusCode: statusCode,
      ),
      _ => ApiException(
        kind: ApiExceptionKind.unknown,
        message: platformMessage ?? 'An unexpected error occurred.',
        code: platformCode,
        statusCode: statusCode,
      ),
    };
  }

  ApiException _mapTransport(DioException exception) =>
      switch (exception.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout => const ApiException(
          kind: ApiExceptionKind.timeout,
          message: 'The request timed out.',
          code: 'PLT999',
        ),
        DioExceptionType.connectionError ||
        DioExceptionType.unknown => const ApiException(
          kind: ApiExceptionKind.network,
          message: 'A network error occurred.',
          code: 'PLT999',
        ),
        DioExceptionType.badCertificate => const ApiException(
          kind: ApiExceptionKind.unknown,
          message: 'An insecure connection was rejected.',
          code: 'PLT999',
        ),
        DioExceptionType.cancel => const ApiException(
          kind: ApiExceptionKind.unknown,
          message: 'The request was cancelled.',
          code: 'PLT999',
        ),
        DioExceptionType.badResponse => const ApiException(
          kind: ApiExceptionKind.server,
          message: 'An unexpected response was received.',
          code: 'PLT999',
        ),
      };

  String? _extractPlatformCode(dynamic body) {
    if (body is Map<String, dynamic>) {
      final code = body['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    return null;
  }

  String? _extractPlatformMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      final message = body['message'] ?? body['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }
}
