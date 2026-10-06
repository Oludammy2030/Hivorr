import 'package:hivorr/data/models/service_review_dto.dart';

/// Contract for double-blind review transport (EP-03-12 §11).
///
/// Wraps exactly the three client-callable review RPCs granted to
/// `authenticated`/`anon`
/// (`supabase/migrations/20260924090001_service_review_schema.sql`):
/// `service_review_submit`, `service_review_get_mine`,
/// `service_review_get_for_listing`.
///
/// `service_review_reveal_if_ready` is **never** called directly — it is
/// lazy-invoked server-side by `submit`/`get_mine`.
///
/// Review tables (`service_reviews` / `service_review_aggregates`) are
/// **never** written directly — all state changes flow through these RPCs
/// per `AGENT.md` Rule 4.
abstract class ServiceReviewRemoteDataSource {
  /// Submits a `1-5` rating with an optional comment for a reviewable
  /// contract (`service_review_submit`, VOLATILE).
  ///
  /// `reviewer`/`reviewee`/`listing`/`profession` are derived server-side;
  /// the caller supplies only [contractId], [rating], and [comment].
  Future<ReviewSubmitEnvelopeDto> submitReview({
    required String contractId,
    required int rating,
    String? comment,
  });

  /// Reads the viewer's submission status for a contract
  /// (`service_review_get_mine`, STABLE; participant-scoped, `PLT004`
  /// oracle). Returns `you_have_submitted` + `your_review` (even when
  /// unrevealed) + `revealed_reviews[]` (only `is_revealed=true`).
  Future<MyReviewStatusEnvelopeDto> getMyStatus(String contractId);

  /// Lists revealed reviews for a `published` listing with keyset pagination
  /// (`service_review_get_for_listing`, STABLE; `anon`-capable for public
  /// stars). Returns only `is_revealed=true` rows plus the aggregate header.
  Future<ListingReviewsEnvelopeDto> getForListing({
    required String listingId,
    int limit = 20,
    String? cursor,
  });
}
