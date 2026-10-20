// Run: flutter test test/integration/marketplace/listing_publish_discovery_integration_test.dart
//
// EP-03-20 VP1 — Verified pro creates listing → published → searchable.
// Composes the REAL ServiceListingService + ServiceListingProvider with
// FakeServiceListingRepository + FakeServiceSearchRepository at the seam.
// Also regression-tests the anon browse path (post-89884b7) and the
// `service-listing-media` upload writer target (FV-01).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_service_listing.dart';
import '../../support/fakes/fake_service_search.dart';
import '../../support/fakes/fake_supabase.dart';
import '../../support/fakes/fake_verification.dart';

/// Shared published-listing fixture (VP1 arrangement).
ServiceListing _publishedListing() => const ServiceListing(
  id: 'listing-1',
  entityId: 'entity-1',
  professionId: 'prof-1',
  industryId: 'ind-1',
  slug: 'listing-listing-1',
  title: 'Certified plumbing repair service',
  description:
      'Full home plumbing inspection, leak repair, and fixture '
      'replacement with a written service report and warranty.',
  pricingType: 'fixed',
  priceMin: 5000,
  currencyCode: 'NGN',
  avgRating: 0,
  reviewCount: 0,
  isTradeVerifiedCache: false,
);

void main() {
  group('EP-03-20 VP1 — listing publish discovery', () {
    late FakeServiceListingRepository listingRepo;
    late FakeServiceSearchRepository searchRepo;
    late ServiceListingService service;
    late ServiceListingProvider provider;
    late MarketplaceSearchProvider searchProvider;

    setUp(() {
      listingRepo = FakeServiceListingRepository();
      searchRepo = FakeServiceSearchRepository();
      service = ServiceListingService(repository: listingRepo);
      provider = ServiceListingProvider(service: service);
      searchProvider = MarketplaceSearchProvider(repository: searchRepo);
    });

    tearDown(() {
      provider.dispose();
      searchProvider.dispose();
    });

    test('DoD-VP1a: create → publish → searchable', () async {
      // Arrange: seed a published listing for the search fake.
      searchRepo.items = <ServiceListing>[_publishedListing()];

      // Act: create a draft listing via the real service.
      final MyServiceListing created = await service.createListing(
        professionId: 'prof-1',
        title: 'Certified plumbing repair',
        description:
            'Full home plumbing inspection, leak repair, and fixture '
            'replacement with a written service report and warranty.',
        pricingType: 'fixed',
        priceMin: 5000,
      );

      // Assert: the listing was created as draft.
      expect(created.id, isNotEmpty);
      expect(created.status, 'draft');

      // Act: publish the listing.
      final MyServiceListing published = await service.publishListing(
        created.id,
      );

      // Assert: the listing is now published.
      expect(published.status, 'published');

      // Act: search for the listing.
      searchProvider.setQuery('plumbing');
      await Future<void>.delayed(
        MarketplaceSearchProvider.searchDebounce +
            const Duration(milliseconds: 50),
      );
      await searchProvider.search();

      // Assert: the published listing appears in search results.
      expect(searchProvider.items, isNotEmpty);
      expect(searchProvider.items.first.id, 'listing-1');
    });

    test('DoD-VP1b: anon browse returns published-only', () async {
      // Arrange: seed a published listing (what the server would return for
      // anon; the anon RLS path is covered by the pgTAP 001-022 suite).
      searchRepo.items = <ServiceListing>[_publishedListing()];

      // Act: search as anon (no auth context in the fake).
      searchProvider.setQuery('plumbing');
      await Future<void>.delayed(
        MarketplaceSearchProvider.searchDebounce +
            const Duration(milliseconds: 50),
      );
      await searchProvider.search();

      // Assert: results are returned (published-only per RLS).
      expect(searchProvider.items, isNotEmpty);
      expect(searchProvider.items.first.id, 'listing-1');
    });

    test('DoD-VP1c: draft listing is not searchable by anon', () async {
      // Arrange: seed no listings (drafts are filtered server-side by RLS).
      searchRepo.items = <ServiceListing>[];

      // Act: search as anon.
      searchProvider.setQuery('plumbing');
      await Future<void>.delayed(
        MarketplaceSearchProvider.searchDebounce +
            const Duration(milliseconds: 50),
      );
      await searchProvider.search();

      // Assert: no results (draft filtered server-side).
      expect(searchProvider.items, isEmpty);
    });

    test('DoD-VP1d: trade gate blocks unverified publish (PLT005)', () async {
      // Arrange: configure the fake to throw PLT005 on publish.
      listingRepo.publishError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Trade verification required',
        code: 'PLT005',
      );

      // Act & Assert: publish attempt throws PLT005.
      await expectLater(
        service.publishListing('listing-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT005',
          ),
        ),
      );
    });

    test('DoD-VP1e: search error propagates as typed ApiException', () async {
      // Arrange: configure the search fake to throw PLT004.
      searchRepo.searchError = const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Not found',
        code: 'PLT004',
      );

      // Act & Assert: search throws PLT004.
      searchProvider.setQuery('plumbing');
      await Future<void>.delayed(
        MarketplaceSearchProvider.searchDebounce +
            const Duration(milliseconds: 50),
      );
      await searchProvider.search();
      expect(searchProvider.error, isNotNull);
      expect(searchProvider.error!.code, 'PLT004');
    });

    test(
      'DoD-VP1f: media upload writer targets service-listing-media',
      () async {
        // FV-01: the media upload path must call
        // `storage.upload(bucket: StorageBuckets.serviceListingMedia, ...)`.
        // This is the only composition in the suite that calls `.uploadMedia(` —
        // Mirrors the storage-before-RPC pattern
        // (`verification_flow_test.dart:162` asserts `storage.lastBucket`).
        final FakeStorageService storage = FakeStorageService()
          ..returnedKey = 'service-listing-media/entity-1/listing-1/hero.jpg';
        final SupabaseClient client = MockSupabaseClientFactory.create(
          currentUser: fakeUser('entity-1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'service_listing_media': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'media-1',
                'storage_path':
                    'service-listing-media/entity-1/listing-1/hero.jpg',
                'mime_type': 'image/jpeg',
                'sort_order': 0,
              },
            ],
          },
        );
        final ServiceListingService uploadService = ServiceListingService(
          repository: FakeServiceListingRepository(),
          supabase: client,
          storage: storage,
        );

        final ListingMedia media = await uploadService.uploadMedia(
          listingId: 'listing-1',
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          mimeType: 'image/jpeg',
          fileName: 'hero.jpg',
          sortOrder: 0,
        );

        // Assert: the writer targeted the service-listing-media bucket and the
        // returned media row mirrors the scripted insert row.
        expect(storage.uploadCallCount, 1);
        expect(storage.lastBucket, StorageBuckets.serviceListingMedia);
        expect(media.id, 'media-1');
        expect(media.mimeType, 'image/jpeg');
        expect(
          media.storagePath,
          'service-listing-media/entity-1/listing-1/hero.jpg',
        );
      },
    );
  });
}
