/// Data Transfer Object for `service_listings` rows returned by
/// `service_ranking_search` (`20260927090001_platform_config_and_ranking.sql:233`).
///
/// Maps server snake_case columns exactly via [fromJson]; `toJson` round-trips
/// for local cache. `score` is transient (`numeric(10,6)`) and nullable on
/// non-ranked rows.
class ServiceListingDto {
  const ServiceListingDto({
    required this.id,
    required this.entityId,
    required this.professionId,
    required this.industryId,
    required this.slug,
    required this.title,
    required this.description,
    required this.pricingType,
    this.priceMin,
    this.priceMax,
    required this.currencyCode,
    required this.avgRating,
    required this.reviewCount,
    required this.isTradeVerifiedCache,
    this.publishedAt,
    this.createdAt,
    this.professionSlug,
    this.professionName,
    this.industrySlug,
    this.industryName,
    this.score,
  });

  factory ServiceListingDto.fromJson(Map<String, dynamic> json) {
    double? parseDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    int parseInt(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ServiceListingDto(
      id: json['id'] as String,
      entityId: json['entity_id'] as String,
      professionId: json['profession_id'] as String,
      industryId: json['industry_id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      pricingType: json['pricing_type'] as String,
      priceMin: parseDouble(json['price_min']),
      priceMax: parseDouble(json['price_max']),
      currencyCode: json['currency_code'] as String,
      avgRating: parseDouble(json['avg_rating']) ?? 0.0,
      reviewCount: parseInt(json['review_count']),
      isTradeVerifiedCache: json['is_trade_verified_cache'] as bool? ?? false,
      publishedAt: parseDate(json['published_at']),
      createdAt: parseDate(json['created_at']),
      professionSlug: json['profession_slug'] as String?,
      professionName: json['profession_name'] as String?,
      industrySlug: json['industry_slug'] as String?,
      industryName: json['industry_name'] as String?,
      score: parseDouble(json['score']),
    );
  }

  final String id;
  final String entityId;
  final String professionId;
  final String industryId;
  final String slug;
  final String title;
  final String description;
  final String pricingType;
  final double? priceMin;
  final double? priceMax;
  final String currencyCode;
  final double avgRating;
  final int reviewCount;
  final bool isTradeVerifiedCache;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final String? professionSlug;
  final String? professionName;
  final String? industrySlug;
  final String? industryName;
  final double? score;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'entity_id': entityId,
        'profession_id': professionId,
        'industry_id': industryId,
        'slug': slug,
        'title': title,
        'description': description,
        'pricing_type': pricingType,
        if (priceMin != null) 'price_min': priceMin,
        if (priceMax != null) 'price_max': priceMax,
        'currency_code': currencyCode,
        'avg_rating': avgRating,
        'review_count': reviewCount,
        'is_trade_verified_cache': isTradeVerifiedCache,
        if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (professionSlug != null) 'profession_slug': professionSlug,
        if (professionName != null) 'profession_name': professionName,
        if (industrySlug != null) 'industry_slug': industrySlug,
        if (industryName != null) 'industry_name': industryName,
        if (score != null) 'score': score,
      };
}

/// DTO wrapper for a ranked page envelope `data:{items,has_more,next_cursor,weights_version}`.
class ServiceSearchPageDto {
  const ServiceSearchPageDto({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.weightsVersion,
  });

  factory ServiceSearchPageDto.fromJson(Map<String, dynamic> data) {
    final List<dynamic> rawItems = data['items'] as List<dynamic>? ?? <dynamic>[];
    final List<ServiceListingDto> items = rawItems
        .map((Object? e) =>
            ServiceListingDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final bool hasMore = data['has_more'] as bool? ?? false;
    final Map<String, dynamic>? cursorJson =
        data['next_cursor'] as Map<String, dynamic>?;
    Map<String, dynamic>? cursorDto;
    if (cursorJson != null) {
      cursorDto = <String, dynamic>{
        'score': cursorJson['score'],
        'id': cursorJson['id'],
      };
    }
    DateTime? weightsVersion;
    final Object? wv = data['weights_version'];
    if (wv is String) weightsVersion = DateTime.tryParse(wv);
    return ServiceSearchPageDto(
      items: items,
      hasMore: hasMore,
      nextCursor: cursorDto,
      weightsVersion: weightsVersion,
    );
  }

  final List<ServiceListingDto> items;
  final bool hasMore;
  final Map<String, dynamic>? nextCursor;
  final DateTime? weightsVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items.map((ServiceListingDto e) => e.toJson()).toList(),
        'has_more': hasMore,
        if (nextCursor != null) 'next_cursor': nextCursor,
        if (weightsVersion != null)
          'weights_version': weightsVersion!.toIso8601String(),
      };
}
