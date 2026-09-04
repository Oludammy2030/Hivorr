import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Parses the standard `{success, code, message, data}` RPC envelope returned
/// by the financial RPCs (EP-02-13 §9.1).
///
/// Envelope contract (identical to the verification RPCs):
///   `code == 'PLT000'` (and `success == true`) → success; `data` is a single
///   JSON object.
///   `PLT001/P002/003/004/005/999` → typed [ApiException].
class FinancialEnvelopeParser {
  const FinancialEnvelopeParser._();

  /// The success code for a financial RPC response.
  static const String successCode = 'PLT000';

  /// Extracts the `data` object from a decoded RPC [envelope].
  ///
  /// Throws an [ApiException] mapping `code` to the matching kind when the RPC
  /// returned a non-success code, and an [ApiExceptionKind.server] when the
  /// envelope is structurally malformed.
  static Map<String, dynamic> unwrap(Map<String, dynamic> envelope) {
    final Object? code = envelope['code'];
    if (code != successCode) {
      throw _errorForCode(code?.toString());
    }
    final Object? data = envelope['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(
      kind: ApiExceptionKind.server,
      message: 'Malformed financial envelope: data is not an object.',
    );
  }

  static ApiException _errorForCode(String? code) {
    switch (code) {
      case 'PLT001':
        return const ApiException(
          kind: ApiExceptionKind.auth,
          message: 'Authentication required.',
          code: 'PLT001',
        );
      case 'PLT002':
        return const ApiException(
          kind: ApiExceptionKind.forbidden,
          message: 'Operation not permitted.',
          code: 'PLT002',
        );
      case 'PLT003':
        return const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'Financial request validation failed.',
          code: 'PLT003',
        );
      case 'PLT004':
        return const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'Financial resource not found.',
          code: 'PLT004',
        );
      case 'PLT005':
        return const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'A financial profile already exists for this entity.',
          code: 'PLT005',
        );
      default:
        return ApiException(
          kind: code?.startsWith('42501') == true
              ? ApiExceptionKind.forbidden
              : ApiExceptionKind.server,
          message: 'Financial request failed.',
          code: code,
        );
    }
  }
}
