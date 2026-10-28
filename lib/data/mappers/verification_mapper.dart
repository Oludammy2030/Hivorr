import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/trade_verification_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Transformations between the transport DTOs and the pure-Dart domain
/// entities (EP-02-10 §5.2, §7).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying and enum
/// mapping (EP-01-08 §5.3).
abstract final class VerificationMapper {
  /// Server cap on `decision_notes` length
  /// (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:141`).
  static const int maxDecisionNotesLength = 5000;

  /// Maps a submission DTO into a domain [VerificationSubmission].
  ///
  /// [documentType] is supplied by the caller because the RPC row only carries
  /// the coarse `submission_type = identity_document`; the specific 5-value
  /// document type is known at submit time.
  static VerificationSubmission submissionToEntity(
    VerificationSubmissionDto dto, {
    required DocumentType documentType,
  }) => VerificationSubmission(
    id: dto.id,
    entityId: dto.entityId,
    credentialId: dto.credentialId,
    documentType: documentType,
    status: VerificationStatusKind.fromServer(dto.status),
    submittedAt: dto.submittedAt,
    reviewedAt: dto.reviewedAt,
    decisionNotes: _truncateNotes(dto.decisionNotes),
  );

  /// Maps a KYC level DTO into a domain [KycLevel].
  static KycLevel kycToEntity(KycLevelDto dto) => KycLevel(
    tierCode: dto.tierCode,
    status: dto.status,
    limits: limitsToEntity(dto.limits),
  );

  /// Maps a KYC limits DTO into a domain [KycLimits].
  static KycLimits limitsToEntity(KycLimitsDto dto) => KycLimits(
    daily: dto.daily,
    weekly: dto.weekly,
    monthly: dto.monthly,
    cashout: dto.cashout,
  );

  /// Maps a latest-submission DTO into a domain [VerificationSubmissionSummary].
  static VerificationSubmissionSummary submissionSummaryToEntity(
    VerificationSubmissionSummaryDto dto,
  ) => VerificationSubmissionSummary(
    submissionType: dto.submissionType,
    professionId: dto.professionId,
    businessId: dto.businessId,
    businessTradingName: dto.businessTradingName,
    status: VerificationStatusKind.fromServer(dto.status),
    submittedAt: dto.submittedAt,
    reviewedAt: dto.reviewedAt,
    decisionNotes: _truncateNotes(dto.decisionNotes),
    credentialTitle: dto.credentialTitle,
  );

  /// Maps a business lane DTO into a domain [BusinessVerificationEntry].
  static BusinessVerificationEntry businessToEntity(
    BusinessVerificationEntryDto dto,
  ) => BusinessVerificationEntry(
    businessId: dto.businessId,
    tradingName: dto.tradingName,
    registeredLegalName: dto.registeredLegalName,
    cacNumber: dto.cacNumber,
    verificationStatus: dto.verificationStatus,
    role: dto.role,
    isAuthorized: dto.isAuthorized,
    latestSubmission: dto.latestSubmission == null
        ? null
        : submissionSummaryToEntity(dto.latestSubmission!),
  );

  /// Maps a trade-verification DTO into a domain [TradeVerification].
  static TradeVerification tradeToEntity(TradeVerificationDto dto) =>
      TradeVerification(
        professionId: dto.professionId,
        status: dto.status,
        professionalDisplayName: dto.professionalDisplayName,
      );

  /// Maps the trade slice of the status aggregate into a domain
  /// [TradeVerificationStatus].
  ///
  /// `rejected` is left as-is in [TradeVerification.statusKind]'s client-side
  /// derivation; here we copy the per-profession entries + identity flag.
  static TradeVerificationStatus tradeStatusToEntity(
    TradeVerificationStatusDto dto,
  ) => TradeVerificationStatus(
    tradeVerifications: dto.tradeVerifications
        .map(tradeToEntity)
        .toList(growable: false),
    identityVerified: dto.identityVerified,
    latestSubmissions: dto.latestSubmissions
        .map(submissionSummaryToEntity)
        .toList(growable: false),
  );

  /// Maps the full status aggregate DTO into a domain [VerificationStatus].
  static VerificationStatus statusToEntity(VerificationStatusDto dto) =>
      VerificationStatus(
        entityId: dto.entityId,
        kycLevel: kycToEntity(dto.kyc),
        identityVerified: dto.identityVerified,
        tradeVerifications: dto.tradeVerifications
            .map(tradeToEntity)
            .toList(growable: false),
        latestSubmissions: dto.latestSubmissions
            .map(submissionSummaryToEntity)
            .toList(growable: false),
        businesses: dto.businesses
            .map(businessToEntity)
            .toList(growable: false),
        eligibility: Map<String, dynamic>.from(dto.eligibility),
        hasLatestSubmissionData: dto.hasLatestSubmissionData,
        pendingSubmissions: dto.pendingSubmissions,
        totalSubmissions: dto.totalSubmissions,
      );

  static String? _truncateNotes(String? notes) {
    if (notes == null) return null;
    if (notes.length <= maxDecisionNotesLength) return notes;
    return notes.substring(0, maxDecisionNotesLength);
  }

  /// Resolves a server tier code to a [KycTier] (EP-02-12).
  ///
  /// Falls back to [KycTier.tier0] for unknown/absent codes.
  static KycTier kycTierFromCode(String code) => KycTier.fromCode(code);

  /// The display label for a server tier code (EP-02-12).
  static String kycTierLabel(String code) =>
      KycTier.fromCode(code).displayLabel;
}
