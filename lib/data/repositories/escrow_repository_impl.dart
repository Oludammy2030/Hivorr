// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/escrow_remote_data_source.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/mappers/escrow_mapper.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/repositories/escrow_repository.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Default implementation of [EscrowRepository].
///
/// Implements the server-authoritative escrow flow (EP-02-14 §5.3): reads via
/// `financial_escrow_get` mapped through [EscrowMapper]; writes staged behind
/// the [EscrowRemoteDataSource.writeViaProxy] seam. The milestone-sum
/// invariant is pre-validated client-side (tolerance `0.01`) so a known
/// `PLT003` violation never round-trips. This implementation never writes
/// escrow tables directly (AGENT.md Rule 4).
class EscrowRepositoryImpl implements EscrowRepository {
  EscrowRepositoryImpl({required EscrowRemoteDataSource remote})
      : _remote = remote;

  final EscrowRemoteDataSource _remote;

  @override
  bool get writeAvailable => _remote.writeViaProxy;

  @override
  Future<EscrowDetail> getById(String id) async {
    final dto = await _remote.getById(id);
    return EscrowMapper.detailToEntity(dto);
  }

  @override
  Future<List<Escrow>> getByProject({
    required String projectId,
    required List<String> escrowIds,
  }) async {
    final dtos = await _remote.getByProject(escrowIds);
    return dtos.map(EscrowMapper.escrowToEntity).toList(growable: false);
  }

  @override
  Future<EscrowDetail> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) async {
    _validateCurrency(currencyCode);
    _validateMilestoneSums(totalAmount, milestones);
    final String createdEscrowId = await _remote.createEscrow(
      payerEntityId: payerEntityId,
      payeeEntityId: payeeEntityId,
      currencyCode: currencyCode,
      totalAmount: totalAmount,
      milestones: milestones,
    );
    // Re-read the created escrow to confirm server state (server-authoritative).
    return getById(createdEscrowId);
  }

  @override
  Future<EscrowDetail> completeMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    await _remote.completeMilestone(
      escrowId: escrowId,
      milestoneId: milestoneId,
    );
    return getById(escrowId);
  }

  @override
  Future<EscrowDetail> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    await _remote.releaseMilestone(
      escrowId: escrowId,
      milestoneId: milestoneId,
    );
    return getById(escrowId);
  }

  @override
  Future<EscrowDetail> releaseFinal({required String escrowId}) async {
    await _remote.releaseFinal(escrowId: escrowId);
    return getById(escrowId);
  }

  @override
  Future<EscrowDetail> refundEscrow({
    required String escrowId,
    required String reason,
  }) async {
    await _remote.refundEscrow(escrowId: escrowId, reason: reason);
    return getById(escrowId);
  }

  static void _validateCurrency(String currencyCode) {
    if (!SupportedCurrency.isSupported(currencyCode)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message:
            'Unsupported currency. Supported currencies are NGN, GHS, USD, GBP.',
        code: 'PLT003',
      );
    }
  }

  static void _validateMilestoneSums(
    double totalAmount,
    List<EscrowMilestoneInput> milestones,
  ) {
    // The server accepts a milestone-less escrow (`p_milestones` nullable);
    // the sum invariant only applies when milestones are supplied.
    if (milestones.isEmpty) return;
    final double sum = milestones.fold(
      0.0,
      (double acc, EscrowMilestoneInput m) => acc + m.amount,
    );
    if ((sum - totalAmount).abs() > 0.01) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Milestone amounts must sum to the escrow total.',
        code: 'PLT003',
      );
    }
  }
}