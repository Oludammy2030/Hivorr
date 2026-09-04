import 'package:hivorr/data/entities/account_activation_guidance.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';

/// Abstract contract for financial profile data operations (EP-02-13).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface, not a Supabase
/// implementation (ARCHITECTURE.md / EP-01-08 §5.6).
abstract class FinancialRepository {
  /// Fetches the financial profile and attached currency accounts.
  ///
  /// Returns `null` when the entity has no profile yet (pre-creation state).
  Future<FinancialProfile?> getProfile();

  /// Fetches all currency accounts for the current profile.
  ///
  /// Returns an empty list when the profile has no attached accounts.
  Future<List<CurrencyAccount>> getAccounts();

  /// Fetches a single-currency balance.
  ///
  /// Returns `null` for unsupported currencies.
  Future<Balance?> getBalance(String currencyCode);

  /// Fetches the aggregated financial status.
  Future<FinancialStatus> getStatus();

  /// Creates a financial profile with a default currency.
  ///
  /// Validates [defaultCurrency] against the supported set before RPC call.
  /// Throws [ApiException] with `kind == conflict` (`PLT005`) when a profile
  /// already exists.
  Future<FinancialProfile> createProfile({String defaultCurrency = 'NGN'});

  /// Returns activation guidance for a pending account in [currencyCode].
  ///
  /// A display-only seam (EP-02-13 §5.3): validates the currency is supported
  /// (throws `PLT003` otherwise), and — when a payment gateway is configured —
  /// resolves `PaymentGatewayFactory.resolveForCurrency(currencyCode)` to
  /// surface a provider-specific hint ("Connect NGN via Paystack"). This
  /// method **never** writes `financial_currency_accounts` (activation is
  /// `financial_payout_account_bind`, EP-02-16).
  Future<AccountActivationGuidance> requestAccountActivation({
    required String currencyCode,
  });
}
