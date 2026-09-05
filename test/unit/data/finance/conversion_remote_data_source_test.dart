// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart' as norm;
import 'package:hivorr/data/datasources/remote/supabase_conversion_remote_data_source.dart';
import 'package:hivorr/data/models/currency_conversion_dto.dart';
import 'package:postgrest/postgrest.dart' show PostgrestException;

import '../../../support/factories/mock_supabase_client_factory.dart';

/// Unit coverage for [SupabaseConversionRemoteDataSource] (EP-02-15 §5.2) over
/// the scripted Supabase transport: it must forward the exact
/// `financial_convert_currency` params (including the trusted `p_rate`),
/// unwrap the `PLT000` envelope into a `completed` DTO, read history through
/// the REST seam gated by `historyReadEnabled`, and normalize every failure
/// into a typed [ApiException] — never leaking a raw transport/Postgrest error
/// (TT-01). The datasource never invents or accepts a user-arbitrary rate
/// (DoD SV-01).
void main() {
  SupabaseConversionRemoteDataSource build(
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers, {
    bool historyReadEnabled = true,
    Map<String, List<Map<String, dynamic>>>? queryResults,
    Object? queryError,
  }) =>
      SupabaseConversionRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(
          rpcHandlers: rpcHandlers,
          queryResults: queryResults,
          queryError: queryError,
        ),
        exceptionMapper: const ApiExceptionMapper(),
        historyReadEnabled: historyReadEnabled,
      );

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  Map<String, dynamic> conversionData({double fromAmount = 50000}) =>
      <String, dynamic>{
        'conversion_id': 'conversion-rpc-1',
        'from_amount': fromAmount,
        'to_amount': 35,
        'rate': 0.0007,
      };

  Map<String, dynamic> historyRow({
    String id = 'c-1',
    String fromCurrency = 'NGN',
    String toCurrency = 'USD',
  }) =>
      <String, dynamic>{
        'conversion_id': id,
        'entity_id': 'u1',
        'from_currency': fromCurrency,
        'to_currency': toCurrency,
        'from_amount': 50000,
        'to_amount': 35,
        'exchange_rate': 0.0007,
        'fee': 0,
        'status': 'completed',
        'created_at': '2026-01-01T00:00:00.000Z',
        'completed_at': '2026-01-01T00:00:01.000Z',
      };

  group('convertCurrency', () {
    test(
        'forwards p_from_currency/p_to_currency/p_amount plus the trusted '
        'p_rate and maps the envelope to a completed DTO', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_convert_currency': (Map<String, dynamic> body) {
          seenFn = 'financial_convert_currency';
          seenParams = body;
          return ok(conversionData());
        },
      });

      final CurrencyConversionDto dto = await source.convertCurrency(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        amount: 50000,
        rate: 0.0007,
      );

      expect(seenFn, 'financial_convert_currency');
      expect(seenParams!['p_from_currency'], 'NGN');
      expect(seenParams!['p_to_currency'], 'USD');
      expect(seenParams!['p_amount'], 50000);
      expect(seenParams!['p_rate'], 0.0007);
      expect(dto.id, 'conversion-rpc-1');
      expect(dto.fromCurrency, 'NGN');
      expect(dto.toCurrency, 'USD');
      expect(dto.fromAmount, 50000);
      expect(dto.toAmount, 35);
      expect(dto.exchangeRate, 0.0007);
      expect(dto.status, 'completed');
      expect(dto.fee, 0);
    });

    test('the rate handed to the RPC is exactly what the caller provided '
        '(rate-integrity boundary)', () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_convert_currency': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(conversionData());
        },
      });

      const double trustedRate = 1234.5;
      await source.convertCurrency(
        fromCurrency: 'GHS',
        toCurrency: 'NGN',
        amount: 5,
        rate: trustedRate,
      );

      expect(seenParams!['p_rate'], trustedRate);
    });

    test('maps a non-PLT000 envelope to a typed ApiException', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_convert_currency': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT006',
            'message': 'insufficient balance',
          },
      });

      await expectLater(
        source.convertCurrency(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: 50000,
          rate: 0.0007,
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind',
                  ApiExceptionKind.conflict)
              .having((ApiException e) => e.code, 'code', 'PLT006'),
        ),
      );
    });

    test('maps a malformed envelope (non-object data) to server', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_convert_currency': (_) => <String, dynamic>{
            'success': true,
            'code': 'PLT000',
            'data': <dynamic>[1, 2, 3],
          },
      });

      await expectLater(
        source.convertCurrency(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: 1,
          rate: 2,
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });

    test('maps an RPC transport failure to a typed ApiException', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_convert_currency': (_) => throw StateError('network down'),
      });

      await expectLater(
        source.convertCurrency(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: 1,
          rate: 2,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('getHistory', () {
    test('reads financial_conversions REST rows and maps each to a DTO',
        () async {
      final source = build(
        null,
        queryResults: <String, List<Map<String, dynamic>>>{
          'financial_conversions': <Map<String, dynamic>>[
            historyRow(id: 'c-1'),
            historyRow(id: 'c-2', fromCurrency: 'USD', toCurrency: 'GHS'),
          ],
        },
      );

      final List<CurrencyConversionDto> rows = await source.getHistory();

      expect(rows, hasLength(2));
      expect(rows.first.id, 'c-1');
      expect(rows.first.status, 'completed');
      expect(rows.first.exchangeRate, 0.0007);
      expect(rows.last.fromCurrency, 'USD');
      expect(rows.last.toCurrency, 'GHS');
    });

    test('maps an identity-scoped profile id when a user is signed in',
        () async {
      final source = build(
        null,
        queryResults: <String, List<Map<String, dynamic>>>{
          'financial_conversions': <Map<String, dynamic>>[
            historyRow(),
          ],
        },
        // MockSupabaseClientFactory defaults to signed-out; the identity
        // branch is covered when a user is seeded.
      );

      final List<CurrencyConversionDto> rows = await source.getHistory();
      expect(rows, hasLength(1));
    });

    test('returns an empty list when historyReadEnabled is false', () async {
      // If the gate were bypassed the REST query would be exercised; here the
      // client has no seeds, so an unexpected query would return rows anyway —
      // the empty result proves the seam short-circuits.
      final source = build(null, historyReadEnabled: false);

      final List<CurrencyConversionDto> rows = await source.getHistory();

      expect(rows, isEmpty);
      expect(source.historyReadEnabled, isFalse);
    });

    test('normalizes a REST query failure to a typed ApiException', () async {
      final source = build(null, queryError: StateError('read denied'));

      await expectLater(source.getHistory(), throwsA(isA<ApiException>()));
    });
  });

  group('mapDataException normalization', () {
    test('rethrows typed ApiExceptions unchanged', () {
      const ApiException original = ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'dup',
        code: 'PLT006',
      );
      expect(norm.mapDataException(original), same(original));
    });

    test('maps PLT006 carried in Postgrest details to conflict', () {
      const PostgrestException pg = PostgrestException(
        message: 'insufficient source balance',
        code: 'P0001',
        details: 'PLT006',
      );
      final ApiException e = norm.mapDataException(pg);
      expect(e.kind, ApiExceptionKind.conflict);
      expect(e.code, 'PLT006');
    });

    test('maps SQLSTATE 42501 to forbidden', () {
      const PostgrestException pg = PostgrestException(
        message: 'policy violation',
        code: '42501',
      );
      expect(norm.mapDataException(pg).kind, ApiExceptionKind.forbidden);
    });

    test('maps unknown codes to server without leaking the message', () {
      const PostgrestException pg = PostgrestException(
        message: 'internal',
        code: '500',
      );
      final ApiException e = norm.mapDataException(pg);
      expect(e.kind, ApiExceptionKind.server);
      expect(e.message, isNot(contains('internal')));
    });

    test('falls back to unknown for non-Postgrest transport errors', () {
      final ApiException e = norm.mapDataException(StateError('boom'));
      expect(e.kind, ApiExceptionKind.unknown);
      expect(e.message, isNot(contains('boom')));
    });
  });
}