import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job_quotation.dart';

/// Repository contract for quotations and hires (EP-04-02).
///
/// Pure domain entities in and out — no DTO or Supabase leakage. The hire
/// funnel stays server-authoritative; this contract exposes intent-level
/// operations only.
abstract class HireRepository {
  /// Proposes (or revises) a quotation on own submitted/shortlisted
  /// application.
  Future<JobQuotation> proposeQuotation({
    required String applicationId,
    required double amount,
    String currencyCode = 'NGN',
    int? durationDays,
    String? message,
  });

  /// Withdraws own live quotation.
  Future<JobQuotation> withdrawQuotation(String quotationId);

  /// Accepts a live quotation (job owner).
  Future<JobQuotation> acceptQuotation(String quotationId);

  /// Hires a shortlisted application (job owner). Returns the hire and the
  /// linked contract id.
  Future<HireAcceptResult> acceptHire(
    String applicationId, {
    String? quotationId,
  });

  /// Fetches a hire with job/application/quotation/contract payloads.
  Future<HireDetail> getHire(String hireId);

  /// Participant-scoped hire list with optional role/status filter.
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  });

  /// Cancels a pending hire, reopening the job (either party).
  Future<Hire> cancelHire(String hireId, {String? reason});

  /// Completes a hire on a completed/closed contract (hiring client).
  Future<Hire> completeHire(String hireId);
}

/// The result of `hire_accept`: the hire bridge plus the linked contract.
class HireAcceptResult {
  const HireAcceptResult({required this.hire, required this.contractId});

  /// The created hire.
  final Hire hire;

  /// The linked `service_contracts` row (status offered).
  final String contractId;
}

/// A `hire_get` result with the joined payloads.
class HireDetail {
  const HireDetail({
    required this.hire,
    required this.effectiveStatus,
    required this.jobId,
    required this.jobTitle,
    required this.applicationId,
    this.quotation,
    this.contractId,
    this.contractStatus,
  });

  /// The hire.
  final Hire hire;

  /// Contract-derived live status.
  final String effectiveStatus;

  /// The awarded job id.
  final String jobId;

  /// The awarded job title.
  final String jobTitle;

  /// The winning application id.
  final String applicationId;

  /// The chosen quotation, when the hire used one.
  final JobQuotation? quotation;

  /// The linked contract id, when set.
  final String? contractId;

  /// The linked contract status, when present.
  final String? contractStatus;
}

/// A keyset page of hires.
class HirePage {
  const HirePage({required this.hires, required this.hasMore, this.nextCursor});

  /// The page items.
  final List<Hire> hires;

  /// Whether further pages exist.
  final bool hasMore;

  /// Cursor for the next page, when [hasMore].
  final String? nextCursor;
}
