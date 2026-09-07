import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/models/payout_bind_dto.dart';
import 'package:hivorr/data/models/withdrawal_dto.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';

/// Transformations between payout transport DTOs and the pure-Dart domain
/// entities (EP-02-16).
///
/// The bind RPC only returns `{payout_account_id, currency_code, status}`;
/// the account profile (bank/account/name) is supplemented from the local
/// bind form values by the repository — the server remains the write
/// authority. No I/O and no business logic (EP-01-08 §5.3).
abstract final class FinancialPayoutMapper {
  /// Maps a withdrawal DTO into a domain [WithdrawalResult].
  static WithdrawalResult withdrawalToEntity(WithdrawalDto dto) =>
      WithdrawalResult(
        payoutId: dto.payoutId,
        amount: dto.amount,
        fee: dto.fee,
        netAmount: dto.netAmount,
        cashoutRemaining: dto.cashoutRemaining,
      );

  /// Builds a [PayoutAccount] from the bind RPC result plus the local form
  /// values that the server validated and persisted.
  static PayoutAccount boundAccountFromBind({
    required PayoutBindDto bind,
    required String bankName,
    required String accountNumber,
    required String accountName,
    DateTime? createdAt,
  }) =>
      PayoutAccount(
        id: bind.payoutAccountId,
        currencyCode: bind.currencyCode,
        bankName: bankName.trim(),
        accountNumber: accountNumber.trim(),
        accountName: accountName.trim(),
        status: PayoutAccountStatus.fromPersisted(bind.status),
        createdAt: createdAt,
      );
}