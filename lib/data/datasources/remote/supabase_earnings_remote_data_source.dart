import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/earnings_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/financial_envelope_parser.dart';
import 'package:hivorr/data/models/earnings_summary_dto.dart';
import 'package:hivorr/data/models/earnings_transaction_dto.dart';

/// Supabase-backed implementation of [EarningsRemoteDataSource] (EP-03-16).
///
/// Accesses Supabase **only** through the injected [BaseApiService] accessors
/// (never constructs clients). Every read goes through the earnings RPCs
/// (`service_earnings_summary` / `service_transaction_history`) — never a
/// direct `financial_transactions` table read. Aggregation stays
/// server-authoritative (AGENT.md Rule 4).
class SupabaseEarningsRemoteDataSource extends BaseApiService
    implements EarningsRemoteDataSource {
  SupabaseEarningsRemoteDataSource({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw mapDataException(e);
    }
  }

  @override
  Future<EarningsSummaryDto> getSummary(String currencyCode) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_earnings_summary',
          params: <String, dynamic>{'p_currency_code': currencyCode},
        );
    final Map<String, dynamic> data = FinancialEnvelopeParser.unwrap(response);
    return EarningsSummaryDto.fromJson(data);
  });

  @override
  Future<EarningsTransactionPageDto> listTransactions({
    required String currencyCode,
    String type = 'all',
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    Map<String, dynamic>? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> filters = <String, dynamic>{'type': type};
    if (contractId != null && contractId.isNotEmpty) {
      filters['contract_id'] = contractId;
    }
    if (dateFrom != null) {
      filters['date_from'] = dateFrom.toIso8601String();
    }
    if (dateTo != null) {
      filters['date_to'] = dateTo.toIso8601String();
    }
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_transaction_history',
          params: <String, dynamic>{
            'p_currency_code': currencyCode,
            'p_filters': filters,
            'p_limit': limit,
            'p_cursor': cursor,
          },
        );
    final Map<String, dynamic> data = FinancialEnvelopeParser.unwrap(response);
    return EarningsTransactionPageDto.fromJson(data);
  });
}
