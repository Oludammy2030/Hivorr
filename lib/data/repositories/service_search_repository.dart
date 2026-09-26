import 'package:hivorr/data/entities/service_listing.dart';

/// Abstract contract for ranked marketplace discovery.
///
/// The repository is the single ordering seam — it never reorders the RPC
/// `items` (`AGENT.md:7` Deterministic Core Supremacy). Cache policy is
/// defined by the implementation (`ServiceSearchRepositoryImpl`).
abstract class ServiceSearchRepository {
  /// Ranked search page for the given `filters`/`query`/`cursor`.
  ///
  /// `professionId` is the optional `p_profession_id` taxonomy filter.
  /// `query` is the optional FTS query (`p_query`).
  /// `filters` is the optional `p_filters` JSON (`price_min`, `rating_min`, …).
  /// `cursor` is the opaque `next_cursor` from a prior page (`null` for first).
  /// `limit` is `p_limit` `1..50` (default `20`).
  ///
  /// Returns `ServiceSearchPage` in RPC order verbatim.
  Future<ServiceSearchPage> search({
    String? professionId,
    String? query,
    ServiceSearchFilters? filters,
    ServiceListingCursor? cursor,
    int limit = 20,
  });

  /// Clears cached ranked pages (e.g., on `weights_version` bump).
  Future<void> invalidate();
}
