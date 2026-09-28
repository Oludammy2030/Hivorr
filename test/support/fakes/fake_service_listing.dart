import 'package:hivorr/data/datasources/remote/service_listing_remote_data_source.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/models/listing_media_dto.dart';
import 'package:hivorr/data/repositories/service_listing_repository.dart';

/// In-memory fake for [ServiceListingRemoteDataSource] (EP-03-08 tests).
class FakeServiceListingRemoteDataSource
    implements ServiceListingRemoteDataSource {
  FakeServiceListingRemoteDataSource({List<Map<String, dynamic>>? seed})
      : _rows = <Map<String, dynamic>>[...?seed];

  final List<Map<String, dynamic>> _rows;

  int createCalls = 0;
  int updateCalls = 0;
  int publishCalls = 0;
  int unpublishCalls = 0;
  int getCalls = 0;
  int listCalls = 0;
  String? lastStatus;
  String? lastCursor;

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
      <String, dynamic>{'listing_id': listingId, 'is_favorite': true};
}

/// In-memory fake for [ServiceListingRepository] (EP-03-08 widget tests).
class FakeServiceListingRepository implements ServiceListingRepository {
  FakeServiceListingRepository({List<MyServiceListing>? seed})
      : _rows = <MyServiceListing>[...?seed];

  final List<MyServiceListing> _rows;

  int listCalls = 0;
  String? lastStatus;

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
  Future<MyServiceListing> getListing(String listingId) async =>
      _rows.firstWhere((e) => e.id == listingId);

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
}
