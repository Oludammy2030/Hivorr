/// Display tone buckets used by job/application/hire status badges.
///
/// Widgets map each tone to a `Theme.of(context).colorScheme` /
/// `AppThemeExtension` container color; no hardcoded hex.
enum HiringStatusTone {
  /// Draft / neutral inactive.
  neutral,

  /// Awaiting attention (open, submitted, proposed, pending).
  warning,

  /// Informational active state (paused, shortlisted, active).
  info,

  /// Positive/terminal success (awarded, accepted, completed).
  success,

  /// Negative/terminal (cancelled, rejected, withdrawn, disputed).
  critical,
}

/// A single hiring status entry (EP-04-01/04-02).
///
/// Data-driven to exactly match the frozen CHECK constraints:
/// `jobs.status`, `job_applications.status`, `job_quotations.status`,
/// `hires.status`.
class HiringStatus {
  const HiringStatus({
    required this.code,
    required this.label,
    required this.tone,
  });

  /// The server status code.
  final String code;

  /// User-facing label.
  final String label;

  /// Display tone.
  final HiringStatusTone tone;

  /// Looks up the vocabulary entry for [code].
  ///
  /// Returns `null` for unknown codes so callers can fall back gracefully.
  static HiringStatus? forCode(String code) {
    for (final HiringStatus status in hiringStatuses) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// The combined hiring vocabulary (EP-04-01 CHECK, EP-04-02 CHECK).
const List<HiringStatus> hiringStatuses = <HiringStatus>[
  // Job + effective-hire shared codes.
  HiringStatus(code: 'draft', label: 'Draft', tone: HiringStatusTone.neutral),
  HiringStatus(code: 'open', label: 'Open', tone: HiringStatusTone.warning),
  HiringStatus(code: 'paused', label: 'Paused', tone: HiringStatusTone.info),
  HiringStatus(
    code: 'awarded',
    label: 'Awarded',
    tone: HiringStatusTone.success,
  ),
  HiringStatus(
    code: 'completed',
    label: 'Completed',
    tone: HiringStatusTone.success,
  ),
  HiringStatus(
    code: 'cancelled',
    label: 'Cancelled',
    tone: HiringStatusTone.neutral,
  ),
  // Application codes.
  HiringStatus(
    code: 'submitted',
    label: 'Submitted',
    tone: HiringStatusTone.warning,
  ),
  HiringStatus(
    code: 'withdrawn',
    label: 'Withdrawn',
    tone: HiringStatusTone.neutral,
  ),
  HiringStatus(
    code: 'shortlisted',
    label: 'Shortlisted',
    tone: HiringStatusTone.info,
  ),
  HiringStatus(
    code: 'accepted',
    label: 'Accepted',
    tone: HiringStatusTone.success,
  ),
  HiringStatus(
    code: 'rejected',
    label: 'Rejected',
    tone: HiringStatusTone.neutral,
  ),
  // Quotation codes.
  HiringStatus(
    code: 'proposed',
    label: 'Proposed',
    tone: HiringStatusTone.warning,
  ),
  HiringStatus(
    code: 'superseded',
    label: 'Superseded',
    tone: HiringStatusTone.neutral,
  ),
  // Hire codes.
  HiringStatus(
    code: 'pending',
    label: 'Pending',
    tone: HiringStatusTone.warning,
  ),
  HiringStatus(code: 'active', label: 'Active', tone: HiringStatusTone.info),
  HiringStatus(
    code: 'disputed',
    label: 'Disputed',
    tone: HiringStatusTone.critical,
  ),
];

/// The 6-state job status vocabulary (EP-04-01, CHECK on `jobs.status`).
const List<String> jobStatusCodes = <String>[
  'draft',
  'open',
  'paused',
  'awarded',
  'completed',
  'cancelled',
];

/// The 5-state application vocabulary (EP-04-01, CHECK).
const List<String> applicationStatusCodes = <String>[
  'submitted',
  'withdrawn',
  'shortlisted',
  'accepted',
  'rejected',
];

/// The 4-state quotation vocabulary (EP-04-02, CHECK).
const List<String> quotationStatusCodes = <String>[
  'proposed',
  'accepted',
  'superseded',
  'withdrawn',
];

/// The 5-state hire vocabulary (EP-04-02, CHECK).
const List<String> hireStatusCodes = <String>[
  'pending',
  'active',
  'completed',
  'cancelled',
  'disputed',
];
