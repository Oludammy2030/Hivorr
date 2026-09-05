// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/escrow_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/models/escrow_transaction_dto.dart';

/// In-memory [EscrowRemoteDataSource] for repository tests (EP-02-14).
///
/// Serves scripted details keyed by escrow id with call counters. Mirrors the
/// real datasource's write seam: when [writeViaProxy] is `false` every write
/// throws [EscrowWriteUnavailableException]; when `true` writes succeed and
/// `createEscrow` returns the scripted [createEscrowId] (the real proxy path is
/// owned by EP-02-18).
class FakeEscrowRemoteDataSource implements EscrowRemoteDataSource {
  FakeEscrowRemoteDataSource({
    this.writeViaProxy = false,
    Map<String, EscrowDetailDto> details = const <String, EscrowDetailDto>{},
    this.createEscrowId = 'escrow-created-1',
  }) : _details = Map<String, EscrowDetailDto>.from(details);

  @override
  final bool writeViaProxy;

  final Map<String, EscrowDetailDto> _details;

  /// Id returned by [createEscrow] when the seam is on.
  String createEscrowId;

  ApiException? nextError;
  int getByIdCallCount = 0;
  int getByProjectCallCount = 0;
  int createCallCount = 0;
  int completeMilestoneCallCount = 0;
  int releaseMilestoneCallCount = 0;
  int releaseFinalCallCount = 0;
  int refundCallCount = 0;
  String? lastCreatePayerEntityId;
  String? lastCreatePayeeEntityId;
  String? lastCreateCurrencyCode;
  double? lastCreateTotalAmount;
  String? lastMilestoneId;
  String? lastRefundReason;

  /// Upserts the detail served for [id].
  void setDetail(EscrowDetailDto detail) => _details[detail.escrow.id] = detail;

  @override
  Future<EscrowDetailDto> getById(String id) async {
    getByIdCallCount++;
    if (nextError != null) throw nextError!;
    final EscrowDetailDto? detail = _details[id];
    if (detail == null) {
      throw const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Escrow not found.',
        code: 'PLT004',
      );
    }
    return detail;
  }

  @override
  Future<List<EscrowDto>> getByProject(List<String> escrowIds) async {
    getByProjectCallCount++;
    if (nextError != null) throw nextError!;
    final List<EscrowDto> result = <EscrowDto>[];
    for (final String id in escrowIds) {
      result.add((await getById(id)).escrow);
    }
    return result;
  }

  @override
  Future<String> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) async {
    createCallCount++;
    lastCreatePayerEntityId = payerEntityId;
    lastCreatePayeeEntityId = payeeEntityId;
    lastCreateCurrencyCode = currencyCode;
    lastCreateTotalAmount = totalAmount;
    if (nextError != null) throw nextError!;
    if (!writeViaProxy) throw const EscrowWriteUnavailableException();
    return createEscrowId;
  }

  @override
  Future<void> fundEscrow({required String escrowId}) async {
    if (nextError != null) throw nextError!;
    if (!writeViaProxy) throw const EscrowWriteUnavailableException();
  }

  @override
  Future<void> completeMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    completeMilestoneCallCount++;
    lastMilestoneId = milestoneId;
    if (nextError != null) throw nextError!;
    if (!writeViaProxy) throw const EscrowWriteUnavailableException();
  }

  @override
  Future<void> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    releaseMilestoneCallCount++;
    lastMilestoneId = milestoneId;
    if (nextError != null) throw nextError!;
    if (!writeViaProxy) throw const EscrowWriteUnavailableException();
  }

  @override
  Future<void> releaseFinal({required String escrowId}) async {
    releaseFinalCallCount++;
    if (nextError != null) throw nextError!;
    if (!writeViaProxy) throw const EscrowWriteUnavailableException();
  }

  @override
  Future<void> refundEscrow({
    required String escrowId,
    required String reason,
  }) async {
    refundCallCount++;
    lastRefundReason = reason;
    if (nextError != null) throw nextError!;
    if (!writeViaProxy) throw const EscrowWriteUnavailableException();
  }
}

EscrowDto seedEscrowDto({
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
    EscrowDto(
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

EscrowMilestoneDto seedMilestoneDto({
  String id = 'ms-1',
  String escrowId = 'escrow-1',
  int milestoneNumber = 1,
  String title = 'Design sign-off',
  String? description,
  double amount = 50000,
  String status = 'pending',
  int sortOrder = 1,
}) =>
    EscrowMilestoneDto(
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

EscrowTransactionDto seedTransactionDto({
  String id = 'txn-1',
  String escrowId = 'escrow-1',
  String type = 'release',
  double amount = 25000,
  String direction = 'out',
  String entityId = 'entity-payee',
  String reference = 'RELEASE-1',
}) =>
    EscrowTransactionDto(
      id: id,
      escrowId: escrowId,
      type: type,
      amount: amount,
      direction: direction,
      entityId: entityId,
      reference: reference,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

EscrowDetailDto seedDetailDto({
  EscrowDto? escrow,
  List<EscrowMilestoneDto> milestones = const <EscrowMilestoneDto>[],
  List<EscrowTransactionDto> transactions = const <EscrowTransactionDto>[],
}) =>
    EscrowDetailDto(
      escrow: escrow ?? seedEscrowDto(),
      milestones: milestones,
      transactions: transactions,
    );