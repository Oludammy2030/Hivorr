import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/portfolio_envelope_parser.dart';

void main() {
  group('PortfolioEnvelopeParser (TT-07 / FV-11)', () {
    test('unwraps the profile data map on PLT000 success', () {
      final Map<String, dynamic> data = PortfolioEnvelopeParser.unwrap(
        <String, dynamic>{
          'success': true,
          'code': 'PLT000',
          'message': 'ok',
          'data': <String, dynamic>{'entity_id': 'entity-1'},
        },
      );

      expect(data, containsPair('entity_id', 'entity-1'));
    });

    test('accepts a Dart Map payload through the dynamic bridge', () {
      final Map<String, dynamic> data = PortfolioEnvelopeParser.unwrap(
        <String, dynamic>{
          'code': 'PLT000',
          'data': <String, dynamic>{'display_name': 'Ada'},
        },
      );

      expect(data['display_name'], 'Ada');
    });

    test('normalizes PLT003 to validation', () {
      expect(
        () => PortfolioEnvelopeParser.unwrap(<String, dynamic>{
          'code': 'PLT003',
          'message': 'invalid id',
          'data': <String, dynamic>{},
        }),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              )
              .having((ApiException e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('normalizes PLT004 to notFound', () {
      expect(
        () => PortfolioEnvelopeParser.unwrap(<String, dynamic>{
          'code': 'PLT004',
          'message': 'not found',
          'data': <String, dynamic>{},
        }),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.notFound,
              )
              .having((ApiException e) => e.code, 'code', 'PLT004'),
        ),
      );
    });

    test('normalizes PLT005 to conflict', () {
      expect(
        () => PortfolioEnvelopeParser.unwrap(<String, dynamic>{
          'code': 'PLT005',
          'message': 'conflict',
          'data': <String, dynamic>{},
        }),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.conflict,
          ),
        ),
      );
    });

    test('normalizes PLT999 to server', () {
      expect(
        () => PortfolioEnvelopeParser.unwrap(<String, dynamic>{
          'code': 'PLT999',
          'message': 'internal error',
          'data': <String, dynamic>{},
        }),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });

    test('falls back to server for an unknown code', () {
      expect(
        () => PortfolioEnvelopeParser.unwrap(<String, dynamic>{
          'code': 'PLT777',
          'data': <String, dynamic>{},
        }),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });

    test('throws server on a non-object data payload', () {
      expect(
        () => PortfolioEnvelopeParser.unwrap(<String, dynamic>{
          'code': 'PLT000',
          'data': 'not-a-map',
        }),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.server,
              )
              .having((ApiException e) => e.code, 'code', isNull),
        ),
      );
    });

    test('throws server when data is missing entirely', () {
      expect(
        () =>
            PortfolioEnvelopeParser.unwrap(<String, dynamic>{'code': 'PLT000'}),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });
  });
}
