// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/escrow_transaction.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/repositories/escrow_repository.dart';

/// In-memory [EscrowRepository] for provider/widget tests (EP-02-14).
///
/// Serves scripted entities with call counters. Mirrors the real repository's
/// write seam: when [writeAvailable] is `false` every write throws
/// [EscrowWriteUnavailableException] (what `EscrowWriteCtaPanel` guidance
/// anticipates); when `true` writes succeed with the re-read detail.
class FakeEscrowRepository implements EscrowRepository {
  FakeEscrowRepository({
    this.writeAvailable = false,
    EscrowDetail? detail,
    List<Escrow> headers = const <Escrow>[],
  })  : _detail = detail,
        _headers = headers;

  @override
  final bool writeAvailable;

  EscrowDetail? _detail;
  List<Escrow> _headers;

  ApiException? nextError;
  int getByIdCallCount = 0;
  int getByProjectCallCount = 0;
  int createCallCount = 0;
  int completeMilestoneCallCount = 0;
  int releaseMilestoneCallCount = 0;
  int releaseFinalCallCount = 0;
  int refundCallCount = 0;
  String? lastCreateCurrencyCode;
  String? lastMilestoneId;

  /// Replaces the detail served by [getById].
  void setDetail(EscrowDetail? detail) => _detail = detail;

  /// Replaces the headers served by [getByProject].
  void setHeaders(List<Escrow> headers) => _headers = headers;

  @override
  Future<EscrowDetail> getById(String id) async {
    getByIdCallCount++;
    if (nextError != null) throw nextError!;
    return _detail ?? seedEscrowDetailEntity(id: id);
  }

  @override
  Future<List<Escrow>> getByProject({
    required String projectId,
    required List<String> escrowIds,
  }) async {
    getByProjectCallCount++;
    if (nextError != null) throw nextError!;
    return _headers;
  }

  @override
  Future<EscrowDetail> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) async {
    createCallCount++;
    lastCreateCurrencyCode = currencyCode;
    if (nextError != null) throw nextError!;
    if (!writeAvailable) throw const EscrowWriteUnavailableException();
    final EscrowDetail detail =
        _detail ?? seedEscrowDetailEntity(totalAmount: totalAmount);
    _detail = detail;
    return detail;
  }

  @override
  Future<EscrowDetail> completeMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    completeMilestoneCallCount++;
    lastMilestoneId = milestoneId;
    if (nextError != null) throw nextError!;
    if (!writeAvailable) throw const EscrowWriteUnavailableException();
    return _detail ?? seedEscrowDetailEntity(id: escrowId);
  }

  @override
  Future<EscrowDetail> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    releaseMilestoneCallCount++;
    lastMilestoneId = milestoneId;
    if (nextError != null) throw nextError!;
    if (!writeAvailable) throw const EscrowWriteUnavailableException();
    return _detail ?? seedEscrowDetailEntity(id: escrowId);
  }

  @override
  Future<EscrowDetail> releaseFinal({required String escrowId}) async {
    releaseFinalCallCount++;
    if (nextError != null) throw nextError!;
    if (!writeAvailable) throw const EscrowWriteUnavailableException();
    return _detail ?? seedEscrowDetailEntity(id: escrowId);
  }

  @override
  Future<EscrowDetail> refundEscrow({
    required String escrowId,
    required String reason,
  }) async {
    refundCallCount++;
    if (nextError != null) throw nextError!;
    if (!writeAvailable) throw const EscrowWriteUnavailableException();
    return _detail ?? seedEscrowDetailEntity(id: escrowId);
  }
}

/// Fixture builders shared across the escrow tests (EP-02-14).
Escrow seedEscrowEntity({
  String id = 'escrow-1',
  String financialProfileId = 'profile-1',
  String payerEntityId = 'entity-payer',
  String payeeEntityId = 'entity-payee',
  String currencyCode = 'NGN',
  double totalAmount = 50000,
  double releasedAmount = 0,
  double refundedAmount = 0,
  String status = 'funded',
  String? externalReference = 'ORD-2026-000123',
}) =>
    Escrow(
      id: id,
      financialProfileId: financialProfileId,
      payerEntityId: payerEntityId,
      payeeEntityId: payeeEntityId,
      currencyCode: currencyCode,
      totalAmount: totalAmount,
      releasedAmount: releasedAmount,
      refundedAmount: refundedAmount,
      status: status,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      externalReference: externalReference,
    );

EscrowMilestone seedMilestoneEntity({
  String id = 'ms-1',
  String escrowId = 'escrow-1',
  int milestoneNumber = 1,
  String title = 'Design sign-off',
  String? description,
  double amount = 50000,
  String status = 'pending',
  int sortOrder = 1,
}) =>
    EscrowMilestone(
      id: id,
      escrowId: escrowId,
      milestoneNumber: milestoneNumber,
      title: title,
      description: description,
      amount: amount,
      status: status,
      sortOrder: sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

EscrowTransaction seedTransactionEntity({
  String id = 'txn-1',
  String escrowId = 'escrow-1',
  String type = 'release',
  double amount = 25000,
  String direction = 'out',
  String entityId = 'entity-payee',
  String reference = 'RELEASE-1',
}) =>
    EscrowTransaction(
      id: id,
      escrowId: escrowId,
      type: type,
      amount: amount,
      direction: direction,
      entityId: entityId,
      reference: reference,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

EscrowDetail seedEscrowDetailEntity({
  String id = 'escrow-1',
  double totalAmount = 50000,
  double releasedAmount = 0,
  String status = 'funded',
  List<EscrowMilestone> milestones = const <EscrowMilestone>[],
  List<EscrowTransaction> transactions = const <EscrowTransaction>[],
}) =>
    EscrowDetail(
      escrow: seedEscrowEntity(
        id: id,
        totalAmount: totalAmount,
        releasedAmount: releasedAmount,
        status: status,
      ),
      milestones: milestones,
      transactions: transactions,
    );