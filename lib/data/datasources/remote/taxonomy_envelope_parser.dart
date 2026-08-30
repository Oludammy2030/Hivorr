import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Parses the standard `{success, code, message, data}` RPC envelope returned
/// by the EP-02-02 taxonomy read RPCs.
///
/// The envelope contract (EP-02-02 §5, EP-02-07 plan §5.2):
///   `success == true`, `code == 'PLT000'` → success, `data` is the JSON array.
///   `PLT003/004/005` → validation / notFound / conflict.
///
/// This parser validates the envelope shape before any caller maps the `data`
/// array, so a malformed or erroring RPC never surfaces a bogus row list.
class TaxonomyEnvelopeParser {
  const TaxonomyEnvelopeParser._();

  /// Whether [code] represents a successful RPC response.
  static const String successCode = 'PLT000';

  /// Extracts the `data` array from a decoded RPC [envelope], treating a
  /// success as mandatory.
  ///
  /// Throws an [ApiException] mapping `code` to the matching kind when the
  /// RPC returned a non-success code, and an [ApiExceptionKind.server] when the
  /// envelope is structurally malformed.
  static List<Map<String, dynamic>> unwrapData(Map<String, dynamic> envelope) {
    final Object? code = envelope['code'];
    if (code != successCode) {
      throw _errorForCode(code?.toString());
    }
    final Object? data = envelope['data'];
    if (data is! List) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        message: 'Malformed taxonomy envelope: data is not an array.',
      );
    }
    return data.map((Object? e) {
      if (e is Map<String, dynamic>) {
        return e;
      }
      return Map<String, dynamic>.from(e as Map);
    }).toList(growable: false);
  }

  static ApiException _errorForCode(String? code) {
    switch (code) {
      case 'PLT003':
        return const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'Taxonomy request validation failed.',
          code: 'PLT003',
        );
      case 'PLT004':
        return const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'Taxonomy resource not found.',
          code: 'PLT004',
        );
      case 'PLT005':
        return const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'Taxonomy state conflict.',
          code: 'PLT005',
        );
      default:
        return ApiException(
          kind: code?.startsWith('42501') == true
              ? ApiExceptionKind.forbidden
              : ApiExceptionKind.server,
          message: 'Taxonomy read failed.',
          code: code,
        );
    }
  }
}
