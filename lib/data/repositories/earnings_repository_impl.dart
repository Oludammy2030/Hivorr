// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';import 'package:hivorr/data/datasources/local/earnings_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/earnings_remote_data_source.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/mappers/earnings_mapper.dart';
import 'package:hivorr/data/models/earnings_summary_dto.dart';
import 'package:hivorr/data/models/earnings_transaction_dto.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Default implementation of [EarningsRepository] (EP-03-16).
///
/// Network-first with a transient write-through window: successful reads are
/// cached for offline display and release-event coherence; a failed network
/// read falls back to the cached value when one exists and rethrows the
/// typed [ApiException] otherwise. The cache is display-only — the RPC
/// remains the sole aggregation authority (AGENT.md Rule 4).
class EarningsRepositoryImpl implements EarningsRepository {
  EarningsRepositoryImpl({
    required EarningsRemoteDataSource remote,
    EarningsLocalDataSource? local,
  }) : _remote = remote,
       _local = local ?? InMemoryEarningsLocalDataSource();

  final EarningsRemoteDataSource _remote;
  final EarningsLocalDataSource _local;

  @override
  Future<EarningsSummary> getSummary(String currencyCode) async {
    _requireSupportedCurrency(currencyCode);
    try {
      final EarningsSummaryDto dto = await _remote.getSummary(currencyCode);
      await _local.saveSummary(currencyCode, dto);
      return EarningsMapper.summaryToEntity(dto);
    } on ApiException {
      final EarningsSummaryDto? cached = await _local.getSummary(currencyCode);
      if (cached != null) {
        return EarningsMapper.summaryToEntity(cached);
      }
      rethrow;
    }
  }

  @override
  Future<EarningsSummary?> getCachedSummary(String currencyCode) async {
    final EarningsSummaryDto? cached = await _local.getSummary(currencyCode);
    if (cached == null) return null;
    return EarningsMapper.summaryToEntity(cached);
  }

  @override
  Future<EarningsTransactionPage> listTransactions({
    required String currencyCode,
    String type = EarningsHistoryFilter.all,
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    Map<String, dynamic>? cursor,
  }) async {
    _requireSupportedCurrency(currencyCode);
    if (!EarningsHistoryFilter.isSupported(type)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Unsupported history filter.',
        code: 'PLT003',
      );
    }
    final String key = historyCacheKey(
      currencyCode: currencyCode,
      type: type,
      contractId: contractId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      limit: limit,
      cursor: cursor,
    );
    try {
      final EarningsTransactionPageDto dto = await _remote.listTransactions(
        currencyCode: currencyCode,
        type: type,
        contractId: contractId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: limit,
        cursor: cursor,
      );
      await _local.savePage(key, dto);
      return EarningsMapper.pageToEntity(dto);
    } on ApiException {
      final EarningsTransactionPageDto? cached = await _local.getPage(key);
      if (cached != null) {
        return EarningsMapper.pageToEntity(cached);
      }
      rethrow;
    }
  }

  @override
  Future<EarningsTransactionPage?> getCachedPage(String cacheKey) async {
    final EarningsTransactionPageDto? cached = await _local.getPage(cacheKey);
    if (cached == null) return null;
    return EarningsMapper.pageToEntity(cached);
  }

  @override
  String historyCacheKey({
    required String currencyCode,
    required String type,
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    required int limit,
    Map<String, dynamic>? cursor,
  }) {
    final StringBuffer key = StringBuffer(
      '$currencyCode|$type|${contractId ?? ''}|'
      '${dateFrom?.toIso8601String() ?? ''}|'
      '${dateTo?.toIso8601String() ?? ''}|$limit',
    );
    if (cursor != null) {
      key.write('|${cursor['created_at']}|${cursor['id']}');
    }
    return key.toString();
  }

  @override
  Future<void> invalidateCache() => _local.invalidate();

  void _requireSupportedCurrency(String currencyCode) {
    if (!SupportedCurrency.isSupported(currencyCode)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message:
            'Unsupported currency. Supported currencies are NGN, GHS, USD, GBP.',
        code: 'PLT003',
      );
    }
  }
}
