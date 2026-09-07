import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/models/deposit_dto.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';

/// Transformations between deposit transport DTOs and the pure-Dart domain
/// entities (EP-02-16).
///
/// No I/O and no business logic — only null-safe field copying (EP-01-08 §5.3).
abstract final class FinancialDepositMapper {
  /// Maps a deposit DTO into a domain [Deposit].
  static Deposit toEntity(DepositDto dto) => Deposit(
        id: dto.id,
        currencyCode: dto.currencyCode,
        amount: dto.amount,
        nameMatchStatus: DepositNameMatchStatus.fromPersisted(
          dto.nameMatchStatus,
        ),
        payerName: dto.payerName,
        nameMatchScore: dto.nameMatchScore,
        externalReference: dto.externalReference,
        status: dto.status,
        creditedAt: dto.creditedAt,
        createdAt: dto.createdAt,
      );
}