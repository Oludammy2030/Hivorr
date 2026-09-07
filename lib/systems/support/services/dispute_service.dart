// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [DisputeRepository] consumed by [DisputeProvider] and the
/// dispute screens (EP-02-17 §5.5).
///
/// Exposes the dispute status/type/priority/desired-outcome/evidence-type/
/// resolution-type vocabularies (compile-time const, mirroring the frozen
/// CHECK constraints) plus the fail-fast validators
/// [validateReason]/[validateTitle]/[validateDescription], and delegates data
/// operations to the repository. Adds PII-safe structured [HivorrLogger]
/// output (case id, escrow id, entity-id suffix, status deltas — never full
/// reason, description, or evidence title) and `support.dispute.*`
/// [PerformanceTracer] spans.
class DisputeService {
  DisputeService({
    required DisputeRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  })  : _repository = repository,
        _logger = logger,
        _tracer = tracer,
        _redactor = redactor ?? PiiRedactor();

  final DisputeRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  // ─── Vocabulary (matches frozen CHECK constraints, EP-02-17 §5.5) ───────

  /// The 5-state dispute status vocabulary (CHECK `66-68`).
  static const List<DisputeStatus> disputeStatusList = disputeStatuses;

  /// The 5-type dispute vocabulary (CHECK `62-65`).
  static const List<DisputeType> disputeTypeList = disputeTypes;

  /// The 4+`other` desired-outcome vocabulary (CHECK `71-73`).
  static const List<DesiredOutcome> desiredOutcomeList = desiredOutcomes;

  /// The 4-state priority vocabulary (CHECK `74-75`).
  static const List<DisputePriority> disputePriorityList = disputePriorities;

  /// The 4-type evidence vocabulary (CHECK `112-113`).
  static const List<EvidenceType> evidenceTypeList = evidenceTypes;

  /// The 4-type resolution vocabulary (CHECK `141-143`).
  static const List<ResolutionType> resolutionTypeList = resolutionTypes;

  /// Resolves the display entry for a dispute [status] code.
  DisputeStatus? statusFor(String status) => DisputeStatus.forCode(status);

  /// Resolves the display entry for a dispute [disputeType] code.
  DisputeType? typeFor(String disputeType) => DisputeType.forCode(disputeType);

  /// Resolves the display entry for a [resolutionType] code.
  ResolutionType? resolutionTypeFor(String resolutionType) =>
      ResolutionType.forCode(resolutionType);

  // ─── Fail-fast validators (mirror CHECK `69-70`, `114-117`) ─────────────

  /// `true` when [reason] is 10–2000 chars after trim (CHECK `69-70`).
  static bool validateReason(String reason) {
    final int length = reason.trim().length;
    return length >= 10 && length <= 2000;
  }

  /// `true` when [title] is 1–255 chars (CHECK `114-115`).
  static bool validateTitle(String title) {
    final int length = title.trim().length;
    return length >= 1 && length <= 255;
  }

  /// `true` when [description] is empty or ≤2000 chars (CHECK `116-117`).
  static bool validateDescription(String description) {
    return description.trim().length <= 2000;
  }

  // ─── Data operations (delegate to repository, traced + logged) ──────────

  Future<List<DisputeCase>> listDisputes({String? status}) =>
      _tracedAndLogged(
        'support.dispute.list',
        () async {
          final cases = await _repository.listDisputes(status: status);
          _logger?.info('Dispute list fetched', <String, Object?>{
            'statusFilter': status,
            'disputeCount': cases.length,
          });
          return cases;
        },
      );

  Future<DisputeCaseDetail> getCase(String caseId) => _tracedAndLogged(
        'support.dispute.get',
        () async {
          final detail = await _repository.getCase(caseId);
          _logger?.info('Dispute detail fetched', <String, Object?>{
            'caseId': _redactor.redact(detail.disputeCase.id),
            'escrowId': _redactor.redact(detail.disputeCase.escrowId),
            'status': detail.disputeCase.status,
            'evidenceCount': detail.evidence.length,
          });
          return detail;
        },
      );

  Future<DisputeCase> fileDispute({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  }) =>
      _tracedAndLogged(
        'support.dispute.file',
        () async {
          _logger?.info('Filing dispute', <String, Object?>{
            'escrowId': _redactor.redact(escrowId),
            'disputeType': disputeType,
            'desiredOutcome': desiredOutcome,
            'priority': priority,
          });
          final case_ = await _repository.fileDispute(
            escrowId: escrowId,
            disputeType: disputeType,
            reason: reason,
            desiredOutcome: desiredOutcome,
            priority: priority,
          );
          _logger?.info('Dispute filed — escrow held', <String, Object?>{
            'caseId': _redactor.redact(case_.id),
            'status': case_.status,
          });
          return case_;
        },
      );

  Future<DisputeEvidence> submitEvidence({
    required String caseId,
    required String evidenceType,
    required String title,
    String? description,
    String? fileUrl,
    Map<String, dynamic> fileMetadata = const <String, dynamic>{},
  }) =>
      _tracedAndLogged(
        'support.dispute.submit_evidence',
        () async {
          final evidence = await _repository.submitEvidence(
            caseId: caseId,
            evidenceType: evidenceType,
            title: title,
            description: description,
            fileUrl: fileUrl,
            fileMetadata: fileMetadata,
          );
          _logger?.info('Dispute evidence submitted', <String, Object?>{
            'caseId': _redactor.redact(caseId),
            'evidenceType': evidenceType,
            'hasAttachment': fileUrl != null,
          });
          return evidence;
        },
      );

  Future<DisputeCase> withdrawDispute(String caseId) => _tracedAndLogged(
        'support.dispute.withdraw',
        () async {
          final case_ = await _repository.withdrawDispute(caseId);
          _logger?.info('Dispute withdrawn — escrow released', <String, Object?>{
            'caseId': _redactor.redact(caseId),
            'status': case_.status,
          });
          return case_;
        },
      );

  /// Wraps [action] in a `support.dispute.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'support');
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
