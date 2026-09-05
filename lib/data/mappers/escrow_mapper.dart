import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/escrow_transaction.dart';
import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/models/escrow_transaction_dto.dart';

/// Transformations between the escrow transport DTOs and the pure-Dart domain
/// entities (EP-02-14 §5.2).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying (EP-01-08 §5.3).
abstract final class EscrowMapper {
  /// Maps the aggregate detail DTO into a domain [EscrowDetail].
  static EscrowDetail detailToEntity(EscrowDetailDto dto) => EscrowDetail(
        escrow: escrowToEntity(dto.escrow),
        milestones: dto.milestones.map(milestoneToEntity).toList(growable: false),
        transactions:
            dto.transactions.map(transactionToEntity).toList(growable: false),
      );

  /// Maps an escrow header DTO into a domain [Escrow].
  static Escrow escrowToEntity(EscrowDto dto) => Escrow(
        id: dto.id,
        financialProfileId: dto.financialProfileId,
        payerEntityId: dto.payerEntityId,
        payeeEntityId: dto.payeeEntityId,
        currencyCode: dto.currencyCode,
        totalAmount: dto.totalAmount,
        releasedAmount: dto.releasedAmount,
        refundedAmount: dto.refundedAmount,
        status: dto.status,
        createdAt: dto.createdAt,
        externalReference: dto.externalReference,
        fundedAt: dto.fundedAt,
        releasedAt: dto.releasedAt,
        refundedAt: dto.refundedAt,
      );

  /// Maps a milestone DTO into a domain [EscrowMilestone].
  static EscrowMilestone milestoneToEntity(EscrowMilestoneDto dto) =>
      EscrowMilestone(
        id: dto.id,
        escrowId: dto.escrowId,
        milestoneNumber: dto.milestoneNumber,
        title: dto.title,
        description: dto.description,
        amount: dto.amount,
        status: dto.status,
        sortOrder: dto.sortOrder,
        createdAt: dto.createdAt,
        completedAt: dto.completedAt,
        releasedAt: dto.releasedAt,
      );

  /// Maps a transaction DTO into a domain [EscrowTransaction].
  static EscrowTransaction transactionToEntity(EscrowTransactionDto dto) =>
      EscrowTransaction(
        id: dto.id,
        escrowId: dto.escrowId,
        type: dto.type,
        amount: dto.amount,
        direction: dto.direction,
        entityId: dto.entityId,
        reference: dto.reference,
        createdAt: dto.createdAt,
      );

  /// Converts a domain milestone into a create-payload [EscrowMilestoneInput]
  /// (used when seeding a create request from an existing escrow mirror).
  static EscrowMilestoneInput entityToInput(EscrowMilestone milestone) =>
      EscrowMilestoneInput(
        milestoneNumber: milestone.milestoneNumber,
        title: milestone.title,
        description: milestone.description,
        amount: milestone.amount,
        sortOrder: milestone.sortOrder,
      );
}