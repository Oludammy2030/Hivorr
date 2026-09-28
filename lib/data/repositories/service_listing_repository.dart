import 'package:hivorr/data/entities/listing_media.dart';

/// Abstract contract for service listing data operations (EP-03-08 §8 D4).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface rather than a Supabase
/// implementation (ARCHITECTURE.md / EP-01-08 §5.6).
///
/// All listing writes flow through the client-callable RPCs
/// (`service_listing_create/update/publish/unpublish`); this repository
/// **never** writes `service_listings` tables directly and **never** attempts
/// the service_role-only `reported` transition.
abstract class ServiceListingRepository {
  /// Creates a draft (default) or published listing, then re-reads the
  /// authoritative row via `service_listing_get`.
  ///
  /// Pre-validates title (10–120), description (50–5000), pricing vocabulary
  /// and price rules, and currency before the RPC (fail-fast `PLT003`).
  Future<MyServiceListing> createListing({
    required String professionId,
    required String title,
    required String description,
    required String pricingType,
    double? priceMin,
    double? priceMax,
    String currencyCode = 'NGN',
    String status = 'draft',
  });

  /// Updates mutable fields, then re-reads the authoritative row.
  Future<MyServiceListing> updateListing({
    required String listingId,
    String? title,
    String? description,
    String? professionId,
    String? pricingType,
    double? priceMin,
    double? priceMax,
    String? currencyCode,
  });

  /// Publishes a draft/paused listing, then re-reads the authoritative row.
  ///
  /// The trade gate (`approved` for the bound profession) is enforced
  /// server-side (`PLT005`); the UI surfaces guidance on that code.
  Future<MyServiceListing> publishListing(String listingId);

  /// Unpublishes a published listing to `paused`, then re-reads the row.
  Future<MyServiceListing> unpublishListing(String listingId);

  /// Fetches a single listing with ordered `media[]` in one RPC.
  Future<MyServiceListing> getListing(String listingId);

  /// Lists the caller's listings with keyset pagination
  /// (`(created_at DESC, id DESC)`), optionally filtered by [status].
  Future<MyListingPage> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  });
}
