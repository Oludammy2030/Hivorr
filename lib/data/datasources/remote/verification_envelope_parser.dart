import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Parses the standard `{success, code, message, data}` RPC envelope returned
/// by the verification RPCs (EP-02-10 §5.2, §9.1).
///
/// Envelope contract (identical to EP-02-02/EP-02-07):
///   `code == 'PLT000'` (and `success == true`) → success; `data` is a single
///   JSON object.
///   `PLT001/P002/003/004/005/999` → typed [ApiException].
///
/// Unlike the taxonomy parser (whose RPCs return an array in `data`), the
/// verification RPCs return a single object, so [unwrap] validates a map.
class VerificationEnvelopeParser {
  const VerificationEnvelopeParser._();

  /// The success code for a verification RPC response.
  static const String successCode = 'PLT000';

  /// The canonical message for the one-active-submission conflict (`PLT005`),
  /// surfaced to the user as a dedup dialog.
  static const String activeConflictMessage =
      'You already have a pending verification for this document.';

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
      message: 'Malformed verification envelope: data is not an object.',
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
          message: 'Verification request validation failed.',
          code: 'PLT003',
        );
      case 'PLT004':
        return const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'Verification resource not found.',
          code: 'PLT004',
        );
      case 'PLT005':
        return ApiException(
          kind: ApiExceptionKind.conflict,
          message: activeConflictMessage,
          code: 'PLT005',
        );
      default:
        return ApiException(
          kind: code?.startsWith('42501') == true
              ? ApiExceptionKind.forbidden
              : ApiExceptionKind.server,
          message: 'Verification request failed.',
          code: code,
        );
    }
  }
}
