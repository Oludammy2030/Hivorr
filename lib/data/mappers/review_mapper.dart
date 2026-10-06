import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/models/service_review_dto.dart';

/// Transformations between the double-blind review transport DTOs and the
/// pure-Dart domain entities (EP-03-12).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying. Server order
/// is preserved verbatim (never re-sorted client-side).
abstract final class ReviewMapper {
  /// Maps a `service_reviews` DTO into a domain [ServiceReview].
  static ServiceReview reviewToEntity(ServiceReviewDto dto) => ServiceReview(
    id: dto.id,
    contractId: dto.contractId,
    serviceListingId: dto.serviceListingId,
    reviewerEntityId: dto.reviewerEntityId,
    revieweeEntityId: dto.revieweeEntityId,
    professionId: dto.professionId,
    rating: dto.rating,
    comment: dto.comment,
    isRevealed: dto.isRevealed,
    revealedAt: dto.revealedAt,
    createdAt: dto.createdAt,
    updatedAt: dto.updatedAt,
  );

  /// Maps a `service_review_submit` envelope into a domain [ServiceReview].
  static ServiceReview submitEnvelopeToEntity(
    ReviewSubmitEnvelopeDto dto,
  ) => reviewToEntity(dto.review);

  /// Maps a `service_review_get_mine` envelope into a [MyReviewStatus].
  ///
  /// The `contractId` is caller-supplied (the RPC nests it inside each row,
  /// but the envelope header does not repeat it).
  static MyReviewStatus myStatusEnvelopeToEntity(
    MyReviewStatusEnvelopeDto dto,
    String contractId,
  ) => MyReviewStatus(
    contractId: contractId,
    youHaveSubmitted: dto.youHaveSubmitted,
    yourReview: dto.yourReview == null
        ? null
        : reviewToEntity(dto.yourReview!),
    revealedReviews: dto.revealedReviews.map(reviewToEntity).toList(
      growable: false,
    ),
    reviewCount: dto.reviewCount,
  );

  /// Maps a `service_review_get_for_listing` envelope into a
  /// [ListingReviewsPage] with its aggregate header.
  ///
  /// The aggregate is keyed by the listing owner + profession; when the
  /// server reports `review_count == 0` the aggregate is synthesized as
  /// empty so widgets render a stable header.
  static ListingReviewsPage listingEnvelopeToPage(
    ListingReviewsEnvelopeDto dto, {
    required String professionalEntityId,
    required String professionId,
  }) {
    final ReviewAggregate? aggregate = dto.reviewCount <= 0
        ? null
        : ReviewAggregate(
            professionalEntityId: professionalEntityId,
            professionId: professionId,
            avgRating: dto.avgRating,
            reviewCount: dto.reviewCount,
            distribution: Map<int, int>.from(dto.distribution),
          );
    return ListingReviewsPage(
      reviews: dto.reviews.map(reviewToEntity).toList(growable: false),
      aggregate: aggregate,
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }
}
