// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/service_listing_remote_data_source.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/mappers/service_listing_mapper.dart';
import 'package:hivorr/data/repositories/service_listing_repository.dart';

/// Default implementation of [ServiceListingRepository].
///
/// Implements the server-authoritative owner flow (EP-03-08 §7): writes via
/// the client-callable RPCs with client-side fail-fast mirrors of the frozen
/// CHECK constraints (title 10–120, description 50–5000, pricing vocab, price
/// rules, currency vocab, status vocab), then re-reads the authoritative row
/// via `service_listing_get`. The server remains the single authority; the
/// repository mirrors the codes for fail-fast UX only. Never writes
/// `service_listings` tables directly and never references `reported`.
class ServiceListingRepositoryImpl implements ServiceListingRepository {
  ServiceListingRepositoryImpl({required ServiceListingRemoteDataSource remote})
      : _remote = remote;

  final ServiceListingRemoteDataSource _remote;

  /// Pricing vocabulary (`service_listings_pricing_type_allowed`).
  static const Set<String> pricingTypes = <String>{
    'fixed',
    'hourly',
    'custom',
    'per_milestone',
  };

  /// Active currency subset (`financial_supported_currencies` active rows).
  static const Set<String> currencies = <String>{
    'NGN',
    'GHS',
    'USD',
    'GBP',
  };

  /// Owner list status filter vocabulary (client may only filter; `reported`
  /// is readable but never written by the client).
  static const Set<String> statuses = <String>{
    'draft',
    'published',
    'paused',
    'archived',
    'reported',
  };

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
    _requireNonEmpty(professionId, 'professionId');
    _requireLength(title, min: 10, max: 120, field: 'title');
    _requireLength(description, min: 50, max: 5000, field: 'description');
    _requireInVocabulary(pricingType, pricingTypes, 'pricingType');
    _requireInVocabulary(currencyCode, currencies, 'currencyCode');
    if (status != 'draft' && status != 'published') {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid initial status.',
        code: 'PLT003',
      );
    }
    _requirePrices(
      pricingType: pricingType,
      priceMin: priceMin,
      priceMax: priceMax,
    );
    final Map<String, dynamic> created = await _remote.createListing(
      professionId: professionId,
      title: title.trim(),
      description: description.trim(),
      pricingType: pricingType,
      priceMin: priceMin,
      priceMax: priceMax,
      currencyCode: currencyCode,
      status: status,
    );
    // The create response is the authoritative row (server holds
    // slug/industry/status/verification). It omits `media[]`, which the
    // mapper defaults to empty.
    return ServiceListingMapper.toOwnerEntity(created);
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
  }) async {
    _requireNonEmpty(listingId, 'listingId');
    if (title != null) {
      _requireLength(title, min: 10, max: 120, field: 'title');
    }
    if (description != null) {
      _requireLength(description, min: 50, max: 5000, field: 'description');
    }
    if (pricingType != null) {
      _requireInVocabulary(pricingType, pricingTypes, 'pricingType');
    }
    if (currencyCode != null) {
      _requireInVocabulary(currencyCode, currencies, 'currencyCode');
    }
    if (priceMin != null && priceMin < 0) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Minimum price must be zero or greater.',
        code: 'PLT003',
      );
    }
    if (priceMax != null && priceMin != null && priceMax < priceMin) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Maximum price must be greater than or equal to the minimum.',
        code: 'PLT003',
      );
    }
    await _remote.updateListing(
      listingId: listingId,
      title: title?.trim(),
      description: description?.trim(),
      professionId: professionId,
      pricingType: pricingType,
      priceMin: priceMin,
      priceMax: priceMax,
      currencyCode: currencyCode,
    );
    final Map<String, dynamic> row = await _remote.getListing(listingId);
    return ServiceListingMapper.toOwnerEntity(row);
  }

  @override
  Future<MyServiceListing> publishListing(String listingId) async {
    _requireNonEmpty(listingId, 'listingId');
    await _remote.publishListing(listingId);
    final Map<String, dynamic> row = await _remote.getListing(listingId);
    return ServiceListingMapper.toOwnerEntity(row);
  }

  @override
  Future<MyServiceListing> unpublishListing(String listingId) async {
    _requireNonEmpty(listingId, 'listingId');
    await _remote.unpublishListing(listingId);
    final Map<String, dynamic> row = await _remote.getListing(listingId);
    return ServiceListingMapper.toOwnerEntity(row);
  }

  @override
  Future<MyServiceListing> getListing(String listingId) async {
    _requireNonEmpty(listingId, 'listingId');
    final Map<String, dynamic> row = await _remote.getListing(listingId);
    return ServiceListingMapper.toOwnerEntity(row);
  }

  @override
  Future<MyListingPage> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    if (status != null) {
      _requireInVocabulary(status, statuses, 'status');
    }
    if (limit < 1 || limit > 100) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Limit must be between 1 and 100.',
        code: 'PLT003',
      );
    }
    final dto = await _remote.listMine(
      status: status,
      limit: limit,
      cursor: cursor,
    );
    return ServiceListingMapper.toOwnerPage(
      items: dto.items,
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  void _requirePrices({
    required String pricingType,
    required double? priceMin,
    required double? priceMax,
  }) {
    if (priceMin != null && priceMin < 0) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Minimum price must be zero or greater.',
        code: 'PLT003',
      );
    }
    if (priceMax != null && priceMin == null) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Minimum price is required when a maximum is provided.',
        code: 'PLT003',
      );
    }
    if (priceMax != null && priceMin != null && priceMax < priceMin) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Maximum price must be greater than or equal to the minimum.',
        code: 'PLT003',
      );
    }
    if (pricingType != 'custom' && priceMin == null) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Minimum price is required for this pricing type.',
        code: 'PLT003',
      );
    }
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: '$field is required.',
        code: 'PLT003',
      );
    }
  }

  static void _requireInVocabulary(
    String value,
    Set<String> vocabulary,
    String field,
  ) {
    if (!vocabulary.contains(value)) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid $field value: $value.',
        code: 'PLT003',
      );
    }
  }

  static void _requireLength(
    String value, {
    required int min,
    required int max,
    required String field,
  }) {
    final int length = value.trim().length;
    if (length < min || length > max) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: '$field must be between $min and $max characters.',
        code: 'PLT003',
      );
    }
  }
}
