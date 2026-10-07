import 'package:hivorr/data/entities/service_review.dart';

/// Abstract contract for double-blind review data operations (EP-03-12 §7.1).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface rather than a Supabase
/// implementation (ARCHITECTURE.md / EP-01-08 §5.6).
///
/// All review writes flow through the client-callable RPCs
/// (`service_review_submit`); reads flow through `service_review_get_mine`
/// and `service_review_get_for_listing`. This repository **never** writes
/// `service_reviews` or `service_review_aggregates` tables directly and
/// **never** calls `service_review_reveal_if_ready` (`AGENT.md` Rule 4).
abstract class ServiceReviewRepository {
  /// Submits a `1-5` rating with an optional comment for a reviewable
  /// contract, then returns the created row.
  ///
  /// Pre-validates `rating 1-5` and `comment` null-or-`10-2000` before the
  /// RPC (fail-fast `PLT003`). The server derives reviewer/reviewee/listing/
  /// profession and enforces the single-review (`PLT005`) and reviewable-state
  /// (`active/completed/closed`, `PLT005`) gates.
  Future<ServiceReview> submitReview({
    required String contractId,
    required int rating,
    String? comment,
  });

  /// Reads the viewer's submission status for [contractId].
  ///
  /// Returns `you_have_submitted` + own row (even unrevealed) + revealed rows
  /// only. Never leaks counterparty unrevealed state.
  Future<MyReviewStatus> getMyStatus(String contractId);

  /// Lists revealed reviews for [listingId] with keyset pagination
  /// (`(revealed_at DESC, id DESC)`), verbatim server order.
  ///
  /// [professionalEntityId] and [professionId] key the aggregate header
  /// synthesized from the envelope when `review_count > 0`.
  Future<ListingReviewsPage> getForListing({
    required String listingId,
    required String professionalEntityId,
    required String professionId,
    int limit = 20,
    String? cursor,
  });
}
