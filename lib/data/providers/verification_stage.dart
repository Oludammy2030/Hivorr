/// The derived lifecycle stage of an entity's identity verification (EP-02-10).
///
/// Computed from the `verification_status_get` aggregate which, per the
/// server contract (§§ `supabase/migrations/20260829090003...sql:598-681`),
/// carries only `kyc`, `identity_verified`, and submission counts — never the
/// per-submission review outcome. The `actionRequired` state therefore derives
/// from `!identity_verified && total_submissions > 0 && pending_submissions == 0`
/// (a submitted document that is no longer pending and was not approved).
enum VerificationStage {
  /// No aggregate has been loaded yet.
  idle,

  /// No submission exists yet — verification has not been started.
  pending,

  /// A submission exists and is under active review.
  inReview,

  /// A submission was decided but not approved (rejected / requires
  /// resubmission) — the user should review and resubmit.
  actionRequired,

  /// Identity verified (KYC active and tier >= tier_1).
  approved,
}