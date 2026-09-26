import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/repositories/service_search_repository.dart';

/// Controllable in-memory fake of [ServiceSearchRepository] for unit tests.
///
/// Returns verbatim `items` (never resorts — `AGENT.md:7` Deterministic Core).
/// Counts calls for cache-first assertions (`searchCallCount`).
class FakeServiceSearchRepository implements ServiceSearchRepository {
  FakeServiceSearchRepository({
    List<ServiceListing>? items,
    this.hasMore = false,
    this.weightsVersion,
  }) : _items = items ?? <ServiceListing>[];

  final List<ServiceListing> _items;
  final bool hasMore;
  final DateTime? weightsVersion;

  int searchCallCount = 0;
  int invalidateCallCount = 0;

  /// The last `professionId` passed to [search].
  String? lastProfessionId;

  /// The last `query` passed to [search].
  String? lastQuery;

  @override
  Future<ServiceSearchPage> search({
    String? professionId,
    String? query,
    ServiceSearchFilters? filters,
    ServiceListingCursor? cursor,
    int limit = 20,
  }) async {
    searchCallCount++;
    lastProfessionId = professionId;
    lastQuery = query;
    return ServiceSearchPage(
      items: _items,
      hasMore: hasMore,
      nextCursor: hasMore
          ? ServiceListingCursor(
              score: _items.last.score ?? 0.0,
              id: _items.last.id,
            )
          : null,
      weightsVersion: weightsVersion,
    );
  }

  @override
  Future<void> invalidate() async {
    invalidateCallCount++;
  }
}
