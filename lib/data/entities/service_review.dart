/// Pure Dart domain models for the double-blind review system (EP-03-12).
///
/// Mirrors `service_reviews` + `service_review_aggregates`
/// (`supabase/migrations/20260924090001_service_review_schema.sql`).
/// `isRevealed` is server-authoritative: `false` until both participants
/// submit for the same `contract_id` or the 14-day deadline expires, then
/// flipped atomically with aggregate recomputation + `service_listings`
/// cache in a single transaction.
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports. Blind
/// state is rendered verbatim; the client never evaluates `both_submitted`,
/// never computes averages, and never re-sorts revealed lists
/// (`AGENT.md` Rule 4).
class ServiceReview {
  const ServiceReview({
    required this.id,
    required this.contractId,
    required this.serviceListingId,
    required this.reviewerEntityId,
    required this.revieweeEntityId,
    required this.professionId,
    required this.rating,
    this.comment,
    required this.isRevealed,
    this.revealedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// The review row id.
  final String id;

  /// The reviewed `service_contracts` row.
  final String contractId;

  /// Denormalized `service_listings` link (for `get_for_listing`).
  final String serviceListingId;

  /// The author (`auth.uid()` at submit, never client-supplied).
  final String reviewerEntityId;

  /// The opposite participant (derived server-side as
  /// `CASE WHEN reviewer=client THEN professional ELSE client END`).
  final String revieweeEntityId;

  /// Denormalized `professions` link (aggregate partition).
  final String professionId;

  /// Star rating `1-5` inclusive.
  final int rating;

  /// Optional comment (`null` for star-only, else trimmed `10-2000` chars).
  final String? comment;

  /// Whether this row has been revealed (server-decided).
  final bool isRevealed;

  /// When the reveal flipped (`null` before reveal).
  final DateTime? revealedAt;

  /// Audit timestamps (RPC-managed).
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether this review carries a non-empty comment.
  bool get hasComment => comment != null && comment!.trim().isNotEmpty;
}

/// Aggregate reputation for a professional within a profession (EP-03-03).
///
/// Mirrors `service_review_aggregates` (`PK (professional_entity_id,
/// profession_id)`). Recomputed atomically on reveal; the client renders it
/// verbatim and never recomputes it.
class ReviewAggregate {
  const ReviewAggregate({
    required this.professionalEntityId,
    required this.professionId,
    required this.avgRating,
    required this.reviewCount,
    required this.distribution,
    this.lastRevealedAt,
  });

  /// Empty aggregate (no revealed reviews yet).
  factory ReviewAggregate.empty({
    required String professionalEntityId,
    required String professionId,
  }) => ReviewAggregate(
    professionalEntityId: professionalEntityId,
    professionId: professionId,
    avgRating: 0,
    reviewCount: 0,
    distribution: const <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  );

  /// The reviewed professional (`entities.id`).
  final String professionalEntityId;

  /// The profession partition (`professions.id`).
  final String professionId;

  /// Mean over revealed ratings `0-5` (`0` when empty).
  final double avgRating;

  /// Count of revealed ratings.
  final int reviewCount;

  /// Histogram `{1: count, …, 5: count}`.
  final Map<int, int> distribution;

  /// Latest reveal timestamp contributing to this aggregate.
  final DateTime? lastRevealedAt;

  /// Whether any revealed review exists.
  bool get isEmpty => reviewCount <= 0;

  /// Whether any revealed review exists.
  bool get isNotEmpty => reviewCount > 0;

  /// Share of [stars] (`1-5`) in `0-1`, `0` when empty (display hint only).
  double shareFor(int stars) {
    if (reviewCount <= 0) return 0;
    return (distribution[stars] ?? 0) / reviewCount;
  }
}

/// Viewer-scoped review status for one contract (EP-03-12).
///
/// Mirrors `service_review_get_mine` (`you_have_submitted` + `your_review`
/// even when unrevealed + `revealed_reviews[]` only `is_revealed=true`).
/// Carries no counterparty-submitted boolean by design (no timing oracle).
class MyReviewStatus {
  const MyReviewStatus({
    required this.contractId,
    required this.youHaveSubmitted,
    this.yourReview,
    this.revealedReviews = const <ServiceReview>[],
    required this.reviewCount,
  });

  /// The `service_contracts.id` this status describes.
  final String contractId;

  /// Whether the viewer has submitted (only leaked boolean).
  final bool youHaveSubmitted;

  /// The viewer's own row (visible even when `is_revealed=false`).
  final ServiceReview? yourReview;

  /// Revealed rows only (`is_revealed=true`), in server order.
  final List<ServiceReview> revealedReviews;

  /// Count of revealed rows for this contract.
  final int reviewCount;

  /// Whether both reviews are revealed (display hint; server decides).
  bool get isRevealed =>
      revealedReviews.isNotEmpty &&
      revealedReviews.every((ServiceReview r) => r.isRevealed);
}

/// Paginated revealed reviews for a listing (EP-03-12).
///
/// Mirrors `service_review_get_for_listing` (keyset
/// `(revealed_at DESC, id DESC)` via
/// `service_reviews_listing_revealed_idx`). Items are assigned verbatim
/// from the RPC — never re-sorted client-side.
class ListingReviewsPage {
  const ListingReviewsPage({
    required this.reviews,
    this.aggregate,
    required this.hasMore,
    this.nextCursor,
  });

  /// Revealed reviews in RPC order.
  final List<ServiceReview> reviews;

  /// Aggregate header for the listing owner + profession (may be `null`
  /// when no revealed review exists yet).
  final ReviewAggregate? aggregate;

  /// Whether another page exists.
  final bool hasMore;

  /// Keyset cursor for the next page (`null` when [hasMore] false).
  final String? nextCursor;

  bool get isEmpty => reviews.isEmpty;
  bool get isNotEmpty => reviews.isNotEmpty;
}
