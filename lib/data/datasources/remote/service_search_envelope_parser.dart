import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Parses the `{success, code, message, data}` envelope returned by
/// `service_ranking_search` (`20260927090001_platform_config_and_ranking.sql:233`).
///
/// Contract: `success==true && code=='PLT000'` → `data` contains
/// `{items, has_more, next_cursor, weights_version}`. Any other `code`
/// (`PLT003` validation, `PLT004` not found, `PLT999` internal, or `P0001`
/// with `detail PLT***` from anon path) is mapped to a typed [ApiException].
///
/// Mirrors `TaxonomyEnvelopeParser` (EP-02-02) — same `PLT***` vocabulary.
class ServiceSearchEnvelopeParser {
  const ServiceSearchEnvelopeParser._();

  static const String successCode = 'PLT000';

  /// Extracts the ranked-page `data` map; throws typed [ApiException] on error.
  static Map<String, dynamic> unwrapData(Map<String, dynamic> envelope) {
    final Object? success = envelope['success'];
    final Object? code = envelope['code'];
    // success may be bool true or truthy; code is authoritative
    if (code != successCode || success != true) {
      // For anon path the envelope may not be normalized; code still PLT***
      throw _errorForCode(code?.toString(), envelope['message']?.toString());
    }
    final Object? data = envelope['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      kind: ApiExceptionKind.server,
      message: 'Malformed service ranking envelope: data is not an object.',
    );
  }

  /// Validates the envelope shape and extracts `List<Map>` for legacy callers.
  /// Kept for parity with `TaxonomyEnvelopeParser.unwrapData` signature.
  static List<Map<String, dynamic>> unwrapItems(
    Map<String, dynamic> envelope,
  ) {
    final Map<String, dynamic> data = unwrapData(envelope);
    final Object? items = data['items'];
    if (items is! List) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        message: 'Malformed service ranking envelope: items is not an array.',
      );
    }
    return items
        .map((Object? e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        })
        .toList(growable: false);
  }

  static ApiException _errorForCode(String? code, String? message) {
    final String c = code ?? '';
    switch (c) {
      case 'PLT003':
        return ApiException(
          kind: ApiExceptionKind.validation,
          message: message ?? 'Service ranking validation failed.',
          code: c,
        );
      case 'PLT004':
        return ApiException(
          kind: ApiExceptionKind.notFound,
          message: message ?? 'Resource not found.',
          code: c,
        );
      case 'PLT005':
        return const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'Service ranking conflict.',
          code: 'PLT005',
        );
      default:
        if (c.startsWith('42501') || c.startsWith('P0001') && (message?.contains('PLT002') ?? false)) {
          return ApiException(
            kind: ApiExceptionKind.forbidden,
            message: message ?? 'Operation not permitted.',
            code: c,
          );
        }
        if (c.startsWith('PLT')) {
          return ApiException(
            kind: ApiExceptionKind.server,
            message: message ?? 'Service ranking failed.',
            code: c,
          );
        }
        return ApiException(
          kind: ApiExceptionKind.server,
          message: message ?? 'Service ranking failed.',
          code: c.isNotEmpty ? c : 'PLT999',
        );
    }
  }
}
