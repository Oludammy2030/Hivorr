import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/service_listing_remote_data_source.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/entities/service_listing_proof.dart';
import 'package:hivorr/data/models/listing_media_dto.dart';
import 'package:hivorr/data/repositories/service_listing_repository.dart';

/// In-memory fake for [ServiceListingRemoteDataSource] (EP-03-08 tests).
class FakeServiceListingRemoteDataSource
    implements ServiceListingRemoteDataSource {
  FakeServiceListingRemoteDataSource({
    List<Map<String, dynamic>>? seed,
    Map<String, List<Map<String, dynamic>>>? proofSeed,
  }) : _rows = <Map<String, dynamic>>[...?seed],
       proofSeed = proofSeed ?? <String, List<Map<String, dynamic>>>{};

  final List<Map<String, dynamic>> _rows;

  int createCalls = 0;
  int updateCalls = 0;
  int publishCalls = 0;
  int unpublishCalls = 0;
  int getCalls = 0;
  int listCalls = 0;
  int linkProofCalls = 0;
  int unlinkProofCalls = 0;
  int listProofCalls = 0;
  String? lastStatus;
  String? lastCursor;

  /// Proof rows served by [listPortfolioProofs], keyed by listing id
  /// (EP-03-15). Each row uses the `service_listing_portfolio_list` item
  /// shape (`id`, `item_type`, `title`, `description`, `media_path`,
  /// `sort_order`, `link_sort_order`).
  final Map<String, List<Map<String, dynamic>>> proofSeed;

  /// The last portfolio ids passed to [linkPortfolioItems].
  List<String>? lastLinkedIds;

  /// The last `(listingId, portfolioItemId)` passed to [unlinkPortfolioItem].
  (String, String)? lastUnlinked;

  static Map<String, dynamic> row({
    required String id,
    String status = 'draft',
    String title = 'Certified plumbing repair service',
    String description =
        'Full home plumbing inspection, leak repair, and fixture replacement with a written service report and warranty.',
    String pricingType = 'fixed',
    double? priceMin = 5000,
    double? priceMax,
    String currencyCode = 'NGN',
    String professionId = 'prof-1',
    List<Map<String, dynamic>> media = const <Map<String, dynamic>>[],
  }) =>
      <String, dynamic>{
        'id': id,
        'entity_id': 'entity-1',
        'profession_id': professionId,
        'industry_id': 'ind-1',
        'slug': 'listing-$id',
        'title': title,
        'description': description,
        'status': status,
        'pricing_type': pricingType,
        'price_min': ?priceMin,
        'price_max': ?priceMax,
        'currency_code': currencyCode,
        'avg_rating': 0,
        'review_count': 0,
        'is_trade_verified_cache': false,
        'created_at': '2026-09-26T10:00:00.000Z',
        'updated_at': '2026-09-26T10:00:00.000Z',
        'media': media,
      };

  Map<String, dynamic> _find(String id) => _rows.firstWhere(
        (Map<String, dynamic> e) => e['id'] == id,
        orElse: () => throw StateError('not found: $id'),
      );

  @override
  Future<Map<String, dynamic>> createListing({
    required String professionId,
    required String title,
    required String description,
    required String pricingType,
    double? priceMin,
    double? priceMax,
    String currencyCode = 'NGN',
    String status = 'draft',
  }) async {
    createCalls++;
    final Map<String, dynamic> created = row(
      id: 'listing-${_rows.length + 1}',
      status: status,
      title: title,
      description: description,
      pricingType: pricingType,
      priceMin: priceMin,
      priceMax: priceMax,
      currencyCode: currencyCode,
      professionId: professionId,
    );
    _rows.insert(0, created);
    return created;
  }

  @override
  Future<Map<String, dynamic>> updateListing({
    required String listingId,
    String? title,
    String? description,
    String? professionId,
    String? pricingType,
    double? priceMin,
    double? priceMax,
    String? currencyCode,
  }) async {
    updateCalls++;
    final Map<String, dynamic> current = Map<String, dynamic>.from(
      _find(listingId),
    );
    if (title != null) current['title'] = title;
    if (description != null) current['description'] = description;
    if (professionId != null) current['profession_id'] = professionId;
    if (pricingType != null) current['pricing_type'] = pricingType;
    if (priceMin != null) current['price_min'] = priceMin;
    if (priceMax != null) current['price_max'] = priceMax;
    if (currencyCode != null) current['currency_code'] = currencyCode;
    final int index = _rows.indexWhere((e) => e['id'] == listingId);
    _rows[index] = current;
    return current;
  }

  @override
  Future<Map<String, dynamic>> publishListing(String listingId) async {
    publishCalls++;
    final Map<String, dynamic> current = Map<String, dynamic>.from(
      _find(listingId),
    );
    current['status'] = 'published';
    final int index = _rows.indexWhere((e) => e['id'] == listingId);
    _rows[index] = current;
    return current;
  }

  @override
  Future<Map<String, dynamic>> unpublishListing(String listingId) async {
    unpublishCalls++;
    final Map<String, dynamic> current = Map<String, dynamic>.from(
      _find(listingId),
    );
    current['status'] = 'paused';
    final int index = _rows.indexWhere((e) => e['id'] == listingId);
    _rows[index] = current;
    return current;
  }

  @override
  Future<Map<String, dynamic>> getListing(String listingId) async {
    getCalls++;
    return Map<String, dynamic>.from(_find(listingId));
  }

  @override
  Future<MyListingPageDto> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    listCalls++;
    lastStatus = status;
    lastCursor = cursor;
    final List<Map<String, dynamic>> filtered = status == null
        ? List<Map<String, dynamic>>.from(_rows)
        : _rows.where((e) => e['status'] == status).toList();
    final List<Map<String, dynamic>> items = filtered.take(limit).toList();
    return MyListingPageDto.fromJson(<String, dynamic>{
      'items': items,
      'has_more': filtered.length > items.length,
      'next_cursor':
          filtered.length > items.length ? items.last['id'] : null,
    });
  }

  @override
  Future<Map<String, dynamic>> toggleFavorite(String listingId) async =>
      <String, dynamic>{'listing_id': listingId, 'favorited': true};

  /// A `service_listing_portfolio_list` item row (EP-03-15 tests).
  static Map<String, dynamic> proofRow({
    required String id,
    String itemType = 'image',
    String title = 'Linked proof piece',
    String description = 'Proof of completed work.',
    String? mediaPath,
    int? sortOrder = 1,
    int? linkSortOrder = 1,
  }) => <String, dynamic>{
    'id': id,
    'item_type': itemType,
    'title': title,
    'description': description,
    'media_path': mediaPath,
    'sort_order': sortOrder,
    'link_sort_order': linkSortOrder,
  };

  @override
  Future<Map<String, dynamic>> linkPortfolioItems({
    required String listingId,
    required List<String> portfolioItemIds,
  }) async {
    linkProofCalls++;
    lastLinkedIds = List<String>.unmodifiable(portfolioItemIds);
    // Full-replace: previously linked rows are superseded by the new set.
    final List<Map<String, dynamic>> existing =
        proofSeed[listingId] ?? <Map<String, dynamic>>[];
    final Map<String, Map<String, dynamic>> byId = <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in existing)
        row['id'] as String: row,
    };
    int order = 0;
    proofSeed[listingId] = <Map<String, dynamic>>[
      for (final String id in portfolioItemIds)
        byId[id] ??
            proofRow(
              id: id,
              title: 'Linked proof $id',
              linkSortOrder: ++order,
            ),
    ];
    // Re-stamp link order from the array position (server semantics).
    order = 0;
    for (final Map<String, dynamic> row in proofSeed[listingId]!) {
      row['link_sort_order'] = ++order;
    }
    return <String, dynamic>{
      'listing_id': listingId,
      'linked_ids': List<String>.from(portfolioItemIds),
      'count': portfolioItemIds.length,
    };
  }

  @override
  Future<Map<String, dynamic>> unlinkPortfolioItem({
    required String listingId,
    required String portfolioItemId,
  }) async {
    unlinkProofCalls++;
    lastUnlinked = (listingId, portfolioItemId);
    final List<Map<String, dynamic>> existing =
        proofSeed[listingId] ?? <Map<String, dynamic>>[];
    final bool removed = existing.any(
      (Map<String, dynamic> row) => row['id'] == portfolioItemId,
    );
    proofSeed[listingId] = <Map<String, dynamic>>[
      for (final Map<String, dynamic> row in existing)
        if (row['id'] != portfolioItemId) row,
    ];
    return <String, dynamic>{
      'listing_id': listingId,
      'portfolio_item_id': portfolioItemId,
      'removed': removed,
    };
  }

  @override
  Future<Map<String, dynamic>> listPortfolioProofs(String listingId) async {
    listProofCalls++;
    final List<Map<String, dynamic>> items =
        proofSeed[listingId] ?? <Map<String, dynamic>>[];
    return <String, dynamic>{
      'listing_id': listingId,
      'items': items,
      'count': items.length,
    };
  }
}

/// In-memory fake for [ServiceListingRepository] (EP-03-08 widget tests).
class FakeServiceListingRepository implements ServiceListingRepository {
  FakeServiceListingRepository({
    List<MyServiceListing>? seed,
    Map<String, List<LinkedPortfolioItem>>? proofs,
  }) : _rows = <MyServiceListing>[...?seed],
       proofs = proofs ?? <String, List<LinkedPortfolioItem>>{};

  final List<MyServiceListing> _rows;

  int listCalls = 0;
  String? lastStatus;

  /// In-memory linked proof per listing (EP-03-15 widget tests).
  final Map<String, List<LinkedPortfolioItem>> proofs;

  /// When set, proof reads/writes throw this instead (e.g. a `PLT001`
  /// [ApiException] for forbidden-link tests).
  ApiException? proofError;

  int proofLinkCalls = 0;
  int proofUnlinkCalls = 0;
  int proofListCalls = 0;

  /// A linked proof fixture (EP-03-15 tests).
  static LinkedPortfolioItem proof({
    required String id,
    String title = 'Linked proof piece',
    int? linkSortOrder = 1,
  }) => LinkedPortfolioItem(
    item: PortfolioItem(
      id: id,
      itemType: 'image',
      title: title,
      description: 'Proof of completed work.',
      sortOrder: 1,
    ),
    linkSortOrder: linkSortOrder,
  );

  /// When set, [getListing] throws this instead of returning a row (e.g. a
  /// `PLT004` [ApiException] for not-found detail tests).
  ApiException? getListingError;

  static MyServiceListing listing({
    required String id,
    String status = 'draft',
    String title = 'Certified plumbing repair service',
  }) =>
      MyServiceListing(
        id: id,
        entityId: 'entity-1',
        professionId: 'prof-1',
        industryId: 'ind-1',
        slug: 'listing-$id',
        title: title,
        description:
            'Full home plumbing inspection, leak repair, and fixture replacement with a written service report and warranty.',
        status: status,
        pricingType: 'fixed',
        priceMin: 5000,
        currencyCode: 'NGN',
        avgRating: 0,
        reviewCount: 0,
        isTradeVerifiedCache: false,
      );

  @override
  Future<MyServiceListing> createListing({
    required String professionId,
    required String title,
    required String description,
    required String pricingType,
    double? priceMin,
    double? priceMax,
    String currencyCode = 'NGN',
    String status = 'draft',
  }) async {
    final MyServiceListing created = listing(
      id: 'listing-${_rows.length + 1}',
      status: status,
      title: title,
    );
    _rows.insert(0, created);
    return created;
  }

  @override
  Future<MyServiceListing> updateListing({
    required String listingId,
    String? title,
    String? description,
    String? professionId,
    String? pricingType,
    double? priceMin,
    double? priceMax,
    String? currencyCode,
  }) async =>
      getListing(listingId);

  @override
  Future<MyServiceListing> publishListing(String listingId) async {
    final int index = _rows.indexWhere((e) => e.id == listingId);
    final MyServiceListing current = _rows[index];
    final MyServiceListing updated = MyServiceListing(
      id: current.id,
      entityId: current.entityId,
      professionId: current.professionId,
      industryId: current.industryId,
      slug: current.slug,
      title: current.title,
      description: current.description,
      status: 'published',
      pricingType: current.pricingType,
      priceMin: current.priceMin,
      priceMax: current.priceMax,
      currencyCode: current.currencyCode,
      avgRating: current.avgRating,
      reviewCount: current.reviewCount,
      isTradeVerifiedCache: current.isTradeVerifiedCache,
      media: current.media,
    );
    _rows[index] = updated;
    return updated;
  }

  @override
  Future<MyServiceListing> unpublishListing(String listingId) async {
    final int index = _rows.indexWhere((e) => e.id == listingId);
    final MyServiceListing current = _rows[index];
    final MyServiceListing updated = MyServiceListing(
      id: current.id,
      entityId: current.entityId,
      professionId: current.professionId,
      industryId: current.industryId,
      slug: current.slug,
      title: current.title,
      description: current.description,
      status: 'paused',
      pricingType: current.pricingType,
      priceMin: current.priceMin,
      priceMax: current.priceMax,
      currencyCode: current.currencyCode,
      avgRating: current.avgRating,
      reviewCount: current.reviewCount,
      isTradeVerifiedCache: current.isTradeVerifiedCache,
      media: current.media,
    );
    _rows[index] = updated;
    return updated;
  }

  @override
  Future<MyServiceListing> getListing(String listingId) async {
    final ApiException? error = getListingError;
    if (error != null) throw error;
    return _rows.firstWhere((e) => e.id == listingId);
  }

  @override
  Future<MyListingPage> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    listCalls++;
    lastStatus = status;
    final List<MyServiceListing> filtered = status == null
        ? List<MyServiceListing>.from(_rows)
        : _rows.where((e) => e.status == status).toList();
    return MyListingPage(
      items: filtered.take(limit).toList(),
      hasMore: false,
    );
  }

  /// In-memory favorite set for EP-03-09 discovery widget tests.
  final Set<String> favorites = <String>{};

  @override
  Future<bool> toggleFavorite(String listingId) async {
    if (favorites.contains(listingId)) {
      favorites.remove(listingId);
      return false;
    }
    favorites.add(listingId);
    return true;
  }

  List<LinkedPortfolioItem> _proofsOrThrow(String listingId) {
    final ApiException? error = proofError;
    if (error != null) throw error;
    return List<LinkedPortfolioItem>.unmodifiable(
      proofs[listingId] ?? const <LinkedPortfolioItem>[],
    );
  }

  @override
  Future<List<LinkedPortfolioItem>> linkPortfolioItems({
    required String listingId,
    required List<String> portfolioItemIds,
  }) async {
    proofLinkCalls++;
    final ApiException? error = proofError;
    if (error != null) throw error;
    // Full-replace in the submitted order (server semantics): previously
    // linked rows keep their stored fields with refreshed positions, exactly
    // as a post-write re-read would return them.
    final Map<String, LinkedPortfolioItem> existing = <String, LinkedPortfolioItem>{
      for (final LinkedPortfolioItem p
          in proofs[listingId] ?? const <LinkedPortfolioItem>[])
        p.item.id: p,
    };
    int order = 0;
    proofs[listingId] = <LinkedPortfolioItem>[
      for (final String id in portfolioItemIds)
        if (existing[id] != null)
          LinkedPortfolioItem(
            item: existing[id]!.item,
            linkSortOrder: ++order,
          )
        else
          proof(id: id, title: 'Linked proof $id', linkSortOrder: ++order),
    ];
    return _proofsOrThrow(listingId);
  }

  @override
  Future<List<LinkedPortfolioItem>> unlinkPortfolioItem({
    required String listingId,
    required String portfolioItemId,
  }) async {
    proofUnlinkCalls++;
    final ApiException? error = proofError;
    if (error != null) throw error;
    proofs[listingId] = <LinkedPortfolioItem>[
      for (final LinkedPortfolioItem p
          in proofs[listingId] ?? const <LinkedPortfolioItem>[])
        if (p.item.id != portfolioItemId) p,
    ];
    return _proofsOrThrow(listingId);
  }

  @override
  Future<List<LinkedPortfolioItem>> listPortfolioProofs(
    String listingId,
  ) async {
    proofListCalls++;
    return _proofsOrThrow(listingId);
  }
}

/// Ranked-listing fixture for EP-03-09 discovery tests (RPC order is the
/// list order — never re-sorted by consumers).
ServiceListing rankedListing({
  required String id,
  String title = 'Certified plumbing repair service',
  double avgRating = 4.5,
  int reviewCount = 3,
  bool verified = true,
  double? score,
  String professionId = 'prof-1',
  String professionName = 'Plumber',
  String entityId = 'entity-9',
  String pricingType = 'fixed',
  double? priceMin = 5000,
  double? priceMax = 15000,
}) => ServiceListing(
  id: id,
  entityId: entityId,
  professionId: professionId,
  industryId: 'ind-1',
  slug: 'listing-$id',
  title: title,
  description:
      'Full home plumbing inspection, leak repair, and fixture replacement with a written service report and warranty.',
  pricingType: pricingType,
  priceMin: priceMin,
  priceMax: priceMax,
  currencyCode: 'NGN',
  avgRating: avgRating,
  reviewCount: reviewCount,
  isTradeVerifiedCache: verified,
  professionSlug: 'plumber',
  professionName: professionName,
  industrySlug: 'artisans',
  industryName: 'Artisans',
  score: score,
);
