// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job_quotation.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/systems/jobs/models/job_status.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [HireRepository] consumed by [HireProvider] and the hiring
/// screens (EP-04-02).
///
/// Exposes the quotation/hire status vocabularies (compile-time const,
/// mirroring the frozen CHECK constraints) plus the fail-fast validator
/// [validateAmount], and delegates data operations to the repository. Adds
/// PII-safe structured [HivorrLogger] output and `hiring.*`
/// [PerformanceTracer] spans.
class HireService {
  HireService({
    required HireRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  }) : _repository = repository,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor();

  final HireRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  // ─── Vocabulary (matches frozen CHECK constraints, EP-04-02) ──────────

  /// The 4-state quotation status vocabulary.
  static const List<String> quotationStatusList = quotationStatusCodes;

  /// The 5-state hire status vocabulary.
  static const List<String> hireStatusList = hireStatusCodes;

  /// Resolves the display entry for a hiring [code].
  HiringStatus? statusFor(String code) => HiringStatus.forCode(code);

  // ─── Fail-fast validator (mirrors CHECK amount > 0) ───────────────────

  /// `true` when [amount] is greater than zero.
  static bool validateAmount(double? amount) => amount != null && amount > 0;

  // ─── Data operations (delegate to repository, traced + logged) ────────

  Future<JobQuotation> proposeQuotation({
    required String applicationId,
    required double amount,
    String currencyCode = 'NGN',
    int? durationDays,
    String? message,
  }) => _tracedAndLogged('hiring.quotation_propose', () async {
    final JobQuotation quotation = await _repository.proposeQuotation(
      applicationId: applicationId,
      amount: amount,
      currencyCode: currencyCode,
      durationDays: durationDays,
      message: message,
    );
    _logger?.info('Quotation proposed', <String, Object?>{
      'quotationId': _redactor.redact(quotation.id),
      'revision': quotation.revisionNumber,
    });
    return quotation;
  });

  Future<JobQuotation> withdrawQuotation(String quotationId) =>
      _tracedAndLogged('hiring.quotation_withdraw', () async {
        return _repository.withdrawQuotation(quotationId);
      });

  Future<JobQuotation> acceptQuotation(String quotationId) =>
      _tracedAndLogged('hiring.quotation_accept', () async {
        final JobQuotation quotation = await _repository.acceptQuotation(
          quotationId,
        );
        _logger?.info('Quotation accepted', <String, Object?>{
          'quotationId': _redactor.redact(quotationId),
        });
        return quotation;
      });

  Future<HireAcceptResult> acceptHire(
    String applicationId, {
    String? quotationId,
  }) => _tracedAndLogged('hiring.accept', () async {
    final HireAcceptResult result = await _repository.acceptHire(
      applicationId,
      quotationId: quotationId,
    );
    _logger?.info('Professional hired', <String, Object?>{
      'hireId': _redactor.redact(result.hire.id),
      'contractId': _redactor.redact(result.contractId),
    });
    return result;
  });

  Future<HireDetail> getHire(String hireId) =>
      _tracedAndLogged('hiring.get', () async {
        final HireDetail detail = await _repository.getHire(hireId);
        _logger?.info('Hire detail fetched', <String, Object?>{
          'hireId': _redactor.redact(hireId),
          'effectiveStatus': detail.effectiveStatus,
        });
        return detail;
      });

  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) => _tracedAndLogged('hiring.list_mine', () async {
    return _repository.listMyHires(
      role: role,
      status: status,
      limit: limit,
      cursor: cursor,
    );
  });

  Future<Hire> cancelHire(String hireId, {String? reason}) =>
      _tracedAndLogged('hiring.cancel', () async {
        final Hire hire = await _repository.cancelHire(hireId, reason: reason);
        _logger?.info('Hire cancelled', <String, Object?>{
          'hireId': _redactor.redact(hireId),
        });
        return hire;
      });

  Future<Hire> completeHire(String hireId) =>
      _tracedAndLogged('hiring.complete', () async {
        final Hire hire = await _repository.completeHire(hireId);
        _logger?.info('Hire completed', <String, Object?>{
          'hireId': _redactor.redact(hireId),
        });
        return hire;
      });

  /// Wraps [action] in a `hiring.*` [PerformanceTracer] span and surfaces
  /// failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'hiring');
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
