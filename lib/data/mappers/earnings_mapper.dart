import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/models/earnings_summary_dto.dart';
import 'package:hivorr/data/models/earnings_transaction_dto.dart';

/// Transformations between the earnings transport DTOs and the pure-Dart
/// domain entities (EP-03-16).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying (EP-01-08 §5.3).
/// Server order and server aggregates pass through verbatim; nothing here
/// recomputes settlement.
abstract final class EarningsMapper {
  /// Maps a summary DTO into a domain [EarningsSummary].
  static EarningsSummary summaryToEntity(EarningsSummaryDto dto) =>
      EarningsSummary(
        currencyCode: dto.currencyCode,
        availableBalance: dto.availableBalance,
        heldBalance: dto.heldBalance,
        pendingBalance: dto.pendingBalance,
        lifetimeEarned: dto.lifetimeEarned,
        releaseCount: dto.releaseCount,
        completedContracts: dto.completedContracts,
        totalWithdrawn: dto.totalWithdrawn,
        frozenCount: dto.frozenCount,
        monthly: dto.monthly.map(bucketToEntity).toList(growable: false),
      );

  /// Maps a month-bucket DTO into a domain [EarningsMonthBucket].
  static EarningsMonthBucket bucketToEntity(EarningsMonthBucketDto dto) =>
      EarningsMonthBucket(
        month: dto.month,
        earned: dto.earned,
        releaseCount: dto.releaseCount,
      );

  /// Maps a ledger-row DTO into a domain [EarningsTransaction].
  static EarningsTransaction transactionToEntity(
    EarningsTransactionDto dto,
  ) => EarningsTransaction(
    id: dto.id,
    type: dto.type,
    currencyCode: dto.currencyCode,
    amount: dto.amount,
    direction: dto.direction,
    sourceEntityId: dto.sourceEntityId,
    destinationEntityId: dto.destinationEntityId,
    referenceType: dto.referenceType,
    referenceId: dto.referenceId,
    description: dto.description,
    createdAt: dto.createdAt,
    contractId: dto.contractId,
    contractStatus: dto.contractStatus,
    escrowStatus: dto.escrowStatus,
  );

  /// Maps a history-page DTO into a domain [EarningsTransactionPage].
  static EarningsTransactionPage pageToEntity(
    EarningsTransactionPageDto dto,
  ) => EarningsTransactionPage(
    items: dto.items.map(transactionToEntity).toList(growable: false),
    hasMore: dto.hasMore,
    nextCursor: dto.nextCursor,
  );
}
