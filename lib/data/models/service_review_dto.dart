/// Data Transfer Objects for the double-blind review RPCs (EP-03-12).
///
/// Mirrors `service_review_submit` / `service_review_get_mine` /
/// `service_review_get_for_listing`
/// (`supabase/migrations/20260924090001_service_review_schema.sql:220-536`).
/// `reviewer/reviewee/listing/profession` ids are server-derived and never
/// supplied by the client; the client sends only
/// `p_contract_id + p_rating + p_comment`.
class ServiceReviewDto {
  const ServiceReviewDto({
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

  factory ServiceReviewDto.fromJson(Map<String, dynamic> json) =>
      ServiceReviewDto(
        id: (json['id'] as String?) ?? '',
        contractId: (json['contract_id'] as String?) ?? '',
        serviceListingId: (json['service_listing_id'] as String?) ?? '',
        reviewerEntityId: (json['reviewer_entity_id'] as String?) ?? '',
        revieweeEntityId: (json['reviewee_entity_id'] as String?) ?? '',
        professionId: (json['profession_id'] as String?) ?? '',
        rating: _parseRating(json['rating']) ?? 0,
        comment: json['comment'] as String?,
        isRevealed: (json['is_revealed'] as bool?) ?? false,
        revealedAt: _parseDate(json['revealed_at']),
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
      );

  final String id;
  final String contractId;
  final String serviceListingId;
  final String reviewerEntityId;
  final String revieweeEntityId;
  final String professionId;
  final int rating;
  final String? comment;
  final bool isRevealed;
  final DateTime? revealedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static int? _parseRating(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// DTO for a `service_review_aggregates` row.
class ReviewAggregateDto {
  const ReviewAggregateDto({
    required this.professionalEntityId,
    required this.professionId,
    required this.avgRating,
    required this.reviewCount,
    required this.distribution,
    this.lastRevealedAt,
  });

  factory ReviewAggregateDto.fromJson(Map<String, dynamic> json) =>
      ReviewAggregateDto(
        professionalEntityId:
            (json['professional_entity_id'] as String?) ?? '',
        professionId: (json['profession_id'] as String?) ?? '',
        avgRating: _parseDouble(json['avg_rating']) ?? 0,
        reviewCount: _parseCount(json['review_count']) ?? 0,
        distribution: _parseDistribution(json['distribution']),
        lastRevealedAt: _parseDate(
          json['last_revealed_at'] ?? json['lastRevealedAt'],
        ),
      );

  final String professionalEntityId;
  final String professionId;
  final double avgRating;
  final int reviewCount;
  final Map<int, int> distribution;
  final DateTime? lastRevealedAt;

  static double? _parseDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _parseCount(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static Map<int, int> _parseDistribution(Object? v) {
    const Map<int, int> empty = <int, int>{
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
    };
    if (v is! Map) return Map<int, int>.from(empty);
    final Map<int, int> result = Map<int, int>.from(empty);
    for (final MapEntry<Object?, Object?> entry
        in v.entries.cast<MapEntry<Object?, Object?>>()) {
      final int? stars = int.tryParse(entry.key.toString());
      if (stars == null || stars < 1 || stars > 5) continue;
      final Object? raw = entry.value;
      final int count = raw is num
          ? raw.toInt()
          : int.tryParse(raw.toString()) ?? 0;
      result[stars] = count;
    }
    return result;
  }
}

/// Envelope for `service_review_submit` (`data: {review}`).
class ReviewSubmitEnvelopeDto {
  const ReviewSubmitEnvelopeDto({required this.review});

  factory ReviewSubmitEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['review'];
    return ReviewSubmitEnvelopeDto(
      review: ServiceReviewDto.fromJson(
        raw is Map<String, dynamic> ? raw : const <String, dynamic>{},
      ),
    );
  }

  final ServiceReviewDto review;
}

/// Envelope for `service_review_get_mine`
/// (`data: {you_have_submitted, your_review, revealed_reviews[],
/// review_count}`).
class MyReviewStatusEnvelopeDto {
  const MyReviewStatusEnvelopeDto({
    required this.youHaveSubmitted,
    this.yourReview,
    required this.revealedReviews,
    required this.reviewCount,
  });

  factory MyReviewStatusEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? yourRaw = json['your_review'];
    final Object? revealedRaw =
        json['revealed_reviews'] ?? json['revealedReviews'];
    return MyReviewStatusEnvelopeDto(
      youHaveSubmitted:
          (json['you_have_submitted'] as bool?) ??
          (json['youHaveSubmitted'] as bool?) ??
          false,
      yourReview: yourRaw is Map<String, dynamic>
          ? ServiceReviewDto.fromJson(yourRaw)
          : null,
      revealedReviews: revealedRaw is List
          ? revealedRaw
                .whereType<Map<String, dynamic>>()
                .map(ServiceReviewDto.fromJson)
                .toList(growable: false)
          : const <ServiceReviewDto>[],
      reviewCount:
          (json['review_count'] as num?)?.toInt() ??
          (json['reviewCount'] as num?)?.toInt() ??
          0,
    );
  }

  final bool youHaveSubmitted;
  final ServiceReviewDto? yourReview;
  final List<ServiceReviewDto> revealedReviews;
  final int reviewCount;
}

/// Envelope for `service_review_get_for_listing`
/// (`data: {reviews[], avg_rating, review_count, distribution, has_more,
/// next_cursor}`).
class ListingReviewsEnvelopeDto {
  const ListingReviewsEnvelopeDto({
    required this.reviews,
    required this.avgRating,
    required this.reviewCount,
    required this.distribution,
    required this.hasMore,
    this.nextCursor,
  });

  factory ListingReviewsEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['reviews'];
    return ListingReviewsEnvelopeDto(
      reviews: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(ServiceReviewDto.fromJson)
                .toList(growable: false)
          : const <ServiceReviewDto>[],
      avgRating: _parseDouble(json['avg_rating']) ?? 0,
      reviewCount: _parseCount(json['review_count']) ?? 0,
      distribution: ReviewAggregateDto._parseDistribution(
        json['distribution'],
      ),
      hasMore:
          (json['has_more'] as bool?) ??
          (json['hasMore'] as bool?) ??
          false,
      nextCursor:
          (json['next_cursor'] as String?) ?? json['nextCursor'] as String?,
    );
  }

  final List<ServiceReviewDto> reviews;
  final double avgRating;
  final int reviewCount;
  final Map<int, int> distribution;
  final bool hasMore;
  final String? nextCursor;

  static double? _parseDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _parseCount(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
