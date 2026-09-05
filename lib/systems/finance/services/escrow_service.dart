// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/repositories/escrow_repository.dart';
import 'package:hivorr/systems/finance/models/escrow_status.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [EscrowRepository] consumed by [EscrowProvider] and
/// future EP-02-15/16 systems (EP-02-14 §5.4).
///
/// Exposes the escrow + milestone status vocabulary and pure milestone-progress
/// math, and delegates data operations to the repository. Adds PII-safe
/// structured [HivorrLogger] output (entity id suffix, escrow id, amounts —
/// never `external_reference` full, never milestone `title` with contract
/// terms) and `finance.escrow.*` [PerformanceTracer] spans.
class EscrowService {
  EscrowService({
    required EscrowRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  })  : _repository = repository,
        _logger = logger,
        _tracer = tracer,
        _redactor = redactor ?? PiiRedactor();

  final EscrowRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  /// Whether the escrow write seam is active (proxy flag).
  bool get escrowWriteAvailable => _repository.writeAvailable;

  /// Resolves the display entry for an escrow [status] code.
  EscrowStatus? statusFor(String status) => EscrowStatus.forCode(status);

  /// Resolves the display entry for a milestone [status] code.
  MilestoneStatus? milestoneStatusFor(String status) =>
      MilestoneStatus.forCode(status);

  /// The 7-state escrow vocabulary (matches the frozen check constraint).
  static const List<EscrowStatus> escrowStatusList = escrowStatuses;

  /// The 3-state milestone vocabulary (matches the frozen check constraint).
  static const List<MilestoneStatus> milestoneStatusList = milestoneStatuses;

  /// Returns `true` when [milestoneAmounts] sum to [totalAmount] within the
  /// `0.01` tolerance (EP-02-14 §5.4 fail-fast check).
  bool validateMilestoneSums({
    required double totalAmount,
    required List<double> milestoneAmounts,
  }) {
    if (milestoneAmounts.isEmpty) return true;
    final double sum = milestoneAmounts.fold(
      0.0,
      (double acc, double amount) => acc + amount,
    );
    return (sum - totalAmount).abs() <= 0.01;
  }

  /// Sum of amounts of `released` milestones (funds actually delivered).
  double releasedMilestoneTotal(List<EscrowMilestone> milestones) =>
      milestones
          .where((EscrowMilestone m) => m.isReleased)
          .fold(0.0, (double sum, EscrowMilestone m) => sum + m.amount);

  /// Sum of amounts of `completed` + `released` milestones (delivered work).
  double completedMilestoneTotal(List<EscrowMilestone> milestones) =>
      milestones
          .where((EscrowMilestone m) => m.isCompleted || m.isReleased)
          .fold(0.0, (double sum, EscrowMilestone m) => sum + m.amount);

  /// Resolves the progress ratio for a milestone list (0.0–1.0), clamped so
  /// a released total never exceeds 1.0 during server-authoritative reads.
  double milestoneProgress({
    required List<EscrowMilestone> milestones,
    required double totalAmount,
  }) {
    if (totalAmount <= 0) return 0.0;
    final double released = releasedMilestoneTotal(milestones);
    return ((released / totalAmount).clamp(0.0, 1.0)).toDouble();
  }

  // ─── Data operations (read live; write behind the proxy seam) ──────────

  Future<EscrowDetail> getById(String id) => _tracedAndLogged(
        'finance.escrow.get',
        () async {
          final detail = await _repository.getById(id);
          _logger?.info('Escrow detail fetched', <String, Object?>{
            'escrowId': _redactor.redact(detail.escrow.id),
            'status': detail.escrow.status,
            'milestoneCount': detail.milestones.length,
            'transactionCount': detail.transactions.length,
          });
          return detail;
        },
      );

  Future<List<Escrow>> getByProject({
    required String projectId,
    required List<String> escrowIds,
  }) =>
      _tracedAndLogged(
        'finance.escrow.list',
        () async {
          final escrows = await _repository.getByProject(
            projectId: projectId,
            escrowIds: escrowIds,
          );
          _logger?.info('Escrow list fetched', <String, Object?>{
            'projectId': _redactor.redact(projectId),
            'escrowCount': escrows.length,
          });
          return escrows;
        },
      );

  Future<EscrowDetail> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) =>
      _tracedAndLogged(
        'finance.escrow.create',
        () async {
          _logger?.info('Creating escrow', <String, Object?>{
            'payerEntityId': _redactor.redact(payerEntityId),
            'payeeEntityId': _redactor.redact(payeeEntityId),
            'currencyCode': currencyCode,
            'totalAmount': totalAmount,
            'milestoneCount': milestones.length,
          });
          final detail = await _repository.createEscrow(
            payerEntityId: payerEntityId,
            payeeEntityId: payeeEntityId,
            currencyCode: currencyCode,
            totalAmount: totalAmount,
            milestones: milestones,
          );
          _logger?.info('Escrow created', <String, Object?>{
            'escrowId': _redactor.redact(detail.escrow.id),
            'status': detail.escrow.status,
          });
          return detail;
        },
      );

  Future<EscrowDetail> completeMilestone({
    required String escrowId,
    required String milestoneId,
  }) =>
      _tracedAndLogged(
        'finance.escrow.milestone.complete',
        () async {
          final detail = await _repository.completeMilestone(
            escrowId: escrowId,
            milestoneId: milestoneId,
          );
          _logger?.info('Milestone completed', <String, Object?>{
            'escrowId': _redactor.redact(escrowId),
            'milestoneId': _redactor.redact(milestoneId),
            'status': detail.escrow.status,
          });
          return detail;
        },
      );

  Future<EscrowDetail> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  }) =>
      _tracedAndLogged(
        'finance.escrow.milestone.release',
        () async {
          final detail = await _repository.releaseMilestone(
            escrowId: escrowId,
            milestoneId: milestoneId,
          );
          _logger?.info('Milestone released', <String, Object?>{
            'escrowId': _redactor.redact(escrowId),
            'status': detail.escrow.status,
          });
          return detail;
        },
      );

  Future<EscrowDetail> releaseFinal({required String escrowId}) =>
      _tracedAndLogged(
        'finance.escrow.releaseFinal',
        () async {
          final detail = await _repository.releaseFinal(escrowId: escrowId);
          _logger?.info('Escrow fully released', <String, Object?>{
            'escrowId': _redactor.redact(escrowId),
            'status': detail.escrow.status,
          });
          return detail;
        },
      );

  Future<EscrowDetail> refundEscrow({
    required String escrowId,
    required String reason,
  }) =>
      _tracedAndLogged(
        'finance.escrow.refund',
        () async {
          final detail = await _repository.refundEscrow(
            escrowId: escrowId,
            reason: reason,
          );
          _logger?.info('Escrow refunded', <String, Object?>{
            'escrowId': _redactor.redact(escrowId),
            'status': detail.escrow.status,
          });
          return detail;
        },
      );

  /// Wraps [action] in a `finance.escrow.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
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