import 'package:hivorr/data/entities/service_listing.dart';
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
