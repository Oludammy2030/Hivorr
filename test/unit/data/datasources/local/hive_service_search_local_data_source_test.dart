import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/cache/cache_config.dart';
import 'package:hivorr/core/cache/cache_manager.dart';
import 'package:hivorr/core/database/database.dart';
import 'package:hivorr/data/datasources/local/hive_service_search_local_data_source.dart';
import 'package:hivorr/data/datasources/local/service_search_local_data_source.dart';
import 'package:hivorr/data/models/service_listing_dto.dart';

import '../../../../support/fakes/fake_storage.dart';

void main() {
  group('HiveServiceSearchLocalDataSource', () {
    late FakeStorageEngine engine;
    late LocalStore store;
    late HiveServiceSearchLocalDataSource dataSource;

    setUp(() {
      engine = FakeStorageEngine();
      store = LocalStore(engine);
      dataSource = HiveServiceSearchLocalDataSource(store: store);
    });

    ServiceSearchPageDto page(String id) => ServiceSearchPageDto(
      items: <ServiceListingDto>[
        ServiceListingDto(
          id: id,
          entityId: 'entity-$id',
          professionId: 'prof-1',
          industryId: 'ind-1',
          slug: 'slug-$id',
          title: 'Title $id',
          description: 'Description $id',
          pricingType: 'fixed',
          currencyCode: 'NGN',
          avgRating: 4.5,
          reviewCount: 10,
          isTradeVerifiedCache: true,
        ),
      ],
      hasMore: false,
    );

    group('getPage', () {
      test('returns null when key absent', () async {
        final ServiceSearchPageDto? result = await dataSource.getPage('abc');
        expect(result, isNull);
      });

      test('returns saved page', () async {
        final ServiceSearchPageDto expected = page('test-1');
        await dataSource.savePage('test-1', expected);

        final ServiceSearchPageDto? result = await dataSource.getPage('test-1');
        expect(result, isNotNull);
        expect(result!.items, hasLength(1));
        expect(result.items.first.id, 'test-1');
      });
    });

    group('savePage', () {
      test('persists page to Hive', () async {
        final ServiceSearchPageDto expected = page('save-1');
        await dataSource.savePage('save-1', expected);

        final ServiceSearchPageDto? result = await dataSource.getPage('save-1');
        expect(result, isNotNull);
        expect(result!.items.first.title, 'Title save-1');
      });
    });

    group('getWeightsVersion', () {
      test('returns null when not saved', () async {
        final DateTime? result = await dataSource.getWeightsVersion();
        expect(result, isNull);
      });

      test('returns saved version', () async {
        final DateTime version = DateTime.utc(2026, 9, 26, 12, 0, 0);
        await dataSource.saveWeightsVersion(version);

        final DateTime? result = await dataSource.getWeightsVersion();
        expect(result, equals(version));
      });
    });

    group('saveWeightsVersion', () {
      test('persists version to Hive', () async {
        final DateTime version = DateTime.utc(2026, 9, 26, 14, 30, 0);
        await dataSource.saveWeightsVersion(version);

        final DateTime? result = await dataSource.getWeightsVersion();
        expect(result, equals(version));
      });
    });

    group('invalidate', () {
      test('clears all service_search: prefixed keys', () async {
        await dataSource.savePage('page-1', page('p1'));
        await dataSource.savePage('page-2', page('p2'));
        await dataSource.saveWeightsVersion(DateTime.now());

        await dataSource.invalidate();

        expect(await dataSource.getPage('page-1'), isNull);
        expect(await dataSource.getPage('page-2'), isNull);
        expect(await dataSource.getWeightsVersion(), isNull);
      });

      test('does not clear unrelated keys', () async {
        // Save unrelated data in same box.
        await store.write<Map<String, dynamic>>(
          'cache',
          'taxonomy:industries',
          <String, dynamic>{'data': 'test'},
          (Map<String, dynamic> v) => v,
        );

        await dataSource.savePage('page-1', page('p1'));
        await dataSource.invalidate();

        // Unrelated key should remain.
        final Map<String, dynamic>? unrelated = await store.read<Map<String, dynamic>>(
          'cache',
          'taxonomy:industries',
          (Map<String, dynamic> json) => json,
        );
        expect(unrelated, isNotNull);
      });
    });

    group('CacheManager second-tier', () {
      setUp(() async {
        CacheManager.dispose();
        await CacheManager.initialize(
          CacheConfig(
            maxEntries: 100,
            defaultTtl: const Duration(minutes: 5),
          ),
        );
      });

      tearDown(() => CacheManager.dispose());

      test('getPage promotes Hive hit to CacheManager', () async {
        final CacheManager cache = CacheManager.instance;
        dataSource = HiveServiceSearchLocalDataSource(
          store: store,
          cache: cache,
        );

        final ServiceSearchPageDto expected = page('promoted');
        await dataSource.savePage('promoted', expected);

        // Clear CacheManager to force Hive read.
        cache.clear();

        final ServiceSearchPageDto? result = await dataSource.getPage('promoted');
        expect(result, isNotNull);
        expect(result!.items.first.id, 'promoted');

        // Second read should hit CacheManager (promoted).
        final ServiceSearchPageDto? cached = cache.get<ServiceSearchPageDto>(
          '${serviceSearchCachePrefix}promoted',
        );
        expect(cached, isNotNull);
      });

      test('savePage writes to both tiers', () async {
        final CacheManager cache = CacheManager.instance;
        dataSource = HiveServiceSearchLocalDataSource(
          store: store,
          cache: cache,
        );

        final ServiceSearchPageDto expected = page('dual');
        await dataSource.savePage('dual', expected);

        // Both tiers should have it.
        final ServiceSearchPageDto? fromCache = cache.get<ServiceSearchPageDto>(
          '${serviceSearchCachePrefix}dual',
        );
        expect(fromCache, isNotNull);

        final ServiceSearchPageDto? fromHive = await dataSource.getPage('dual');
        expect(fromHive, isNotNull);
      });

      test('invalidate clears both tiers', () async {
        final CacheManager cache = CacheManager.instance;
        dataSource = HiveServiceSearchLocalDataSource(
          store: store,
          cache: cache,
        );

        await dataSource.savePage('page-1', page('p1'));
        await dataSource.saveWeightsVersion(DateTime.now());

        await dataSource.invalidate();

        expect(cache.get<ServiceSearchPageDto>('${serviceSearchCachePrefix}page-1'), isNull);
        expect(await dataSource.getPage('page-1'), isNull);
        expect(await dataSource.getWeightsVersion(), isNull);
      });
    });

    group('fallback (no LocalStore)', () {
      test('uses in-memory Map when store is null', () async {
        dataSource = HiveServiceSearchLocalDataSource(store: null);

        final ServiceSearchPageDto expected = page('fallback');
        await dataSource.savePage('fallback', expected);

        final ServiceSearchPageDto? result = await dataSource.getPage('fallback');
        expect(result, isNotNull);
        expect(result!.items.first.id, 'fallback');
      });

      test('invalidate clears fallback', () async {
        dataSource = HiveServiceSearchLocalDataSource(store: null);

        await dataSource.savePage('fb-1', page('f1'));
        await dataSource.saveWeightsVersion(DateTime.now());

        await dataSource.invalidate();

        expect(await dataSource.getPage('fb-1'), isNull);
        expect(await dataSource.getWeightsVersion(), isNull);
      });
    });
  });
}
