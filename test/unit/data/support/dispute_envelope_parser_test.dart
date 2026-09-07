import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/dispute_envelope_parser.dart';

void main() {
  const String successCode = DisputeEnvelopeParser.successCode;

  Map<String, dynamic> envelope({
    String code = successCode,
    String? message,
    Object? data,
  }) =>
      <String, dynamic>{
        'success': code == successCode,
        'code': code,
        'message': message,
        'data': data,
      };

  group('DisputeEnvelopeParser.unwrap', () {
    test('returns the data object for a PLT000 success envelope', () {
      final Map<String, dynamic> result = DisputeEnvelopeParser.unwrap(
        envelope(data: <String, dynamic>{'disputes': <dynamic>[]}),
      );

      expect(result, <String, dynamic>{'disputes': <dynamic>[]});
    });

    test('throws server ApiException when data is structurally malformed', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(envelope(data: 'not-a-map')),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.server)
              .having((ApiException e) => e.message, 'message', contains('Malformed')),
        ),
      );
    });

    test('PLT001 maps to ApiExceptionKind.auth', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(envelope(code: 'PLT001')),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.auth,
          ),
        ),
      );
    });

    test('PLT002 maps to ApiExceptionKind.forbidden', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(envelope(code: 'PLT002')),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.forbidden,
          ),
        ),
      );
    });

    test('PLT003 maps to ApiExceptionKind.validation', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(envelope(code: 'PLT003')),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.validation,
          ),
        ),
      );
    });

    test('PLT004 maps to ApiExceptionKind.notFound', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(envelope(code: 'PLT004')),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.notFound,
          ),
        ),
      );
    });

    test('PLT005 maps to ApiExceptionKind.conflict', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(envelope(code: 'PLT005')),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.conflict,
          ),
        ),
      );
    });

    test('an unrecognized or missing code maps to server', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(envelope(code: 'PLT999', message: 'x')),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.server,
              )
              .having((ApiException e) => e.code, 'code', 'PLT999'),
        ),
      );

      expect(
        () => DisputeEnvelopeParser.unwrap(envelope()),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });

    test('carries the server-provided safe message through', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(
          envelope(code: 'PLT003', message: 'Reason must be at least 10 '
              'characters when provided.'),
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            'Reason must be at least 10 characters when provided.',
          ),
        ),
      );
    });

    test('falls back to a typed default message when the server message is '
        'blank', () {
      expect(
        () => DisputeEnvelopeParser.unwrap(envelope(code: 'PLT004', message: '  ')),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            'Dispute not found.',
          ),
        ),
      );
    });
  });
}