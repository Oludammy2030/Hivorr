import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Parses the standard `{success, code, message, data}` RPC envelope returned
/// by the service contract RPCs (EP-03-10 §11, EP-03-02
/// `20260923090001_service_contract_schema.sql`).
///
/// Envelope contract (identical to the jobs/listing/dispute RPCs):
///   `success == true && code == 'PLT000'` → success; `data` is the payload.
///   `PLT001/PLT002/PLT003/PLT004/PLT005/PLT999` → typed [ApiException] whose
///   `message` carries the server-provided safe message when present.
class ServiceContractEnvelopeParser {
  const ServiceContractEnvelopeParser._();

  /// The success code for a service contract RPC response.
  static const String successCode = 'PLT000';

  /// Extracts the `data` object from a decoded RPC [envelope].
  ///
  /// Throws an [ApiException] mapping `code` to the matching kind when the RPC
  /// returned a non-success code, and an [ApiExceptionKind.server] when the
  /// envelope is structurally malformed.
  static Map<String, dynamic> unwrap(Map<String, dynamic> envelope) {
    final Object? code = envelope['code'];
    final Object? message = envelope['message'];
    if (code != successCode) {
      throw _errorForCode(code?.toString(), message: message?.toString());
    }
    final Object? data = envelope['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(
      kind: ApiExceptionKind.server,
      message: 'Malformed service contract envelope: data is not an object.',
    );
  }

  static ApiException _errorForCode(String? code, {String? message}) {
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
      default:
        kind = ApiExceptionKind.server;
    }
    return ApiException(
      kind: kind,
      message: _safeMessage(message, kind),
      code: code,
    );
  }

  static String _safeMessage(String? message, ApiExceptionKind kind) {
    if (message != null && message.trim().isNotEmpty) return message;
    switch (kind) {
      case ApiExceptionKind.auth:
        return 'Authentication required.';
      case ApiExceptionKind.forbidden:
        return 'Operation not permitted.';
      case ApiExceptionKind.validation:
        return 'Contract request validation failed.';
      case ApiExceptionKind.notFound:
        return 'Contract not found.';
      case ApiExceptionKind.conflict:
        return 'Conflict with current contract state.';
      case ApiExceptionKind.server:
        return 'Contract request failed.';
      case ApiExceptionKind.network:
        return 'A network error occurred.';
      case ApiExceptionKind.timeout:
        return 'The request timed out.';
      case ApiExceptionKind.unknown:
        return 'An unexpected error occurred.';
    }
  }
}
