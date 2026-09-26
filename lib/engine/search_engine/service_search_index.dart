import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/repositories/service_search_repository.dart';
import 'package:hivorr/workspace/profession_registry/taxonomy_engine.dart';

/// Thin offline-browse cache warmer for ranked marketplace discovery.
///
/// Composes the existing `ServiceSearchRepository` + `TaxonomyEngine` to
/// pre-populate the two-tier cache (transient `LruCache 5m` + persistent
/// `Hive` via `HiveServiceSearchLocalDataSource`) with warm ranked browse
/// pages. **Never decides ordering** — `items` from the repository are
/// preserved verbatim (`AGENT.md:7` Deterministic Core Supremacy).
///
/// Lives in `lib/engine/search_engine/` per `ARCHITECTURE.md:71` (`search_engine =
/// offline & local indexing`). Distinct from
/// `lib/engine/recommendation_engine/` (`RankingFormula` scorer) and
/// `lib/engine/matching_engine/` (EP-04 spatial routing seam).
///
/// Consumers:
/// * `MarketplaceSearchProvider.refresh()` — called on `weights_version` bump
///   to pre-warm cache with the new ranking order.
/// * `EP-03-09 marketplace_discovery_screen` — called on `initState` to
///   pre-warm Top-20 per warm profession before the user browses.
class ServiceSearchIndex {
  ServiceSearchIndex({
    required this.repository,
    required this.taxonomy,
  });

  /// The ranked search repository (cache-first for browse).
  final ServiceSearchRepository repository;

  /// The taxonomy engine used to iterate warm professions.
  final TaxonomyEngine taxonomy;

  /// Default number of ranked items to pre-warm per warm profession.
  static const int warmLimit = 20;

  /// Default number of top professions (by `sortOrder`) to pre-warm.
  static const int warmProfessionCount = 20;

  /// Pre-warms a single browse page (no FTS query) into the two-tier cache.
  ///
  /// Returns the ranked page (verbatim RPC order). The repository handles
  /// cache-first policy internally (`isBrowse cache-first 62`); this method
  /// exists only as a named entry point for discovery screens to call on
  /// `initState` without coupling to the repository directly.
  Future<ServiceSearchPage> warmBrowse({
    String? professionId,
    int limit = warmLimit,
  }) async {
    return repository.search(
      professionId: professionId,
      query: null,
      filters: null,
      cursor: null,
      limit: limit,
    );
  }

  /// Pre-warms ranked browse pages for the Top-[warmProfessionCount]
  /// professions (by `TaxonomyEngine.browseProfessions` `sortOrder`) plus
  /// one unscoped cross-profession page.
  ///
  /// Returns the count of professions warmed (for telemetry). Designed for
  /// airplane-mode / cold-start resilience — pages are persisted via the
  /// repository's two-tier cache so subsequent `search()` calls on the
  /// same filters hit cache without a network round-trip.
  Future<int> hydrateOffline({int limit = warmLimit}) async {
    int count = 0;

    // 1. Unscoped cross-profession top page.
    await repository.search(
      professionId: null,
      query: null,
      filters: null,
      cursor: null,
      limit: limit,
    );
    count++;

    // 2. Per-profession top pages.
    final List<Industry> industries = await taxonomy.browseIndustries();
    for (final Industry industry in industries) {
      final List<Profession> professions = await taxonomy.browseProfessions(
        industry.id,
      );
      for (int i = 0;
          i < professions.length && count < warmProfessionCount + 1;
          i++) {
        await repository.search(
          professionId: professions[i].id,
          query: null,
          filters: null,
          cursor: null,
          limit: limit,
        );
        count++;
      }
      if (count >= warmProfessionCount + 1) break;
    }

    return count;
  }
}
