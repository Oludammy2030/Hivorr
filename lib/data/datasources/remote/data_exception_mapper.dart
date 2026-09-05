import 'package:hivorr/core/api/exceptions/api_exception.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Normalizes transport and server failures into a typed [ApiException].
///
/// Consumes the EP-01-05/`PLT###` contract where a platform code is present
/// and applies best-effort SQLSTATE fallbacks otherwise. No raw SQL, secrets,
/// or sensitive values are surfaced in the resulting message (EP-01-08 §5.4,
/// §12). Used by the remote datasource before any error crosses the
/// repository boundary.
ApiException mapDataException(Object error) {
  if (error is ApiException) {
    return error;
  }
  if (error is PostgrestException) {
    final String code = _platformCode(error);
    final ApiExceptionKind kind;
    switch (code) {
      case 'PLT001':
        kind = ApiExceptionKind.auth;
      case 'PLT002':
        kind = ApiExceptionKind.forbidden;
      case 'PLT003':
        kind = ApiExceptionKind.validation;
      case 'PLT004':
        kind = ApiExceptionKind.notFound;
      case 'PLT005':
        kind = ApiExceptionKind.conflict;
      case 'PLT006':
        // Insufficient balance (e.g. financial_convert_currency 1511-1513) —
        // a state conflict the caller can resolve, not a server fault.
        kind = ApiExceptionKind.conflict;
      default:
        if (code.startsWith('235')) {
          kind = ApiExceptionKind.conflict;
        } else if (code.startsWith('42501')) {
          kind = ApiExceptionKind.forbidden;
        } else if (code.startsWith('42P') || code.startsWith('P0')) {
          kind = ApiExceptionKind.forbidden;
        } else {
          kind = ApiExceptionKind.server;
        }
    }
    return ApiException(
      kind: kind,
      message: _safeMessage(kind),
      code: code.isNotEmpty ? code : null,
    );
  }
  return const ApiException(
    kind: ApiExceptionKind.unknown,
    message: 'An unexpected data error occurred.',
  );
}

/// Resolves the platform (`PLT###`) code carried by a [PostgrestException].
///
/// `platform_raise_error` raises with SQLSTATE `P0001` but stamps the platform
/// code in the error `detail` (`20260819090001_enforcement_foundation.sql:77-80`),
/// so a raised `PLT006` arrives as `code: 'P0001'`, `detail: 'PLT006'`. The
/// platform code is preferred over the SQLSTATE so typed kinds (auth,
/// validation, conflict, ...) survive transport.
String _platformCode(PostgrestException error) {
  final String? code = error.code;
  if (code != null && code.startsWith('PLT')) return code;
  final Object? details = error.details;
  if (details is String && details.startsWith('PLT')) return details;
  return code ?? '';
}

String _safeMessage(ApiExceptionKind kind) {
  switch (kind) {
    case ApiExceptionKind.auth:
      return 'Authentication required.';
    case ApiExceptionKind.forbidden:
      return 'Operation not permitted.';
    case ApiExceptionKind.validation:
      return 'Validation failed.';
    case ApiExceptionKind.notFound:
      return 'Resource not found.';
    case ApiExceptionKind.conflict:
      return 'Conflict with current state.';
    case ApiExceptionKind.server:
      return 'A server error occurred.';
    case ApiExceptionKind.network:
      return 'A network error occurred.';
    case ApiExceptionKind.timeout:
      return 'The request timed out.';
    case ApiExceptionKind.unknown:
      return 'An unexpected error occurred.';
  }
}
