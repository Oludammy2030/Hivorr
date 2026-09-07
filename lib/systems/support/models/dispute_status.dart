/// Display tone buckets used by [DisputeStatusBadge].
///
/// Widgets map each tone to a `Theme.of(context).colorScheme` /
/// `AppThemeExtension` container color; no hardcoded hex (EP-02-17 §10).
enum DisputeStatusTone {
  /// Awaiting attention (open).
  warning,

  /// Informational active state (under_review).
  info,

  /// Positive/terminal success (resolved).
  success,

  /// Neutral/inactive (closed, withdrawn).
  neutral,
}

/// A single dispute status entry (EP-02-17 §5.5).
///
/// Data-driven to exactly match the frozen `dispute_cases.status` check
/// constraint `('open','under_review','resolved','closed','withdrawn')`
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:66-68`).
class DisputeStatus {
  const DisputeStatus({
    required this.code,
    required this.label,
    required this.tone,
  });

  /// The server status code.
  final String code;

  /// User-facing label.
  final String label;

  /// Display tone.
  final DisputeStatusTone tone;

  /// Looks up the status vocabulary entry for [code].
  ///
  /// Returns `null` for unknown codes so callers can fall back gracefully.
  static DisputeStatus? forCode(String code) {
    for (final DisputeStatus status in disputeStatuses) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// The 5-state dispute vocabulary (EP-02-17 §5.5, CHECK `66-68`).
const List<DisputeStatus> disputeStatuses = <DisputeStatus>[
  DisputeStatus(code: 'open', label: 'Open', tone: DisputeStatusTone.warning),
  DisputeStatus(
    code: 'under_review',
    label: 'Under review',
    tone: DisputeStatusTone.info,
  ),
  DisputeStatus(
    code: 'resolved',
    label: 'Resolved',
    tone: DisputeStatusTone.success,
  ),
  DisputeStatus(code: 'closed', label: 'Closed', tone: DisputeStatusTone.neutral),
  DisputeStatus(
    code: 'withdrawn',
    label: 'Withdrawn',
    tone: DisputeStatusTone.neutral,
  ),
];

/// A single dispute type entry (EP-02-17 §5.5).
///
/// Matches the frozen `dispute_cases.dispute_type` check constraint
/// `('service_quality','non_delivery','milestone_disagreement','fraud',
/// 'other')` (`20260829120005:62-65`).
class DisputeType {
  const DisputeType({required this.code, required this.label});

  /// The server dispute-type code.
  final String code;

  /// User-facing label.
  final String label;

  /// Looks up the type vocabulary entry for [code].
  static DisputeType? forCode(String code) {
    for (final DisputeType type in disputeTypes) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// The 5-type dispute vocabulary (EP-02-17 §5.5, CHECK `62-65`).
const List<DisputeType> disputeTypes = <DisputeType>[
  DisputeType(code: 'service_quality', label: 'Service quality'),
  DisputeType(code: 'non_delivery', label: 'Non-delivery'),
  DisputeType(
    code: 'milestone_disagreement',
    label: 'Milestone disagreement',
  ),
  DisputeType(code: 'fraud', label: 'Fraud'),
  DisputeType(code: 'other', label: 'Other'),
];

/// A single desired-outcome entry (EP-02-17 §5.5).
///
/// Matches the frozen nullable `dispute_cases.desired_outcome` check
/// constraint `('release_to_payee','refund_to_payer','split','other')`
/// (`20260829120005:71-73`).
class DesiredOutcome {
  const DesiredOutcome({required this.code, required this.label});

  /// The server desired-outcome code.
  final String code;

  /// User-facing label.
  final String label;
}

/// The 4+`other` desired-outcome vocabulary (EP-02-17 §5.5, CHECK `71-73`).
const List<DesiredOutcome> desiredOutcomes = <DesiredOutcome>[
  DesiredOutcome(code: 'release_to_payee', label: 'Release to provider'),
  DesiredOutcome(code: 'refund_to_payer', label: 'Refund to me'),
  DesiredOutcome(code: 'split', label: 'Split the amount'),
  DesiredOutcome(code: 'other', label: 'Other'),
];

/// A single priority entry (EP-02-17 §5.5).
///
/// Matches the frozen `dispute_cases.priority` check constraint
/// `('low','medium','high','critical')` (`20260829120005:74-75`).
class DisputePriority {
  const DisputePriority({
    required this.code,
    required this.label,
  });

  /// The server priority code.
  final String code;

  /// User-facing label.
  final String label;
}

/// The 4-state priority vocabulary (EP-02-17 §5.5, CHECK `74-75`).
const List<DisputePriority> disputePriorities = <DisputePriority>[
  DisputePriority(code: 'low', label: 'Low'),
  DisputePriority(code: 'medium', label: 'Medium'),
  DisputePriority(code: 'high', label: 'High'),
  DisputePriority(code: 'critical', label: 'Critical'),
];

/// A single evidence-type entry (EP-02-17 §5.5).
///
/// Matches the frozen `dispute_evidence.evidence_type` check constraint
/// `('document','screenshot','description','photo')` (`20260829120005:112-113`).
class EvidenceType {
  const EvidenceType({required this.code, required this.label});

  /// The server evidence-type code.
  final String code;

  /// User-facing label.
  final String label;
}

/// The 4-type evidence vocabulary (EP-02-17 §5.5, CHECK `112-113`).
const List<EvidenceType> evidenceTypes = <EvidenceType>[
  EvidenceType(code: 'document', label: 'Document'),
  EvidenceType(code: 'screenshot', label: 'Screenshot'),
  EvidenceType(code: 'description', label: 'Description'),
  EvidenceType(code: 'photo', label: 'Photo'),
];

/// A single resolution-type entry (EP-02-17 §5.5).
///
/// Matches the frozen `dispute_resolutions.resolution_type` check constraint
/// `('release_to_payee','refund_to_payer','split','dismissed')`
/// (`20260829120005:141-143`).
class ResolutionType {
  const ResolutionType({
    required this.code,
    required this.label,
  });

  /// The server resolution-type code.
  final String code;

  /// User-facing outcome label.
  final String label;

  /// Looks up the resolution-type vocabulary entry for [code].
  static ResolutionType? forCode(String code) {
    for (final ResolutionType type in resolutionTypes) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// The 4-type resolution vocabulary (EP-02-17 §5.5, CHECK `141-143`).
const List<ResolutionType> resolutionTypes = <ResolutionType>[
  ResolutionType(code: 'release_to_payee', label: 'Release to provider'),
  ResolutionType(code: 'refund_to_payer', label: 'Refund to payer'),
  ResolutionType(code: 'split', label: 'Split between parties'),
  ResolutionType(code: 'dismissed', label: 'Dismissed'),
];