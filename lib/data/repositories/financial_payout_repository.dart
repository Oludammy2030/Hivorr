import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';

/// Abstract contract for payout-account data operations (EP-02-16).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface, not a Supabase
/// implementation (ARCHITECTURE.md / EP-01-08 §5.6).
abstract class FinancialPayoutRepository {
  /// Binds a payout account for the authenticated entity via
  /// `financial_payout_account_bind`.
  ///
  /// Validates against the supported-currency and account-number format gates
  /// before the RPC (mirroring the server's own checks), persists the
  /// successfully bound account into the local display mirror, and returns it.
  /// Throws [ApiException]: `validation` (`PLT003`) for format errors or an
  /// unsupported currency; `conflict` (`PLT005`) when the account number is
  /// already bound for the currency.
  Future<PayoutAccount> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  });

  /// Lists the client-side display mirror of bound payout accounts.
  ///
  /// There is no authenticated read of `financial_payout_accounts` (no SELECT
  /// grant), so this reflects accounts bound during the current session (or
  /// seeded into [PayoutAccountLocalStore]).
  Future<List<PayoutAccount>> listPayoutAccounts();

  /// Withdraws to a verified payout account via `financial_withdraw`.
  ///
  /// Pre-checks mirror the server gates (verified account, amount `> 0`) so
  /// obvious format errors surface without a round trip. Throws [ApiException]
  /// with the server's typed codes: `validation` (`PLT003`) for an unverified
  /// account; `notFound` (`PLT004`); `conflict` (`PLT006`) for insufficient
  /// balance or cashout-limit breach.
  Future<WithdrawalResult> withdraw({
    required String payoutAccountId,
    required double amount,
  });
}