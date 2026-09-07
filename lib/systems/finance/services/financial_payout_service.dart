// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/repositories/financial_payout_repository.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [FinancialPayoutRepository] consumed by
/// [FinancialPayoutProvider] (EP-02-16 §5.4).
///
/// Adds PII-safe structured [HivorrLogger] output (currency code, masked
/// account number — never the raw `account_number` or `account_name`) and
/// `finance.payout.*` [PerformanceTracer] spans.
class FinancialPayoutService {
  FinancialPayoutService({
    required FinancialPayoutRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
  })  : _repository = repository,
        _logger = logger,
        _tracer = tracer;

  final FinancialPayoutRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;

  /// The supported currency vocabulary (shared with the profile system).
  static const List<SupportedCurrency> supportedCurrencies =
      SupportedCurrency.values;

  /// Binds a new payout account through the server-authoritative RPC.
  Future<PayoutAccount> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) =>
      _tracedAndLogged(
        'finance.payout.bind',
        () async {
          _logger?.info('Binding payout account', <String, Object?>{
            'currencyCode': currencyCode,
            'bankName': bankName,
            'accountNumber': _mask(accountNumber),
          });
          final PayoutAccount account = await _repository.bindAccount(
            currencyCode: currencyCode,
            bankName: bankName,
            accountNumber: accountNumber,
            accountName: accountName,
          );
          _logger?.info('Payout account bound', <String, Object?>{
            'accountId': _redactor(account.id),
            'currencyCode': account.currencyCode,
            'accountNumber': account.maskedAccountNumber,
          });
          return account;
        },
      );

  /// Lists the local display mirror of bound payout accounts.
  Future<List<PayoutAccount>> listPayoutAccounts() => _tracedAndLogged(
        'finance.payout.list',
        () async {
          final List<PayoutAccount> accounts =
              await _repository.listPayoutAccounts();
          _logger?.info(
            'Bound payout accounts listed',
            <String, Object?>{'count': accounts.length},
          );
          return accounts;
        },
      );

  /// Withdraws to a verified payout account.
  Future<WithdrawalResult> withdraw({
    required String payoutAccountId,
    required double amount,
  }) =>
      _tracedAndLogged(
        'finance.payout.withdraw',
        () async {
          _logger?.info('Initiating withdrawal', <String, Object?>{
            'accountId': _redactor(payoutAccountId),
            'amount': amount,
          });
          final WithdrawalResult result = await _repository.withdraw(
            payoutAccountId: payoutAccountId,
            amount: amount,
          );
          _logger?.info('Withdrawal initiated', <String, Object?>{
            'payoutId': _redactor(result.payoutId),
            'amount': result.amount,
            'netAmount': result.netAmount,
            'cashoutRemaining': result.cashoutRemaining,
          });
          return result;
        },
      );

  /// Masks an account number down to its last four digits.
  static String _mask(String accountNumber) {
    final String trimmed = accountNumber.trim();
    if (trimmed.length <= 4) return '****';
    return '***${trimmed.substring(trimmed.length - 4)}';
  }

  static String _redactor(String value) => PiiRedactor().redact(value);

  /// Wraps [action] in a `finance.payout.*` [PerformanceTracer] span and
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