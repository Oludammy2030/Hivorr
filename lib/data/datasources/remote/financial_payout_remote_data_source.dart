import 'package:hivorr/data/models/payout_bind_dto.dart';
import 'package:hivorr/data/models/withdrawal_dto.dart';

/// Abstract contract for the remote (Supabase) side of payout accounts and
/// withdrawals (EP-02-16).
///
/// Implementations access the backend only through the EP-01-07
/// [BaseApiService] channel and the authenticated RPCs —
/// `financial_payout_account_bind` / `financial_withdraw`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1150-1199`
/// and `:1241-1330`). Never writes tables directly (server-authoritative,
/// AGENT.md Rule 4). There is intentionally **no** list method: the
/// authenticated role has no SELECT grant on `financial_payout_accounts`, so
/// bound accounts are mirrored client-side by the repository store.
abstract class FinancialPayoutRemoteDataSource {
  /// Binds a payout account via `financial_payout_account_bind`.
  ///
  /// Throws [ApiException] with `kind == conflict` (`PLT005`) when the
  /// (entity, currency, account-number) triple already exists, and
  /// `kind == validation` (`PLT003`) for an unsupported currency or a
  /// blank bank/account/name.
  Future<PayoutBindDto> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  });

  /// Withdraws [amount] to the verified payout account via `financial_withdraw`.
  ///
  /// Throws [ApiException]: `validation` (`PLT003`) when the account is not
  /// verified or amount `<= 0`; `notFound` (`PLT004`) for unknown account or
  /// missing profile; `conflict` (`PLT006`) for insufficient balance or a
  /// cashout-limit breach.
  Future<WithdrawalDto> withdraw({
    required String payoutAccountId,
    required double amount,
  });
}