/// The trade-proof type vocabulary for per-profession verification (EP-02-11).
///
/// This is a pure-Dart client vocabulary of the 5 allowed proof kinds
/// (`certificate / license / workSample / portfolio / other`). Every value maps
/// to an `entity_credentials.kind` accepted by `verification_submit` with
/// `submission_type = 'trade_proof'`
/// (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:358`).
/// Adding a future proof subtype is just a new enum value + label — no schema
/// change is required.
enum TradeProofType {
  /// A certification of skill/competence (e.g. trade certificate).
  certificate,

  /// A professional or occupational license.
  license,

  /// A documented sample of work.
  workSample,

  /// A portfolio of prior work.
  portfolio,

  /// Any other acceptable trade proof.
  other;

  /// The stable `entity_credentials.kind` value for trade proofs.
  static const String tradeKind = 'trade_proof';

  /// The stable `submission_type` value passed to `verification_submit`.
  static const String submissionType = 'trade_proof';

  /// Human-readable display label.
  String get label => switch (this) {
        TradeProofType.certificate => 'Certificate',
        TradeProofType.license => 'License',
        TradeProofType.workSample => 'Work Sample',
        TradeProofType.portfolio => 'Portfolio',
        TradeProofType.other => 'Other',
      };

  /// A short one-line helper shown under the picker choice.
  String get helper => switch (this) {
        TradeProofType.certificate => 'Trade certificate or qualification',
        TradeProofType.license => 'Professional or occupational license',
        TradeProofType.workSample => 'A documented sample of your work',
        TradeProofType.portfolio => 'A portfolio of prior work',
        TradeProofType.other => 'Any other acceptable trade proof',
      };

  /// The `entity_credentials.kind` this proof maps to (always `trade_proof`).
  String get kind => tradeKind;

  /// Resolves a [TradeProofType] from a display title, ignoring case.
  ///
  /// Returns `null` for unrecognized titles so callers can fall back to a
  /// default selection without coupling UI text to the enum.
  static TradeProofType? fromTitle(String title) {
    for (final TradeProofType type in TradeProofType.values) {
      if (type.label.toLowerCase() == title.trim().toLowerCase()) {
        return type;
      }
    }
    return null;
  }
}
