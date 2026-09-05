import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/conversion_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/financial_envelope_parser.dart';
import 'package:hivorr/data/models/currency_conversion_dto.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed implementation of [ConversionRemoteDataSource] (EP-02-15).
///
/// `convertCurrency` calls the authenticated, self-scoped
/// `financial_convert_currency` RPC with the standard financial envelope
/// (`{success, code PLT000, data:{conversion_id, from_amount, to_amount,
/// rate}}`) via [FinancialEnvelopeParser]. The rate parameter is supplied by
/// the repository from the `ConversionRateSource` seam — this datasource never
/// invents or accepts a user-arbitrary rate.
///
/// `getHistory` reads `financial_conversions` rows through the REST transport
/// seam, gated by [historyReadEnabled] (build-time decision §5.2). When the
/// gate is off the method returns `[]` with the future
/// `financial_conversions_list` RPC swap point documented in
/// [ConversionRemoteDataSource.getHistory] dartdoc. It never writes and never
/// bypasses RLS.
class SupabaseConversionRemoteDataSource extends BaseApiService
    implements ConversionRemoteDataSource {
  SupabaseConversionRemoteDataSource({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
    this.historyReadEnabled = true,
  });

  /// Whether the `financial_conversions` REST read seam is enabled.
  ///
  /// Mirrors the authenticated-role REST grant decision at build (§5.2); when
  /// `false`, [getHistory] returns an empty list.
  final bool historyReadEnabled;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw mapDataException(e);
    }
  }

  @override
  Future<CurrencyConversionDto> convertCurrency({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
    required double rate,
  }) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'financial_convert_currency',
          params: <String, dynamic>{
            'p_from_currency': fromCurrency,
            'p_to_currency': toCurrency,
            'p_amount': amount,
            'p_rate': rate,
          },
        );
        final Map<String, dynamic> data = FinancialEnvelopeParser.unwrap(response);
        return CurrencyConversionDto.fromRpc(
          conversionId: data['conversion_id'] as String,
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          fromAmount: (data['from_amount'] as num).toDouble(),
          toAmount: (data['to_amount'] as num).toDouble(),
          rate: (data['rate'] as num).toDouble(),
        );
      });

  @override
  Future<List<CurrencyConversionDto>> getHistory() => _guard(() async {
        if (!historyReadEnabled) {
          return const <CurrencyConversionDto>[];
        }
        final String? entityId = supabase.auth.currentUser?.id;
        final String table = 'financial_conversions';
        final PostgrestFilterBuilder<PostgrestList> filtered = supabase
            .from(table)
            .select();
        final PostgrestTransformBuilder<PostgrestList> query =
            (entityId == null || entityId.isEmpty)
                ? filtered.order('created_at', ascending: false)
                : filtered
                    .eq('entity_id', entityId)
                    .order('created_at', ascending: false);
        final PostgrestList rows = await query;
        return rows.map(CurrencyConversionDto.fromJson).toList(growable: false);
      });
}