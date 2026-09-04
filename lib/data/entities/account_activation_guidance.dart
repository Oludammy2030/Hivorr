import 'package:hivorr/data/entities/currency_account.dart';

/// Guidance returned by `requestAccountActivation` (EP-02-13 §5.3).
///
/// Activation itself is server-authoritative via `financial_payout_account_bind`
/// (EP-02-16, AGENT.md Rule 4) — this value only tells the UI *how* a pending
/// account should eventually be activated (e.g. "Connect NGN via Paystack").
/// It is display-only and never writes `financial_currency_accounts`.
class AccountActivationGuidance {
  const AccountActivationGuidance({
    required this.currencyCode,
    required this.message,
    this.providerName,
    this.account,
  });

  /// The currency the guidance applies to (`NGN`, `GHS`, `USD`, `GBP`).
  final String currencyCode;

  /// A user-facing activation hint, e.g. "Connect NGN via Paystack".
  final String message;

  /// The resolved payment provider display name (e.g. "Paystack"), when a
  /// provider is configured for this currency; `null` when the generic hint
  /// is shown.
  final String? providerName;

  /// The existing pending [CurrencyAccount] the guidance refers to, if known.
  final CurrencyAccount? account;
}
