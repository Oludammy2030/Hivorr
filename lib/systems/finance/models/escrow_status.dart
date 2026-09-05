/// Visual tone buckets used by the escrow/milestone status badges.
///
/// Widgets map each tone to a `Theme.of(context).colorScheme` container color;
/// no hardcoded hex (EP-02-14 §10 / VISUAL-IDENTITY.md).
enum EscrowStatusTone {
  /// Awaiting attention (created).
  warning,

  /// Informational active state (funded, partially released).
  info,

  /// Positive/terminal success (released, milestone released).
  success,

  /// Brand highlight (milestone completed).
  primary,

  /// Neutral/inactive (refunded, cancelled, milestone pending).
  neutral,

  /// Dangerous/frozen (disputed).
  danger,
}

/// A single escrow lifecycle status entry (EP-02-14 §5.4).
///
/// Data-driven to exactly match the frozen `financial_escrow.status` check
/// constraint `('created','funded','partially_released','released','refunded',
/// 'cancelled','disputed')`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:205-207`).
class EscrowStatus {
  const EscrowStatus({
    required this.code,
    required this.label,
    required this.tone,
  });

  /// The server status code.
  final String code;

  /// User-facing label.
  final String label;

  /// Display tone.
  final EscrowStatusTone tone;

  /// Looks up the status vocabulary entry for [code].
  ///
  /// Returns `null` for unknown codes so callers can fall back gracefully.
  static EscrowStatus? forCode(String code) {
    for (final EscrowStatus status in escrowStatuses) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// The 7-state escrow vocabulary (EP-02-14 §5.4).
const List<EscrowStatus> escrowStatuses = <EscrowStatus>[
  EscrowStatus(code: 'created', label: 'Awaiting funding', tone: EscrowStatusTone.warning),
  EscrowStatus(code: 'funded', label: 'Funded & held', tone: EscrowStatusTone.primary),
  EscrowStatus(code: 'partially_released', label: 'Milestones releasing', tone: EscrowStatusTone.primary),
  EscrowStatus(code: 'released', label: 'Released to provider', tone: EscrowStatusTone.success),
  EscrowStatus(code: 'refunded', label: 'Refunded to payer', tone: EscrowStatusTone.neutral),
  EscrowStatus(code: 'cancelled', label: 'Cancelled', tone: EscrowStatusTone.neutral),
  EscrowStatus(code: 'disputed', label: 'In dispute — frozen', tone: EscrowStatusTone.danger),
];

/// A single milestone lifecycle status entry (EP-02-14 §5.4).
///
/// Matches the frozen `financial_escrow_milestones.status` check constraint
/// `('pending','completed','released')`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:240-241`).
class MilestoneStatus {
  const MilestoneStatus({
    required this.code,
    required this.label,
    required this.tone,
  });

  /// The server status code.
  final String code;

  /// User-facing label.
  final String label;

  /// Display tone.
  final EscrowStatusTone tone;

  /// Looks up the milestone vocabulary entry for [code].
  ///
  /// Returns `null` for unknown codes so callers can fall back gracefully.
  static MilestoneStatus? forCode(String code) {
    for (final MilestoneStatus status in milestoneStatuses) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// The 3-state milestone vocabulary (EP-02-14 §5.4).
const List<MilestoneStatus> milestoneStatuses = <MilestoneStatus>[
  MilestoneStatus(code: 'pending', label: 'Pending', tone: EscrowStatusTone.neutral),
  MilestoneStatus(code: 'completed', label: 'Completed — awaiting release', tone: EscrowStatusTone.primary),
  MilestoneStatus(code: 'released', label: 'Released', tone: EscrowStatusTone.success),
];