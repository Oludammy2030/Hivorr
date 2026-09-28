import 'package:hivorr/data/models/listing_media_dto.dart';

/// Contract for service listing transport (EP-03-08 §11).
///
/// Wraps exactly the client-callable listing RPCs granted to `authenticated`
/// (`supabase/migrations/20260921090001_service_marketplace_schema.sql` +
/// `20260922090001_manage_user_capability_filter.sql:197-202`):
/// `service_listing_create`, `service_listing_update`,
/// `service_listing_publish`, `service_listing_unpublish`,
/// `service_listing_get`, `service_listing_list_mine`, plus the
/// read-through `service_favorite_toggle`.
///
/// Media rows (`service_listing_media`) are **not** part of this contract —
/// they use RLS-scoped REST (`insert/update(sort_order)/delete` own) per the
/// migration's sanctioned split (plan §7 rule 1).
abstract class ServiceListingRemoteDataSource {
  /// Creates a draft (default) or published listing
  /// (`service_listing_create`, VOLATILE).
  Future<Map<String, dynamic>> createListing({
    required String professionId,
    required String title,
    required String description,
    required String pricingType,
    double? priceMin,
    double? priceMax,
    String currencyCode = 'NGN',
    String status = 'draft',
  });

  /// Updates mutable fields (`service_listing_update`, VOLATILE).
  Future<Map<String, dynamic>> updateListing({
    required String listingId,
    String? title,
    String? description,
    String? professionId,
    String? pricingType,
    double? priceMin,
    double? priceMax,
    String? currencyCode,
  });

  /// Publishes a draft/paused listing (`service_listing_publish`, VOLATILE).
  Future<Map<String, dynamic>> publishListing(String listingId);

  /// Unpublishes a published listing to `paused`
  /// (`service_listing_unpublish`, VOLATILE). `reported` is service-role-only
  /// and is never passed by the client.
  Future<Map<String, dynamic>> unpublishListing(String listingId);

  /// Fetches a single listing with ordered `media[]`
  /// (`service_listing_get`, STABLE; public read of `published`, owner read
  /// of private states).
  Future<Map<String, dynamic>> getListing(String listingId);

  /// Lists the caller's listings with keyset pagination
  /// (`service_listing_list_mine`, STABLE).
  Future<MyListingPageDto> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  });

  /// Toggles the caller's favorite (read-through for detail preview only).
  Future<Map<String, dynamic>> toggleFavorite(String listingId);
}
