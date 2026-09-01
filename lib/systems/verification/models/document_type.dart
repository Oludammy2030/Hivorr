/// The document-type vocabulary for identity verification (EP-02-10).
///
/// This is a pure-Dart client vocabulary. Every value maps to the server
/// `kind = 'identity_document'` and `submission_type = 'identity_document'`
/// (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:130-131`),
/// so adding a future provider-specific type (e.g. BVN for EP-02-12) is just a
/// new enum value + label — no schema change is required.
enum DocumentType {
  /// Nigerian National ID.
  nationalId,

  /// International passport.
  passport,

  /// Driver's license (FRSC).
  driversLicense,

  /// Voter's card (INEC).
  votersCard,

  /// NIN slip.
  ninSlip;

  /// The stable server-side credential kind for all identity documents.
  static const String identityKind = 'identity_document';

  /// The stable server-side submission type for all identity documents.
  static const String submissionType = 'identity_document';

  /// Human-readable display label with Nigeria-specific hint.
  String get label => switch (this) {
        DocumentType.nationalId => 'National ID (NIN)',
        DocumentType.passport => 'Passport',
        DocumentType.driversLicense => "Driver's License (FRSC)",
        DocumentType.votersCard => "Voter's Card (INEC)",
        DocumentType.ninSlip => 'NIN Slip',
      };

  /// A short one-line helper shown under the picker choice.
  String get helper => switch (this) {
        DocumentType.nationalId => 'Nigerian National Identity Card',
        DocumentType.passport => 'International passport bio page',
        DocumentType.driversLicense => 'Nigerian driver\'s license',
        DocumentType.votersCard => 'Permanent voter\'s card',
        DocumentType.ninSlip => 'NIN slip or enrolment acknowledgement',
      };

  /// The credential kind this document maps to (always `identity_document`).
  String get kind => identityKind;

  /// Resolves a [DocumentType] from a display title, ignoring case.
  ///
  /// Returns `null` for unrecognized titles so callers can fall back to a
  /// default selection without coupling UI text to the enum.
  static DocumentType? fromTitle(String title) {
    for (final DocumentType type in DocumentType.values) {
      if (type.label.toLowerCase() == title.trim().toLowerCase()) {
        return type;
      }
    }
    return null;
  }
}
