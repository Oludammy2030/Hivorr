/// Pure Dart domain model for a marketplace `service_listings` row.
///
/// Mirrors the `service_listings` table columns exposed by the ranked RPC
/// `service_ranking_search` (`20260921090001_service_marketplace_schema.sql:42`,
/// `20260927090001_platform_config_and_ranking.sql:233`) plus denormalized
/// profession/industry slugs/names. `score` is transient (computed per ranked
/// page, not persisted) and is present only on ranked results.
///
/// No framework or backend dependency.
class ServiceListing {
  const ServiceListing({
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

  /// Primary key (UUID).
  final String id;

  /// FK → `entities.id` (owner).
  final String entityId;

  /// FK → `professions.id`.
  final String professionId;

  /// FK → `industries.id` (denormalized via trigger, never client-supplied).
  final String industryId;

  /// SEO-stable slug (`^[a-z0-9]+(-[a-z0-9]+)*$`).
  final String slug;

  /// Title `10..120` chars.
  final String title;

  /// Description `50..5000` chars.
  final String description;

  /// Pricing type vocabulary (`fixed|hourly|custom|per_milestone`).
  final String pricingType;

  /// Minimum price (nullable for `custom`).
  final double? priceMin;

  /// Maximum price (nullable).
  final double? priceMax;

  /// ISO 4217 currency code (`NGN|GHS|USD|GBP`).
  final String currencyCode;

  /// Denormalized `avg_rating` `0..5` (EP-03-03 reveal cache).
  final double avgRating;

  /// Denormalized `review_count`.
  final int reviewCount;

  /// Denormalized trade-gate snapshot set at publish time.
  final bool isTradeVerifiedCache;

  /// `timestamptz` when `status='published'` else `null`.
  final DateTime? publishedAt;

  /// Audit creation timestamp.
  final DateTime? createdAt;

  /// Denormalized profession slug for SEO `/s/:profession_slug/:id`.
  final String? professionSlug;

  /// Denormalized profession display name.
  final String? professionName;

  /// Denormalized industry slug.
  final String? industrySlug;

  /// Denormalized industry display name.
  final String? industryName;

  /// Ranked-page score `0..1` (`numeric(10,6)`), transient — present only
  /// on `service_ranking_search` pages, `null` on owner CRUD rows.
  final double? score;
}

/// Immutable cursor for keyset pagination `(score DESC, id DESC)`.
///
/// Mirrors the `p_cursor jsonb {score numeric, id uuid}` contract in
/// `20260927090001_platform_config_and_ranking.sql:233` and the `next_cursor`
/// returned in `data.next_cursor`.
class ServiceListingCursor {
  const ServiceListingCursor({required this.score, required this.id});

  /// `score` from the last item's `score` (6-decimal).
  final double score;

  /// `id` of the last item.
  final String id;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'score': score,
        'id': id,
      };

  factory ServiceListingCursor.fromJson(Map<String, dynamic> json) =>
      ServiceListingCursor(
        score: (json['score'] as num).toDouble(),
        id: json['id'] as String,
      );
}

/// Ranked page returned by the recommendation engine.
///
/// Never decides order — `items` are assigned verbatim from the RPC
/// (`AGENT.md:7`).
class ServiceSearchPage {
  const ServiceSearchPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.weightsVersion,
  });

  /// Ranked listings in RPC order.
  final List<ServiceListing> items;

  /// Whether another page exists (`ordered` had `p_limit+1` rows).
  final bool hasMore;

  /// Keyset cursor for the next page (`null` when `hasMore` false).
  final ServiceListingCursor? nextCursor;

  /// `platform_config.updated_at` for `service_ranking_weights` (cache invalidation).
  final DateTime? weightsVersion;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}

/// Filters composing `p_filters jsonb` validated server-side
/// (`20260927090001_platform_config_and_ranking.sql:400`).
class ServiceSearchFilters {
  const ServiceSearchFilters({
    this.professionId,
    this.industryId,
    this.priceMin,
    this.priceMax,
    this.currencyCode,
    this.ratingMin,
    this.isTradeVerifiedOnly,
    this.availabilityDate,
  });

  final String? professionId;
  final String? industryId;
  final double? priceMin;
  final double? priceMax;
  final String? currencyCode; // ISO 4217, active only
  final double? ratingMin; // 0..5
  final bool? isTradeVerifiedOnly; // alias is_verified_only
  final DateTime? availabilityDate; // timestamptz, PLT003 on bad cast server-side

  bool get isEmpty =>
      professionId == null &&
      industryId == null &&
      priceMin == null &&
      priceMax == null &&
      currencyCode == null &&
      ratingMin == null &&
      isTradeVerifiedOnly == null &&
      availabilityDate == null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> m = <String, dynamic>{};
    if (professionId != null) m['profession_id'] = professionId;
    if (industryId != null) m['industry_id'] = industryId;
    if (priceMin != null) m['price_min'] = priceMin;
    if (priceMax != null) m['price_max'] = priceMax;
    if (currencyCode != null) m['currency_code'] = currencyCode;
    if (ratingMin != null) m['rating_min'] = ratingMin;
    if (isTradeVerifiedOnly != null) {
      m['is_trade_verified_only'] = isTradeVerifiedOnly;
    }
    if (availabilityDate != null) {
      m['availability_date'] = availabilityDate!.toIso8601String();
    }
    return m;
  }
}
