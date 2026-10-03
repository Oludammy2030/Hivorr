// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_paths.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/repositories/service_listing_repository.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin facade over [ServiceListingRepository] consumed by
/// [ServiceListingProvider] and the marketplace screens (EP-03-08 §8 D6).
///
/// Exposes the pricing/currency/status vocabularies (compile-time const,
/// mirroring the frozen CHECK constraints) plus the fail-fast validators
/// [validateTitle]/[validateDescription]/[validatePricing]/[validateCurrency],
/// and delegates data operations to the repository. Adds PII-safe structured
/// [HivorrLogger] output (listing id suffix, status deltas — never title,
/// description, or media paths in full) and `marketplace.listing.*`
/// [PerformanceTracer] spans.
///
/// Media orchestration follows the storage-before-RPC pattern (copied from
/// `VerificationRepositoryImpl`): `validate → upload(service-listing-media)
/// → insert service_listing_media row → RPC`. Orphan bytes are removed when a
/// later step fails.
class ServiceListingService {
  ServiceListingService({
    required ServiceListingRepository repository,
    SupabaseClient? supabase,
    StorageService? storage,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  })  : _repository = repository,
        _supabase = supabase,
        _storage = storage,
        _logger = logger,
        _tracer = tracer,
        _redactor = redactor ?? PiiRedactor();

  final ServiceListingRepository _repository;

  /// Supabase client for media row CRUD. Nullable so list/form widget tests
  /// can run without a networked auth client; [uploadMedia]/[deleteMedia]
  /// fail closed with `PLT999`/`PLT001` when absent.
  final SupabaseClient? _supabase;
  final StorageService? _storage;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  // ─── Vocabulary (matches frozen CHECK constraints) ────────────────────

  /// Pricing vocabulary (`service_listings_pricing_type_allowed`).
  static const List<String> pricingTypes = <String>[
    'fixed',
    'hourly',
    'custom',
    'per_milestone',
  ];

  /// Active currency subset (`financial_supported_currencies`).
  static const List<String> currencies = <String>[
    'NGN',
    'GHS',
    'USD',
    'GBP',
  ];

  /// Owner status vocabulary (client writes only `draft→published→paused`).
  static const List<String> statuses = <String>[
    'draft',
    'published',
    'paused',
    'archived',
    'reported',
  ];

  // ─── Fail-fast validators (mirror CHECKs; server stays authoritative) ──

  /// `true` when [title] is 10–120 chars after trim.
  static bool validateTitle(String title) {
    final int length = title.trim().length;
    return length >= 10 && length <= 120;
  }

  /// `true` when [description] is 50–5000 chars after trim.
  static bool validateDescription(String description) {
    final int length = description.trim().length;
    return length >= 50 && length <= 5000;
  }

  /// `true` when [pricingType] is in the frozen vocabulary.
  static bool validatePricingType(String pricingType) =>
      pricingTypes.contains(pricingType);

  /// `true` when the price combination satisfies the CHECK rules.
  static bool validatePrices({
    required String pricingType,
    required double? priceMin,
    required double? priceMax,
  }) {
    if (priceMin != null && priceMin < 0) return false;
    if (priceMax != null && priceMin == null) return false;
    if (priceMax != null && priceMin != null && priceMax < priceMin) {
      return false;
    }
    if (pricingType != 'custom' && priceMin == null) return false;
    return true;
  }

  /// `true` when [currencyCode] is in the active subset.
  static bool validateCurrency(String currencyCode) =>
      currencies.contains(currencyCode);

  // ─── Data operations (delegate to repository, traced + logged) ─────────

  Future<MyListingPage> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) =>
      _tracedAndLogged('marketplace.listing.list', () async {
        final page = await _repository.listMine(
          status: status,
          limit: limit,
          cursor: cursor,
        );
        _logger?.info('Listing list fetched', <String, Object?>{
          'statusFilter': status,
          'listingCount': page.items.length,
          'hasMore': page.hasMore,
        });
        return page;
      });

  Future<MyServiceListing> getListing(String listingId) =>
      _tracedAndLogged('marketplace.listing.get', () async {
        final listing = await _repository.getListing(listingId);
        _logger?.info('Listing detail fetched', <String, Object?>{
          'listingId': _redactor.redact(listing.id),
          'status': listing.status,
          'mediaCount': listing.media.length,
        });
        return listing;
      });

  /// Toggles the caller's favorite for a `published` listing
  /// (`service_favorite_toggle` read-through for detail preview only).
  ///
  /// Returns the post-toggle state (`true` when favorited). Self-favorite and
  /// non-`published` targets surface `PLT005`; unknown listings `PLT004`.
  Future<bool> toggleFavorite(String listingId) =>
      _tracedAndLogged('marketplace.listing.favorite', () async {
        final bool favorited = await _repository.toggleFavorite(listingId);
        _logger?.info('Listing favorite toggled', <String, Object?>{
          'listingId': _redactor.redact(listingId),
          'favorited': favorited,
        });
        return favorited;
      });

  Future<MyServiceListing> createListing({
    required String professionId,
    required String title,
    required String description,
    required String pricingType,
    double? priceMin,
    double? priceMax,
    String currencyCode = 'NGN',
    String status = 'draft',
  }) =>
      _tracedAndLogged('marketplace.listing.create', () async {
        _logger?.info('Creating listing', <String, Object?>{
          'pricingType': pricingType,
          'currencyCode': currencyCode,
          'status': status,
        });
        final listing = await _repository.createListing(
          professionId: professionId,
          title: title,
          description: description,
          pricingType: pricingType,
          priceMin: priceMin,
          priceMax: priceMax,
          currencyCode: currencyCode,
          status: status,
        );
        _logger?.info('Listing created', <String, Object?>{
          'listingId': _redactor.redact(listing.id),
          'status': listing.status,
        });
        return listing;
      });

  Future<MyServiceListing> updateListing({
    required String listingId,
    String? title,
    String? description,
    String? professionId,
    String? pricingType,
    double? priceMin,
    double? priceMax,
    String? currencyCode,
  }) =>
      _tracedAndLogged('marketplace.listing.update', () async {
        final listing = await _repository.updateListing(
          listingId: listingId,
          title: title,
          description: description,
          professionId: professionId,
          pricingType: pricingType,
          priceMin: priceMin,
          priceMax: priceMax,
          currencyCode: currencyCode,
        );
        _logger?.info('Listing updated', <String, Object?>{
          'listingId': _redactor.redact(listing.id),
          'status': listing.status,
        });
        return listing;
      });

  Future<MyServiceListing> publishListing(String listingId) =>
      _tracedAndLogged('marketplace.listing.publish', () async {
        final listing = await _repository.publishListing(listingId);
        _logger?.info('Listing published', <String, Object?>{
          'listingId': _redactor.redact(listing.id),
          'status': listing.status,
        });
        return listing;
      });

  Future<MyServiceListing> unpublishListing(String listingId) =>
      _tracedAndLogged('marketplace.listing.unpublish', () async {
        final listing = await _repository.unpublishListing(listingId);
        _logger?.info('Listing unpublished', <String, Object?>{
          'listingId': _redactor.redact(listing.id),
          'status': listing.status,
        });
        return listing;
      });

  /// Uploads media bytes to `service-listing-media` then inserts the
  /// `service_listing_media` row (storage-before-RPC).
  ///
  /// Returns the inserted media row. Removes the uploaded bytes when the row
  /// insert fails so no orphan objects accumulate.
  Future<ListingMedia> uploadMedia({
    required String listingId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    required int sortOrder,
    void Function(int sent, int total)? onProgress,
  }) async {
    final StorageService? storage = _storage;
    final SupabaseClient? supabase = _supabase;
    if (storage == null || supabase == null) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        message: 'Media upload is unavailable.',
        code: 'PLT999',
      );
    }
    final String? entityId = supabase.auth.currentUser?.id;
    if (entityId == null || entityId.isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.auth,
        message: 'Authentication required.',
        code: 'PLT001',
      );
    }
    storage.validateForBucket(
      bucket: StorageBuckets.serviceListingMedia,
      mimeType: mimeType,
      byteLength: bytes.lengthInBytes,
    );
    final String storagePath = StoragePaths.listingMedia(
      entityId: entityId,
      listingId: listingId,
      fileName: fileName,
    );
    final String storageKey = await storage.upload(
      bucket: StorageBuckets.serviceListingMedia,
      path: storagePath,
      bytes: bytes,
      mimeType: mimeType,
      fileName: fileName,
      onProgress: onProgress,
    );
    try {
      final List<Map<String, dynamic>> rows = await supabase
          .from('service_listing_media')
          .insert(<String, dynamic>{
        'listing_id': listingId,
        'entity_id': entityId,
        'storage_path': storageKey,
        'mime_type': mimeType,
        'sort_order': sortOrder,
      }).select().limit(1);
      if (rows.isEmpty) {
        throw const ApiException(
          kind: ApiExceptionKind.server,
          message: 'Media row could not be created.',
          code: 'PLT999',
        );
      }
      final Map<String, dynamic> row = rows.first;
      return ListingMedia(
        id: row['id'] as String,
        storagePath: row['storage_path'] as String,
        mimeType: row['mime_type'] as String,
        sortOrder: (row['sort_order'] as num).toInt(),
        createdAt: row['created_at'] is String
            ? DateTime.tryParse(row['created_at'] as String)
            : null,
      );
    } catch (_) {
      try {
        await storage.remove(
          bucket: StorageBuckets.serviceListingMedia,
          paths: <String>[storageKey],
        );
      } on Object {
        // Best-effort orphan cleanup; the original error propagates.
      }
      rethrow;
    }
  }

  /// Deletes a media row then its bytes (row-first so RLS owns the gate).
  Future<void> deleteMedia({
    required String mediaId,
    required String storagePath,
  }) async {
    final SupabaseClient? supabase = _supabase;
    if (supabase == null) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        message: 'Media delete is unavailable.',
        code: 'PLT999',
      );
    }
    await supabase
        .from('service_listing_media')
        .delete()
        .eq('id', mediaId);
    final StorageService? storage = _storage;
    if (storage == null) return;
    try {
      await storage.remove(
        bucket: StorageBuckets.serviceListingMedia,
        paths: <String>[storagePath],
      );
    } on Object {
      // Row is already gone (authoritative); byte cleanup is best-effort.
    }
  }

  /// Resolves a public URL for a listing media path, or `null` when storage
  /// is unavailable (callers render a type placeholder instead).
  String? mediaPublicUrl(String storagePath) {
    final StorageService? storage = _storage;
    if (storage == null) return null;
    try {
      return storage.getPublicUrl(
        bucket: StorageBuckets.serviceListingMedia,
        path: storagePath,
      );
    } on Object {
      return null;
    }
  }

  /// Wraps [action] in a `marketplace.listing.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'marketplace');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'span': name},
      );
      rethrow;
    }
  }
}
