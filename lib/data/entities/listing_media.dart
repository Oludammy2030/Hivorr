/// Pure Dart domain model for a `service_listing_media` row.
///
/// Mirrors the `service_listing_get` media projection ordered by
/// `sort_order ASC, created_at ASC`. No framework or backend dependency.
class ListingMedia {
  const ListingMedia({
    required this.id,
    required this.storagePath,
    required this.mimeType,
    required this.sortOrder,
    this.createdAt,
  });

  /// Primary key (UUID).
  final String id;

  /// Storage key under `service-listing-media/{entity_id}/{listing_id}/...`.
  final String storagePath;

  /// MIME type (`image/jpeg|image/png|image/webp|application/pdf`).
  final String mimeType;

  /// Display order (`sort_order >= 0`, `0` is the cover).
  final int sortOrder;

  /// Audit creation timestamp.
  final DateTime? createdAt;

  /// Whether this media is the cover (first in server order).
  bool get isCover => sortOrder == 0;
}

/// Owner-scoped page returned by `service_listing_list_mine`.
///
/// Keyset is `(created_at DESC, id DESC)` with an opaque `uuid` cursor —
/// distinct from the ranked `(score, id)` cursor in [ServiceListingCursor].
class MyListingPage {
  const MyListingPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  /// Owner listings in server order (verbatim, never client-sorted).
  final List<MyServiceListing> items;

  /// Whether another page exists.
  final bool hasMore;

  /// Opaque `uuid` cursor for the next page (`null` when [hasMore] false).
  final String? nextCursor;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}

/// Owner projection of a `service_listings` row.
///
/// Extends the ranked [ServiceListing] projection with the mutable `status`,
/// attached [media], and `updatedAt`. Ranked discovery fields
/// (`avgRating`, `reviewCount`, `score`, slugs) are carried through so detail
/// screens can render verification/rating context without a second RPC.
class MyServiceListing {
  const MyServiceListing({
    required this.id,
    required this.entityId,
    required this.professionId,
    required this.industryId,
    required this.slug,
    required this.title,
    required this.description,
    required this.status,
    required this.pricingType,
    this.priceMin,
    this.priceMax,
    required this.currencyCode,
    required this.avgRating,
    required this.reviewCount,
    required this.isTradeVerifiedCache,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
    this.professionSlug,
    this.professionName,
    this.industrySlug,
    this.industryName,
    this.media = const <ListingMedia>[],
  });

  final String id;
  final String entityId;
  final String professionId;
  final String industryId;
  final String slug;
  final String title;
  final String description;

  /// Lifecycle (`draft|published|paused|archived|reported`). Client writes
  /// only `draft→published→paused`; `archived/reported` are read-only.
  final String status;
  final String pricingType;
  final double? priceMin;
  final double? priceMax;
  final String currencyCode;
  final double avgRating;
  final int reviewCount;
  final bool isTradeVerifiedCache;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? professionSlug;
  final String? professionName;
  final String? industrySlug;
  final String? industryName;

  /// Attached media in server order (`sort_order, created_at`).
  final List<ListingMedia> media;

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isPaused => status == 'paused';
  bool get isArchived => status == 'archived';
  bool get isReported => status == 'reported';

  /// Whether the owner may edit fields (draft/paused fully, published
  /// description-only per the D5 trigger — enforced server-side).
  bool get isEditable => status == 'draft' || status == 'paused';

  /// Whether the owner may attempt publish (draft/paused).
  bool get canPublish => status == 'draft' || status == 'paused';

  /// Whether the owner may unpublish (published only).
  bool get canUnpublish => status == 'published';
}
