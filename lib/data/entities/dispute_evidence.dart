/// A single immutable evidence submission on a dispute case (EP-02-17).
///
/// Mirrors `dispute_evidence`
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:106-122`).
/// `evidence_type` matches the frozen CHECK vocabulary
/// (`document|screenshot|description|photo`, CHECK `112-113`), `title` is
/// 1–255 chars (`114-115`), `description` ≤2000 (`116-117`). Rows are
/// immutable server-side — the client renders, never edits or deletes
/// (EP-02-17 §7.2).
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class DisputeEvidence {
  const DisputeEvidence({
    required this.id,
    required this.caseId,
    required this.submittedBy,
    required this.evidenceType,
    required this.title,
    this.description,
    this.fileUrl,
    this.fileMetadata = const <String, dynamic>{},
    required this.createdAt,
  });

  /// The evidence row id.
  final String id;

  /// The dispute case this evidence belongs to.
  final String caseId;

  /// The entity that submitted the evidence.
  final String submittedBy;

  /// `document | screenshot | description | photo` (CHECK `112-113`).
  final String evidenceType;

  /// Evidence title, 1–255 chars (CHECK `114-115`).
  final String title;

  /// Optional evidence description, ≤2000 chars (CHECK `116-117`).
  final String? description;

  /// Optional Supabase Storage path in the `credential-documents` bucket.
  final String? fileUrl;

  /// Storage metadata (`mimeType`, `sizeBytes`, `originalName`).
  final Map<String, dynamic> fileMetadata;

  /// When the evidence was submitted.
  final DateTime createdAt;

  /// Whether this evidence carries an attachment (non-`description` types).
  bool get hasAttachment => fileUrl != null && fileUrl!.isNotEmpty;

  /// Whether the evidence was submitted as a written description only.
  bool get isDescriptive => evidenceType == 'description';
}