import 'package:hivorr/data/models/hire_dto.dart';
import 'package:hivorr/data/models/hire_envelopes_dto.dart';
import 'package:hivorr/data/models/job_quotation_dto.dart';

/// Contract for quotations/hires transport (EP-04-02).
///
/// Wraps exactly the **eight client-callable** RPCs granted to `authenticated`
/// (`supabase/migrations/20260928090002_quotations_hires_schema.sql:1003-1010`):
/// `quotation_propose/withdraw/accept` and
/// `hire_accept/get/list_mine/cancel/complete`.
abstract class HiresRemoteDataSource {
  /// Proposes (or revises) a quotation (`quotation_propose`, VOLATILE).
  Future<JobQuotationDto> proposeQuotation({
    required String applicationId,
    required double amount,
    String currencyCode = 'NGN',
    int? durationDays,
    String? message,
  });

  /// Withdraws a live quotation (`quotation_withdraw`, VOLATILE).
  Future<JobQuotationDto> withdrawQuotation(String quotationId);

  /// Accepts a live quotation (owner, `quotation_accept`, VOLATILE).
  Future<JobQuotationDto> acceptQuotation(String quotationId);

  /// Hires a shortlisted application (owner, `hire_accept`, VOLATILE).
  Future<HireAcceptEnvelopeDto> acceptHire(
    String applicationId, {
    String? quotationId,
  });

  /// Fetches a hire with job/application/quotation/contract payloads
  /// (`hire_get`, STABLE).
  Future<HireDetailEnvelopeDto> getHire(String hireId);

  /// Participant-scoped hire list (`hire_list_mine`, STABLE).
  Future<HireListEnvelopeDto> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  });

  /// Cancels a pending hire, reopening the job (`hire_cancel`, VOLATILE).
  ///
  /// Returns the updated hire row (use [getHire] for the full payload).
  Future<HireDto> cancelHire(String hireId, {String? reason});

  /// Completes a hire on a completed/closed contract
  /// (`hire_complete`, VOLATILE).
  ///
  /// Returns the updated hire row (use [getHire] for the full payload).
  Future<HireDto> completeHire(String hireId);
}
