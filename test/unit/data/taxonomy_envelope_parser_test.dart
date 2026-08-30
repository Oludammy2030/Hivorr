import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/taxonomy_envelope_parser.dart';

void main() {
  group('TaxonomyEnvelopeParser', () {
    test('unwraps data array on PLT000 success', () {
      final List<Map<String, dynamic>> rows =
          TaxonomyEnvelopeParser.unwrapData(<String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': <dynamic>[
          <String, dynamic>{'id': 'ind-1'},
          <String, dynamic>{'id': 'ind-2'},
        ],
      });
      expect(rows.length, 2);
      expect(rows.first['id'], 'ind-1');
    });

    test('normalizes PLT003 to validation', () {
      expect(
        () => TaxonomyEnvelopeParser.unwrapData(
          <String, dynamic>{'code': 'PLT003', 'data': <dynamic>[]},
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((ApiException e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('normalizes PLT004 to notFound', () {
      expect(
        () => TaxonomyEnvelopeParser.unwrapData(
          <String, dynamic>{'code': 'PLT004', 'data': <dynamic>[]},
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.notFound)
              .having((ApiException e) => e.code, 'code', 'PLT004'),
        ),
      );
    });

    test('normalizes PLT005 to conflict', () {
      expect(
        () => TaxonomyEnvelopeParser.unwrapData(
          <String, dynamic>{'code': 'PLT005', 'data': <dynamic>[]},
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.conflict)),
      );
    });

    test('maps 42501 to forbidden', () {
      expect(
        () => TaxonomyEnvelopeParser.unwrapData(
          <String, dynamic>{'code': '42501', 'data': <dynamic>[]},
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.forbidden)),
      );
    });

    test('throws server on malformed data payload', () {
      expect(
        () => TaxonomyEnvelopeParser.unwrapData(<String, dynamic>{
          'code': 'PLT000',
          'data': 'not-an-array',
        }),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.server)),
      );
    });
  });
}
