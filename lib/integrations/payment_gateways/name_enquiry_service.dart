import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';

/// The account-name enquiry contract used for payout binding and deposit
/// verification (AGENT.md Rule 3 / EP-02-16).
///
/// This is a separate, segregated abstraction (ISP) so that EP-02-16 can
/// inject a different NIBSS implementation (e.g. a paying NIBSS-backed
/// provider) without swapping the full [PaymentGateway].
///
/// Implementations must validate the account number (NUBAN `^\d{10}$`)
/// before any network call and normalize provider envelopes into a single
/// `ApiException` error contract.
abstract class NameEnquiryService {
  /// Resolves the account holder name for [accountNumber] at [bankCode].
  ///
  /// The returned [NameEnquiryResult.accountName] is for server-side
  /// `legal_name` comparison — it is never persisted by this adapter.
  Future<NameEnquiryResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  });
}
