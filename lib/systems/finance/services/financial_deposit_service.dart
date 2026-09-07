// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [FinancialDepositRepository] consumed by
/// [FinancialDepositProvider] (EP-02-16).
///
/// Read-only. Logs aggregate counts only — never the raw `payer_name`
/// (deposit payer names are PII).
class FinancialDepositService {
  FinancialDepositService({
    required FinancialDepositRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
  })  : _repository = repository,
        _logger = logger,
        _tracer = tracer;

  final FinancialDepositRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;

  /// Lists the authenticated entity's deposits (RLS-scoped read).
  Future<List<Deposit>> listDeposits() => _tracedAndLogged(
        'finance.deposit.list',
        () async {
          final List<Deposit> deposits = await _repository.listDeposits();
          _logger?.info('Deposits listed', <String, Object?>{
            'count': deposits.length,
            'matched': deposits
                .where((Deposit d) => d.status == 'credited')
                .length,
          });
          return deposits;
        },
      );

  /// Wraps [action] in a `finance.deposit.*` [PerformanceTracer] span and
  /// surfaces failures via the logger.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'finance');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'span': name},
      );
      rethrow;
    }
  }
}