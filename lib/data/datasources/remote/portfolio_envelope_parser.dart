import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Parses the standard `{success, code, message, data}` RPC envelope returned
/// by the `portfolio_public_profile_get` RPC (EP-02-19).
///
/// Envelope contract (identical to taxonomy/dispute parsers):
///   `success == true && code == 'PLT000'` → success; `data` is the profile
///   object. `PLT003` → validation, `PLT004` → not found, `PLT999` → internal.
class PortfolioEnvelopeParser {
  const PortfolioEnvelopeParser._();

  /// The success code for a portfolio RPC response.
  static const String successCode = 'PLT000';

  /// Extracts the `data` map from a decoded RPC [envelope].
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
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(
      kind: ApiExceptionKind.server,
      message: 'Malformed portfolio envelope: data is not an object.',
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
      case 'PLT999':
        kind = ApiExceptionKind.server;
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
        return 'Portfolio request validation failed.';
      case ApiExceptionKind.notFound:
        return 'Professional profile not found.';
      case ApiExceptionKind.conflict:
        return 'Conflict with current state.';
      case ApiExceptionKind.server:
        return 'Portfolio request failed.';
      case ApiExceptionKind.network:
        return 'A network error occurred.';
      case ApiExceptionKind.timeout:
        return 'The request timed out.';
      case ApiExceptionKind.unknown:
        return 'An unexpected error occurred.';
    }
  }
}
