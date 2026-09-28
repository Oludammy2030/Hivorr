import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/models/listing_media_dto.dart';
import 'package:hivorr/data/models/service_listing_dto.dart';

/// Transforms [ServiceListingDto] ↔ [ServiceListing].
///
/// The single transformation boundary between the transport DTO and the
/// pure-Dart domain entity (EP-01-08 §5.3). No I/O and no business logic —
/// only null-safe field copying. Mirrors `ProfessionMapper`.
class ServiceListingMapper {
  const ServiceListingMapper._();

  /// Maps a ranked-page DTO into the domain entity.
  static ServiceListing toEntity(ServiceListingDto dto) => ServiceListing(
        id: dto.id,
        entityId: dto.entityId,
        professionId: dto.professionId,
        industryId: dto.industryId,
        slug: dto.slug,
        title: dto.title,
        description: dto.description,
        pricingType: dto.pricingType,
        priceMin: dto.priceMin,
        priceMax: dto.priceMax,
        currencyCode: dto.currencyCode,
        avgRating: dto.avgRating,
        reviewCount: dto.reviewCount,
        isTradeVerifiedCache: dto.isTradeVerifiedCache,
        publishedAt: dto.publishedAt,
        createdAt: dto.createdAt,
        professionSlug: dto.professionSlug,
        professionName: dto.professionName,
        industrySlug: dto.industrySlug,
        industryName: dto.industryName,
        score: dto.score,
      );

  /// Maps a domain entity back into a DTO (for local cache).
  static ServiceListingDto fromEntity(ServiceListing entity) =>
      ServiceListingDto(
        id: entity.id,
        entityId: entity.entityId,
        professionId: entity.professionId,
        industryId: entity.industryId,
        slug: entity.slug,
        title: entity.title,
        description: entity.description,
        pricingType: entity.pricingType,
        priceMin: entity.priceMin,
        priceMax: entity.priceMax,
        currencyCode: entity.currencyCode,
        avgRating: entity.avgRating,
        reviewCount: entity.reviewCount,
        isTradeVerifiedCache: entity.isTradeVerifiedCache,
        publishedAt: entity.publishedAt,
        createdAt: entity.createdAt,
        professionSlug: entity.professionSlug,
        professionName: entity.professionName,
        industrySlug: entity.industrySlug,
        industryName: entity.industryName,
        score: entity.score,
      );

  /// Maps a `service_listing_media` DTO into the domain entity.
  static ListingMedia toMediaEntity(ListingMediaDto dto) => ListingMedia(
        id: dto.id,
        storagePath: dto.storagePath,
        mimeType: dto.mimeType,
        sortOrder: dto.sortOrder,
        createdAt: dto.createdAt,
      );

  /// Maps an owner-projection row (`service_listing_create/update/publish/
  /// unpublish/get/list_mine` `data`) into [MyServiceListing].
  ///
  /// The row shape matches `service_listing_get` (single object with optional
  /// `media[]`) and `list_mine` items (without `media`). Media order is
  /// preserved verbatim (`sort_order, created_at`). No business logic —
  /// only null-safe field copying.
  static MyServiceListing toOwnerEntity(Map<String, dynamic> json) {
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

    final Object? rawMedia = json['media'];
    final List<ListingMedia> media = <ListingMedia>[];
    if (rawMedia is List) {
      for (final Object? e in rawMedia) {
        if (e is Map<String, dynamic>) {
          media.add(toMediaEntity(ListingMediaDto.fromJson(e)));
        } else if (e is Map) {
          media.add(
            toMediaEntity(
              ListingMediaDto.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
        }
      }
    }

    return MyServiceListing(
      id: json['id'] as String,
      entityId: json['entity_id'] as String? ?? '',
      professionId: json['profession_id'] as String? ?? '',
      industryId: json['industry_id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      pricingType: json['pricing_type'] as String? ?? 'custom',
      priceMin: parseDouble(json['price_min']),
      priceMax: parseDouble(json['price_max']),
      currencyCode: json['currency_code'] as String? ?? 'NGN',
      avgRating: parseDouble(json['avg_rating']) ?? 0.0,
      reviewCount: parseInt(json['review_count']),
      isTradeVerifiedCache:
          json['is_trade_verified_cache'] as bool? ?? false,
      publishedAt: parseDate(json['published_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      professionSlug: json['profession_slug'] as String?,
      professionName: json['profession_name'] as String?,
      industrySlug: json['industry_slug'] as String?,
      industryName: json['industry_name'] as String?,
      media: media,
    );
  }

  /// Maps a `list_mine` items array into an owner page (verbatim order).
  static MyListingPage toOwnerPage({
    required List<Map<String, dynamic>> items,
    required bool hasMore,
    String? nextCursor,
  }) {
    final List<MyServiceListing> entities =
        items.map(toOwnerEntity).toList(growable: false);
    return MyListingPage(
      items: entities,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  /// Maps a page DTO into the domain page (preserves RPC order verbatim).
  static ServiceSearchPage toPageEntity(ServiceSearchPageDto dto) {
    final List<ServiceListing> items =
        dto.items.map(toEntity).toList(growable: false);
    ServiceListingCursor? cursor;
    final Map<String, dynamic>? c = dto.nextCursor;
    if (c != null && c['score'] != null && c['id'] != null) {
      cursor = ServiceListingCursor(
        score: (c['score'] as num).toDouble(),
        id: c['id'] as String,
      );
    }
    return ServiceSearchPage(
      items: items,
      hasMore: dto.hasMore,
      nextCursor: cursor,
      weightsVersion: dto.weightsVersion,
    );
  }
}
