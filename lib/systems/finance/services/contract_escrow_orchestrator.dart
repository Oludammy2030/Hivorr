// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_state.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;
import 'package:uuid/uuid.dart';

/// Verification-gated escrow release orchestrator (EP-03-11 §7).
///
/// Sequences the two server-authoritative halves of milestone settlement
/// without deciding either of them:
///
///  1. Verification half — [ContractService] (`service_contract_get`,
///     `service_contract_verify_milestone`; authenticated, participant-gated).
///  2. Fund-movement half — [EscrowService] (`financial_escrow_get` read +
///     proxy-seamed `releaseMilestone` (privileged release service server-side).
///
/// Rules (mirroring `service_contract_release_gate` fail-closed order):
/// disputed -> not-funded -> not-verified -> write-unavailable. The
/// orchestrator never computes balances, never synthesizes `verified`, and
/// never calls a `financial_escrow_*` write RPC directly — every fund
/// movement goes through [EscrowService.releaseMilestone] so the
/// `writeViaProxy` seam stays honest (`AGENT.md` Rule 4). Each sequence
/// carries an `Idempotency-Key: uuid v4` that the proxy/server dedupes on
/// `(contract_id, milestone_id, action)`.
///
/// Escrow linkage (`service_contracts.escrow_id` backfill) is a privileged
/// platform-side operation performed server-side on fund; [ensureEscrowLinked] is therefore
/// a read-only check from the client — it reports `not-funded` guidance when
/// unlinked and never attempts an authenticated link RPC (which correctly
/// returns `PLT002`).
class ContractEscrowOrchestrator {
  ContractEscrowOrchestrator({
    required ContractService contracts,
    required EscrowService escrows,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _contracts = contracts,
       _escrows = escrows,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor(),
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  final ContractService _contracts;
  final EscrowService _escrows;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Whether the Edge proxy write seam is on (read once per call site).
  bool get writeAvailable => _escrows.escrowWriteAvailable;

  /// Generates an idempotency key for one release sequence.
  String newIdempotencyKey() => _uuid.v4();

  /// Read-only linkage check: linked, or `not-funded` guidance.
  ///
  /// Never attempts the privileged-only link RPC from the client.
  Future<ContractEscrowReleaseState> ensureEscrowLinked(
    String contractId,
  ) => _tracedAndLogged('finance.contract-escrow.link', () async {
    final ServiceContract contract = await _contracts.getContract(
      contractId,
    );
    if (contract.escrowId == null) {
      _logger?.info('Escrow not yet linked', <String, Object?>{
        'contractId': _redactor.redact(contractId),
      });
      return ContractEscrowReleaseState(
        contractId: contractId,
        milestoneId: '',
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.notFunded,
        message:
            'Funding is pending for this contract. Release unlocks after the client funds escrow.',
        code: 'PLT005',
        serverTimestamp: _clock(),
      );
    }
    return ContractEscrowReleaseState(
      contractId: contract.id,
      milestoneId: '',
      escrowId: contract.escrowId,
      phase: ContractEscrowReleasePhase.idle,
      message: 'Escrow linked.',
      code: 'PLT000',
      serverTimestamp: _clock(),
    );
  });

  /// Read-only pre-flight projection for one milestone (no fund movement).
  Future<ContractEscrowReleaseState> checkReleaseState({
    required String contractId,
    required String milestoneId,
  }) => _tracedAndLogged('finance.contract-escrow.check', () async {
    final ServiceContract contract = await _contracts.getContract(
      contractId,
    );
    return _project(contract, milestoneId);
  });

  /// Verifies (when `completed`) then releases one milestone.
  ///
  /// Sequence: re-read contract -> fail-closed projection -> `verify`
  /// (client acceptance, only from `completed`) -> proxy `releaseMilestone`
  /// -> re-read escrow + contract. Any refusal returns `blocked` before fund
  /// movement. Throws [ApiException]/[EscrowWriteUnavailableException] only
  /// for transport/server failures after passing pre-flight.
  Future<ContractEscrowReleaseState> verifyAndReleaseMilestone({
    required String contractId,
    required String milestoneId,
    String? idempotencyKey,
  }) => _tracedAndLogged('finance.contract-escrow.verify-release', () async {
    final String idempotency = idempotencyKey ?? newIdempotencyKey();
    _logger?.info('Release sequence started', <String, Object?>{
      'contractId': _redactor.redact(contractId),
      'milestoneId': _redactor.redact(milestoneId),
      'idempotencyKey': _redactor.redact(idempotency),
    });

    ServiceContract contract = await _contracts.getContract(contractId);
    ContractEscrowReleaseState projected = _project(contract, milestoneId);
    if (projected.phase == ContractEscrowReleasePhase.blocked) {
      return projected;
    }

    final String status = _milestoneStatus(contract, milestoneId);
    // Client acceptance first (server decides; no-op when already verified).
    if (status == 'completed') {
      try {
        contract = await _contracts.verifyMilestone(
          contractId: contractId,
          milestoneId: milestoneId,
        );
      } on ApiException catch (e) {
        return ContractEscrowReleaseState(
          contractId: contractId,
          milestoneId: milestoneId,
          escrowId: contract.escrowId,
          phase: ContractEscrowReleasePhase.blocked,
          blockReason: _blockReasonFor(e),
          message: e.message,
          code: e.code ?? 'PLT005',
          serverTimestamp: _clock(),
        );
      }
      projected = _project(contract, milestoneId);
      if (projected.phase == ContractEscrowReleasePhase.blocked) {
        return projected;
      }
    }

    final String? escrowId = contract.escrowId;
    final String? escrowMilestoneId = _escrowMilestoneId(
      contract,
      milestoneId,
    );
    if (escrowId == null || escrowMilestoneId == null) {
      return ContractEscrowReleaseState(
        contractId: contractId,
        milestoneId: milestoneId,
        escrowId: escrowId,
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.notFunded,
        message:
            'Funding is pending for this contract. Release unlocks after the client funds escrow.',
        code: 'PLT005',
        serverTimestamp: _clock(),
      );
    }

    EscrowDetail released;
    try {
      released = await _escrows.releaseMilestone(
        escrowId: escrowId,
        milestoneId: escrowMilestoneId,
      );
    } on EscrowWriteUnavailableException {
      return ContractEscrowReleaseState(
        contractId: contractId,
        milestoneId: milestoneId,
        escrowId: escrowId,
        escrowMilestoneId: escrowMilestoneId,
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.writeUnavailable,
        message:
            'Releases are processed by the platform release service. Contact support to complete this release.',
        code: 'PLT002',
        serverTimestamp: _clock(),
      );
    } on ApiException catch (e) {
      final bool alreadyReleased =
          e.kind == ApiExceptionKind.conflict ||
          (e.message.toLowerCase().contains('already'));
      return ContractEscrowReleaseState(
        contractId: contractId,
        milestoneId: milestoneId,
        escrowId: escrowId,
        escrowMilestoneId: escrowMilestoneId,
        phase: alreadyReleased
            ? ContractEscrowReleasePhase.blocked
            : ContractEscrowReleasePhase.failed,
        blockReason: alreadyReleased
            ? ContractEscrowBlockReason.alreadyReleased
            : null,
        message: e.message,
        code: e.code ?? 'PLT005',
        serverTimestamp: _clock(),
      );
    }

    // Post-release re-read confirms the server state (no client math).
    contract = await _contracts.getContract(contractId);
    _logger?.info('Release sequence completed', <String, Object?>{
      'contractId': _redactor.redact(contractId),
      'milestoneId': _redactor.redact(milestoneId),
      'escrowStatus': released.escrow.status,
    });
    return ContractEscrowReleaseState(
      contractId: contractId,
      milestoneId: milestoneId,
      escrowId: escrowId,
      escrowMilestoneId: escrowMilestoneId,
      phase: ContractEscrowReleasePhase.released,
      releasedAmount: _releasedAmountFor(contract, milestoneId),
      message: 'Milestone released.',
      code: 'PLT000',
      serverTimestamp: _clock(),
    );
  });

  /// Releases every currently-`verified` milestone of a contract.
  ///
  /// Iterates the server-ordered milestone list; each item runs the same
  /// fail-closed sequence as [verifyAndReleaseMilestone]. Never throws for
  /// per-item refusals — they are returned as `blocked` states.
  Future<List<ContractEscrowReleaseState>> releaseVerifiedMilestones(
    String contractId,
  ) => _tracedAndLogged('finance.contract-escrow.release-verified', () async {
    final ServiceContract contract = await _contracts.getContract(
      contractId,
    );
    final List<ContractEscrowReleaseState> results =
        <ContractEscrowReleaseState>[];
    for (final m in contract.milestones) {
      if (m.status != 'verified') continue;
      results.add(
        await verifyAndReleaseMilestone(
          contractId: contractId,
          milestoneId: m.id,
        ),
      );
    }
    return results;
  });

  /// Re-reads the authoritative contract (countdown + badge refresh hook).
  Future<ServiceContract> refreshReleaseStates(String contractId) =>
      _tracedAndLogged('finance.contract-escrow.refresh', () async {
        return _contracts.getContract(contractId);
      });

  // ─── Fail-closed projection (client mirror; server gate decides) ─────────

  ContractEscrowReleaseState _project(
    ServiceContract contract,
    String milestoneId,
  ) {
    final now = _clock();
    String? status;
    String? escrowMilestoneId;
    for (final m in contract.milestones) {
      if (m.id == milestoneId) {
        status = m.status;
        escrowMilestoneId = m.escrowMilestoneId;
        break;
      }
    }
    if (status == null) {
      return ContractEscrowReleaseState(
        contractId: contract.id,
        milestoneId: milestoneId,
        escrowId: contract.escrowId,
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.notVerified,
        message: 'Milestone not found on this contract.',
        code: 'PLT004',
        serverTimestamp: now,
      );
    }
    if (contract.isDisputed) {
      return ContractEscrowReleaseState(
        contractId: contract.id,
        milestoneId: milestoneId,
        escrowId: contract.escrowId,
        escrowMilestoneId: escrowMilestoneId,
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.disputed,
        message:
            'This contract is frozen pending dispute resolution. Releases resume after resolution.',
        code: 'PLT005',
        serverTimestamp: now,
      );
    }
    if (status == 'released') {
      return ContractEscrowReleaseState(
        contractId: contract.id,
        milestoneId: milestoneId,
        escrowId: contract.escrowId,
        escrowMilestoneId: escrowMilestoneId,
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.alreadyReleased,
        message: 'This milestone has already been released.',
        code: 'PLT005',
        serverTimestamp: now,
      );
    }
    if (contract.escrowId == null || escrowMilestoneId == null) {
      return ContractEscrowReleaseState(
        contractId: contract.id,
        milestoneId: milestoneId,
        escrowId: contract.escrowId,
        escrowMilestoneId: escrowMilestoneId,
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.notFunded,
        message:
            'Funding is pending for this contract. Release unlocks after the client funds escrow.',
        code: 'PLT005',
        serverTimestamp: now,
      );
    }
    if (status != 'completed' && status != 'verified') {
      return ContractEscrowReleaseState(
        contractId: contract.id,
        milestoneId: milestoneId,
        escrowId: contract.escrowId,
        escrowMilestoneId: escrowMilestoneId,
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.notVerified,
        message:
            'This milestone needs client verification before its funds can be released.',
        code: 'PLT005',
        serverTimestamp: now,
      );
    }
    if (!writeAvailable) {
      return ContractEscrowReleaseState(
        contractId: contract.id,
        milestoneId: milestoneId,
        escrowId: contract.escrowId,
        escrowMilestoneId: escrowMilestoneId,
        phase: ContractEscrowReleasePhase.blocked,
        blockReason: ContractEscrowBlockReason.writeUnavailable,
        message:
            'Releases are processed by the platform release service. Contact support to complete this release.',
        code: 'PLT002',
        serverTimestamp: now,
      );
    }
    return ContractEscrowReleaseState(
      contractId: contract.id,
      milestoneId: milestoneId,
      escrowId: contract.escrowId,
      escrowMilestoneId: escrowMilestoneId,
      phase: ContractEscrowReleasePhase.idle,
      message: status == 'verified'
          ? 'Verified. Ready to release.'
          : 'Completed. Verify to release.',
      code: 'PLT000',
      serverTimestamp: now,
    );
  }

  String _milestoneStatus(ServiceContract contract, String milestoneId) {
    for (final m in contract.milestones) {
      if (m.id == milestoneId) return m.status;
    }
    return '';
  }

  String? _escrowMilestoneId(ServiceContract contract, String milestoneId) {
    for (final m in contract.milestones) {
      if (m.id == milestoneId) return m.escrowMilestoneId;
    }
    return null;
  }

  double? _releasedAmountFor(ServiceContract contract, String milestoneId) {
    for (final m in contract.milestones) {
      if (m.id == milestoneId) return m.amount;
    }
    return null;
  }

  ContractEscrowBlockReason _blockReasonFor(ApiException e) {
    switch (e.kind) {
      case ApiExceptionKind.forbidden:
        return ContractEscrowBlockReason.writeUnavailable;
      case ApiExceptionKind.notFound:
        return ContractEscrowBlockReason.notVerified;
      case ApiExceptionKind.conflict:
        return e.message.toLowerCase().contains('disput')
            ? ContractEscrowBlockReason.disputed
            : ContractEscrowBlockReason.notVerified;
      case ApiExceptionKind.auth:
      case ApiExceptionKind.validation:
      case ApiExceptionKind.network:
      case ApiExceptionKind.timeout:
      case ApiExceptionKind.server:
      case ApiExceptionKind.unknown:
        return ContractEscrowBlockReason.notVerified;
    }
  }

  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'finance');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: const SpanStatus.internalError());
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
