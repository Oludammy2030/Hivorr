// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/repositories/service_review_repository.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [ServiceReviewRepository] consumed by
/// [ServiceReviewProvider] and the review screens (EP-03-12 §7.2).
///
/// Exposes the review vocabulary (compile-time const, mirroring the frozen
/// CHECK constraints) plus the fail-fast validators [validateRating]/
/// [validateComment]/[validateContractId]/[validateListingId], and delegates
/// data operations to the repository. Adds PII-safe structured [HivorrLogger]
/// output (contract id suffix, `is_revealed` deltas — never comment bodies)
/// and `reviews.*` [PerformanceTracer] spans.
///
/// This service never decides reveal, never computes averages, and never
/// re-sorts revealed lists — the server is the single authority
/// (`AGENT.md` Rule 4).
class ServiceReviewService {
  ServiceReviewService({
    required ServiceReviewRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  }) : _repository = repository,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor();

  final ServiceReviewRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  // ─── Vocabulary (matches frozen CHECK constraints) ───────────────────

  /// Minimum star rating (`service_reviews_rating_range`).
  static const int minRating = 1;

  /// Maximum star rating (`service_reviews_rating_range`).
  static const int maxRating = 5;

  /// Minimum comment length when a comment is supplied.
  static const int minCommentLength = 10;

  /// Maximum comment length when a comment is supplied.
  static const int maxCommentLength = 2000;

  /// Contract states that accept reviews
  /// (`service_review_submit` reviewable gate).
  static const List<String> reviewableStatuses = <String>[
    'active',
    'completed',
    'closed',
  ];

  /// Default page size for `service_review_get_for_listing`.
  static const int defaultPageLimit = 20;

  /// Maximum page size accepted by `service_review_get_for_listing`.
  static const int maxPageLimit = 100;

  // ─── Fail-fast validators (mirror CHECKs; server stays authoritative) ─

  /// `true` when [rating] is `1-5` inclusive.
  static bool validateRating(int? rating) =>
      rating != null && rating >= minRating && rating <= maxRating;

  /// `true` when [comment] is absent/blank (star-only) or trimmed
  /// `10-2000` chars.
  static bool validateComment(String? comment) {
    if (comment == null || comment.trim().isEmpty) return true;
    final int length = comment.trim().length;
    return length >= minCommentLength && length <= maxCommentLength;
  }

  /// `true` when [contractId] is non-blank.
  static bool validateContractId(String? contractId) =>
      contractId != null && contractId.trim().isNotEmpty;

  /// `true` when [listingId] is non-blank.
  static bool validateListingId(String? listingId) =>
      listingId != null && listingId.trim().isNotEmpty;

  /// View-intent hint: whether [viewerEntityId] may see the review CTA for
  /// [contract] given [status].
  ///
  /// Affordance only — enforcement stays server-side (`PLT005` otherwise).
  /// `true` when the viewer is a participant, the contract is in a
  /// reviewable state, and the viewer has not submitted yet (when [status]
  /// is known).
  static bool canReview({
    required ServiceContract? contract,
    required String viewerEntityId,
    MyReviewStatus? status,
  }) {
    if (contract == null || viewerEntityId.isEmpty) return false;
    final bool isParticipant =
        viewerEntityId == contract.clientEntityId ||
        viewerEntityId == contract.professionalEntityId;
    if (!isParticipant) return false;
    if (!reviewableStatuses.contains(contract.status)) return false;
    if (status != null && status.youHaveSubmitted) return false;
    return true;
  }

  // ─── Data operations (delegate to repository, traced + logged) ────────

  /// Submits a review for [contractId] and returns the created row.
  Future<ServiceReview> submitReview({
    required String contractId,
    required int rating,
    String? comment,
  }) => _tracedAndLogged<ServiceReview>('reviews.submit', () async {
    final ServiceReview review = await _repository.submitReview(
      contractId: contractId,
      rating: rating,
      comment: comment,
    );
    _logger?.info('Review submitted', <String, Object?>{
      'contractId': _redactor.redact(contractId),
      'rating': rating,
      'isRevealed': review.isRevealed,
    });
    return review;
  });

  /// Reads the viewer's submission status for [contractId].
  Future<MyReviewStatus> getMyStatus(String contractId) =>
      _tracedAndLogged<MyReviewStatus>('reviews.get_mine', () async {
        final MyReviewStatus status = await _repository.getMyStatus(
          contractId,
        );
        _logger?.info('Review status fetched', <String, Object?>{
          'contractId': _redactor.redact(contractId),
          'youHaveSubmitted': status.youHaveSubmitted,
          'revealedCount': status.revealedReviews.length,
        });
        return status;
      });

  /// Lists revealed reviews for [listingId] with keyset pagination.
  Future<ListingReviewsPage> getForListing({
    required String listingId,
    required String professionalEntityId,
    required String professionId,
    int limit = defaultPageLimit,
    String? cursor,
  }) => _tracedAndLogged<ListingReviewsPage>('reviews.get_for_listing', () async {
    final ListingReviewsPage page = await _repository.getForListing(
      listingId: listingId,
      professionalEntityId: professionalEntityId,
      professionId: professionId,
      limit: limit,
      cursor: cursor,
    );
    _logger?.info('Listing reviews fetched', <String, Object?>{
      'reviewCount': page.reviews.length,
      'hasMore': page.hasMore,
    });
    return page;
  });

  /// Wraps [action] in a `reviews.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'reviews');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: const SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'span': name},
      );
      rethrow;
    }
  }
}
