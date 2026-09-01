/// Provider-neutral payment gateway domain models.
///
/// Every type in this file is pure Dart and carries no reference to any
/// specific provider (Paystack, Flutterwave, NIBSS). Adapters map provider
/// payloads into these neutral shapes so `lib/systems/finance/` never import
/// provider DTOs (ARCHITECTURE.md:151-152).
///
/// Amounts are always expressed in **minor units** (`minorUnits`) plus a
/// three-letter [Amount.currency]. This prevents the classic 100x unit bug:
/// Paystack quotes kobo (`amount: 500000` == NGN 5,000) while Flutterwave
/// quotes major units (`amount: 5000`). Both adapters normalize into this
/// single representation internally.
library;

/// Supported payment providers.
enum PaymentProvider {
  /// Paystack (NGN-focused, kobo units).
  paystack,

  /// Flutterwave (NGN/GHS multi-currency, major-unit amounts).
  flutterwave,
}

/// Unified lifecycle status of a payment, independent of provider naming.
enum PaymentStatus {
  /// Awaiting confirmation / authorization.
  pending,

  /// Payment captured successfully (Paystack `success`, Flutterwave
  /// `successful`).
  success,

  /// Payment failed or declined.
  failed,

  /// Checkout abandoned by the payer.
  abandoned,

  /// Payment reversed / refunded.
  reversed,
}

/// Unified lifecycle status of a transfer (payout).
enum TransferStatus {
  /// Transfer queued/processing.
  pending,

  /// Transfer completed.
  success,

  /// Transfer failed.
  failed,

  /// Transfer reversed.
  reversed,
}

/// A monetary amount expressed in minor units (kobo/pesewas/cents) for a
/// given [currency].
///
/// Integer arithmetic only — never `double`, avoiding rounding drift
/// (EP-02-09 §5.3, §12).
class Amount {
  const Amount({required this.minorUnits, required this.currency});

  /// The amount in the smallest unit of [currency] (e.g. kobo for NGN).
  final int minorUnits;

  /// Three-letter ISO currency code (e.g. `NGN`, `GHS`, `USD`, `GBP`).
  final String currency;

  /// Whether [minorUnits] is greater than zero.
  bool get isPositive => minorUnits > 0;

  @override
  bool operator ==(Object other) =>
      other is Amount &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Amount($minorUnits $currency)';
}

/// Request to initialize a new payment.
class PaymentInitializationRequest {
  PaymentInitializationRequest({
    required this.amount,
    required this.email,
    required this.reference,
    required this.callbackUrl,
    this.metadata,
    this.currency,
  });

  /// The amount to charge, in minor units.
  final Amount amount;

  /// Payer email (used as the provider customer identifier).
  final String email;

  /// Idempotency key — caller/factory-generated UUID v4, echoed by
  /// [verifyPayment]. Never provider-generated alone (EP-02-09 §5.3).
  final String reference;

  /// Redirect (post-3DS) callback URL.
  final String callbackUrl;

  /// Optional non-sensitive metadata (e.g. `entity_id`, `escrow_id`,
  /// `purpose`). Up to 10 keys with ≤500-char values.
  final Map<String, String>? metadata;

  /// Optional explicit currency override; defaults to [amount.currency].
  final String? currency;
}

/// A successful payment-initialization, returned by
/// `PaymentGateway.initializePayment`.
class PaymentInitializationResult {
  PaymentInitializationResult({
    required this.reference,
    required this.authorizationUrl,
    required this.accessCode,
  });

  /// The echoed idempotency reference.
  final String reference;

  /// Provider-hosted checkout URL (Paystack `authorization_url` /
  /// Flutterwave `link`). The client redirects the payer here; it never
  /// collects card data itself (PCI scope zero).
  final String authorizationUrl;

  /// Provider access code for the session, when available.
  final String accessCode;
}

/// Verification result returned by `PaymentGateway.verifyPayment`.
class PaymentVerificationResult {
  PaymentVerificationResult({
    required this.reference,
    required this.status,
    required this.amount,
    required this.currency,
    this.paidAt,
    this.gatewayFee,
  });

  /// The verified idempotency reference.
  final String reference;

  /// Unified payment status.
  final PaymentStatus status;

  /// Confirmed amount in minor units.
  final Amount amount;

  /// Confirmed currency.
  final String currency;

  /// When the payment was captured, when available.
  final DateTime? paidAt;

  /// Provider gateway fee in minor units, when reported (audit trail input).
  final Amount? gatewayFee;
}

/// Request to create a transfer (payout).
class TransferRequest {
  TransferRequest({
    required this.amount,
    required this.recipientAccountNumber,
    required this.recipientBankCode,
    required this.reference,
    required this.reason,
  });

  /// The payout amount in minor units.
  final Amount amount;

  /// Recipient NUBAN account number — `^\d{10}$`.
  final String recipientAccountNumber;

  /// Recipient 3-digit CBN bank code (e.g. `058` for GTBank).
  final String recipientBankCode;

  /// Idempotency key for the transfer.
  final String reference;

  /// Human-readable transfer reason shown to the recipient.
  final String reason;
}

/// The result of a transfer (payout) request.
class TransferResult {
  TransferResult({
    required this.reference,
    required this.status,
    required this.amount,
  });

  /// The transfer reference.
  final String reference;

  /// Unified transfer status.
  final TransferStatus status;

  /// The amount transferred, in minor units.
  final Amount amount;
}

/// Request to refund a previously completed transaction.
class RefundRequest {
  RefundRequest({
    required this.transactionReference,
    this.amount,
    this.reason,
  });

  /// The provider transaction reference to refund.
  final String transactionReference;

  /// Optional partial-refund amount in minor units; `null` = full refund.
  final Amount? amount;

  /// Optional merchant note attached to the refund.
  final String? reason;
}

/// The result of a refund request.
class RefundResult {
  RefundResult({
    required this.reference,
    required this.status,
    required this.amount,
  });

  /// The refund reference.
  final String reference;

  /// Whether the refund was accepted by the provider.
  final PaymentStatus status;

  /// The refunded amount in minor units.
  final Amount amount;
}

/// The result of a NIBSS account-name enquiry (used by the
/// `NameEnquiryService`).
///
/// `accountName` is returned to the caller only — it is never persisted by
/// the adapter. Downstream `EP-02-16` compares it server-side against
/// `entity_profiles.legal_name` (AGENT.md Rule 3).
class NameEnquiryResult {
  NameEnquiryResult({
    required this.accountNumber,
    required this.accountName,
    required this.bankCode,
  });

  /// The enquired account number (10-digit NUBAN).
  final String accountNumber;

  /// The name registered against the account, as returned by the provider.
  final String accountName;

  /// The bank code the account belongs to.
  final String bankCode;
}

/// A provider-neutral parsed webhook event.
///
/// The webhook `status` is a **notification only** — it must never be trusted
/// for ledger mutations. Downstream must re-fetch truth via
/// `verifyPayment`/`verifyTransfer` before any business action
/// (EP-02-09 §7.3, §12).
class WebhookEvent {
  WebhookEvent({
    required this.provider,
    required this.eventType,
    required this.reference,
    required this.status,
    this.raw,
  });

  /// The originating provider (`paystack` or `flutterwave`).
  final String provider;

  /// Provider event name (e.g. `charge.success`, `transfer.success`,
  /// `transfer.completed`).
  final String eventType;

  /// The reference/tx_ref carried by the event, when parseable.
  final String reference;

  /// Unified payment status derived from the event type.
  final PaymentStatus status;

  /// The raw parsed body, retained for downstream correlation (never logged).
  final Map<String, dynamic>? raw;
}
