// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/account_activation_guidance.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/data/repositories/financial_repository.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [FinancialRepository] consumed by [FinancialProvider]
/// and future EP-02-14/15/16 systems (EP-02-13 §5.4).
///
/// Exposes supported-currency vocabulary and delegates data operations to the
/// repository. Adds PII-safe structured [HivorrLogger] output (entity id
/// suffix, currency code, balance values — never `legal_name` or raw account
/// numbers) and `finance.*.get`/`finance.profile.create` [PerformanceTracer]
/// spans (EP-02-13 §5.4 / TV-14).
class FinancialService {
  FinancialService({
    required FinancialRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  })  : _repository = repository,
        _logger = logger,
        _tracer = tracer,
        _redactor = redactor ?? PiiRedactor();

  final FinancialRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  /// The supported currency vocabulary, data-driven from
  /// `financial_supported_currencies`.
  static const List<SupportedCurrency> supportedCurrencies =
      SupportedCurrency.values;

  /// Whether [currencyCode] is in the supported set.
  static bool isCurrencySupported(String currencyCode) =>
      SupportedCurrency.isSupported(currencyCode);

  /// Fetches the financial profile.
  Future<FinancialProfile?> getProfile() => _tracedAndLogged(
        'finance.profile.get',
        () async {
          final profile = await _repository.getProfile();
          _logger?.info('Financial profile fetched', <String, Object?>{
            'hasProfile': profile != null,
            'status': profile?.status,
            'defaultCurrency': profile?.defaultCurrency,
            'entityId':
                profile == null ? null : _redactor.redact(profile.entityId),
          });
          return profile;
        },
      );

  /// Fetches the aggregated financial status.
  Future<FinancialStatus> getStatus() => _tracedAndLogged(
        'finance.status.get',
        () async {
          final status = await _repository.getStatus();
          _logger?.info('Financial status fetched', <String, Object?>{
            'balanceCount': status.balances.length,
            'activeEscrowCount': status.activeEscrowCount,
            'cashoutLimit': status.cashoutLimit,
          });
          return status;
        },
      );

  /// Fetches a single-currency balance.
  Future<Balance?> getBalance(String currencyCode) => _tracedAndLogged(
        'finance.balance.get',
        () async {
          final balance = await _repository.getBalance(currencyCode);
          _logger?.info('Balance fetched', <String, Object?>{
            'currencyCode': currencyCode,
            'hasBalance': balance != null,
            'available': balance?.availableBalance,
          });
          return balance;
        },
      );

  /// Creates a financial profile with a default currency.
  Future<FinancialProfile> createProfile({
    String defaultCurrency = 'NGN',
  }) =>
      _tracedAndLogged(
        'finance.profile.create',
        () async {
          _logger?.info('Creating financial profile', <String, Object?>{
            'defaultCurrency': defaultCurrency,
          });
          final profile = await _repository.createProfile(
            defaultCurrency: defaultCurrency,
          );
          _logger?.info('Financial profile created', <String, Object?>{
            'profileId': _redactor.redact(profile.id),
            'defaultCurrency': profile.defaultCurrency,
            'entityId': _redactor.redact(profile.entityId),
          });
          return profile;
        },
      );

  /// Requests activation guidance for a pending account in [currencyCode].
  Future<AccountActivationGuidance> requestAccountActivation({
    required String currencyCode,
  }) =>
      _tracedAndLogged(
        'finance.account.activation',
        () async {
          final guidance = await _repository.requestAccountActivation(
            currencyCode: currencyCode,
          );
          _logger?.info('Account activation guidance resolved',
              <String, Object?>{
                'currencyCode': guidance.currencyCode,
                'providerName': guidance.providerName,
              });
          return guidance;
        },
      );

  /// Wraps [action] in a `finance.*` [PerformanceTracer] span and surfaces
  /// failures via the logger with redacted context.
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
