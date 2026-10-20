import 'package:hivorr/core/api/exceptions/api_exception.dart';
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

  List<ServiceListing> _items;
  final bool hasMore;
  final DateTime? weightsVersion;

  /// Sets the items returned by [search] (for test arrangement).
  set items(List<ServiceListing> value) => _items = value;

  /// Optional scripted keyset pages (EP-03-20 VP4). When non-null, [search]
  /// serves these in sequence: the first call (no cursor) returns page 1 and
  /// records its `nextCursor`; a later call advances only when the caller
  /// round-trips that exact cursor. A cursor miss or an exhausted script
  /// returns an empty terminal page (mirrors a server keyset miss).
  List<ServiceSearchPage>? pages;

  /// The last `cursor` passed to [search] (VP4 keyset round-trip assert).
  ServiceListingCursor? lastCursor;

  /// The last `limit` passed to [search] (VP4 no-unbounded-fetch assert).
  int? lastLimit;

  int _pageIndex = 0;
  ServiceListingCursor? _expectedCursor;

  int searchCallCount = 0;
  int invalidateCallCount = 0;

  /// The last `professionId` passed to [search].
  String? lastProfessionId;

  /// The last `query` passed to [search].
  String? lastQuery;

  /// The last `filters` passed to [search].
  ServiceSearchFilters? lastFilters;

  /// When set, [search] throws this instead of returning a page (e.g. a
  /// `PLT004` [ApiException] for no-oracle empty-state tests).
  ApiException? searchError;

  ServiceSearchPage _emptyPage() => ServiceSearchPage(
    items: const <ServiceListing>[],
    hasMore: false,
    nextCursor: null,
    weightsVersion: weightsVersion,
  );

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
    lastFilters = filters;
    lastCursor = cursor;
    lastLimit = limit;
    final ApiException? error = searchError;
    if (error != null) throw error;

    final List<ServiceSearchPage>? scripted = pages;
    if (scripted != null) {
      // First call (no cursor) serves page 1 and records its nextCursor.
      if (cursor == null) {
        _pageIndex = 1;
        if (scripted.isEmpty) return _emptyPage();
        final ServiceSearchPage first = scripted.first;
        _expectedCursor = first.nextCursor;
        return first;
      }
      // Advance only when the caller round-trips the exact prior cursor.
      final ServiceListingCursor? expected = _expectedCursor;
      final bool matches =
          expected != null &&
          cursor.score == expected.score &&
          cursor.id == expected.id;
      if (matches && _pageIndex < scripted.length) {
        final ServiceSearchPage next = scripted[_pageIndex];
        _pageIndex += 1;
        _expectedCursor = next.nextCursor;
        return next;
      }
      return _emptyPage();
    }

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
