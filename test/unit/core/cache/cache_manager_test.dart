import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/cache/cache_config.dart';
import 'package:hivorr/core/cache/cache_manager.dart';

CacheConfig _config({int maxEntries = 100, int ttlSeconds = 300}) =>
    CacheConfig(
      maxEntries: maxEntries,
      defaultTtl: Duration(seconds: ttlSeconds),
    );

void main() {
  group('CacheManager — basic get/put', () {
    setUp(() async {
      CacheManager.dispose();
      await CacheManager.initialize(_config());
    });

    tearDown(() => CacheManager.dispose());

    test('put then get returns the value', () {
      final mgr = CacheManager.instance;
      mgr.put('user:1', 'Alice');
      expect(mgr.get<String>('user:1'), 'Alice');
    });

    test('get on missing key is a miss returning null', () {
      final mgr = CacheManager.instance;
      expect(mgr.get<String>('nope'), isNull);
      expect(mgr.stats.misses, 1);
      expect(mgr.stats.hits, 0);
    });

    test('stats reflect hits and misses', () {
      final mgr = CacheManager.instance;
      mgr.put('k', 'v');
      mgr.get<String>('k');
      mgr.get<String>('k');
      mgr.get<String>('missing');
      expect(mgr.stats.hits, 2);
      expect(mgr.stats.misses, 1);
    });
  });

  group('CacheManager — TTL expiry', () {
    setUp(() async {
      CacheManager.dispose();
      await CacheManager.initialize(_config(ttlSeconds: 300));
    });

    tearDown(() => CacheManager.dispose());

    test('entry is a miss after its TTL elapses', () async {
      final mgr = CacheManager.instance;
      mgr.put('ephemeral', 'data', ttl: const Duration(milliseconds: 1));
      expect(mgr.get<String>('ephemeral'), 'data');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mgr.get<String>('ephemeral'), isNull);
    });

    test('default TTL applies when none supplied', () async {
      final mgr = CacheManager.instance;
      mgr.put('d', 'x'); // default 300s
      expect(mgr.get<String>('d'), 'x');
    });
  });

  group('CacheManager — LRU eviction', () {
    setUp(() async {
      CacheManager.dispose();
      await CacheManager.initialize(_config(maxEntries: 2, ttlSeconds: 300));
    });

    tearDown(() => CacheManager.dispose());

    test('evicts least-recently-used entry when over capacity', () {
      final mgr = CacheManager.instance;
      mgr.put('a', '1');
      mgr.put('b', '2');
      // Access 'a' so it becomes most-recently-used; 'b' is now LRU.
      expect(mgr.get<String>('a'), '1');
      // Insert 'c' → over capacity → evict 'b'.
      mgr.put('c', '3');
      expect(mgr.get<String>('a'), '1');
      expect(mgr.get<String>('c'), '3');
      expect(mgr.get<String>('b'), isNull);
      expect(mgr.stats.evictions, 1);
    });
  });

  group('CacheManager — invalidation & clear', () {
    setUp(() async {
      CacheManager.dispose();
      await CacheManager.initialize(_config());
    });

    tearDown(() => CacheManager.dispose());

    test('invalidatePrefix clears only matching keys', () {
      final mgr = CacheManager.instance;
      mgr.put('entity:1', 'a');
      mgr.put('entity:2', 'b');
      mgr.put('profile:1', 'c');
      mgr.invalidatePrefix('entity:');
      expect(mgr.get<String>('entity:1'), isNull);
      expect(mgr.get<String>('entity:2'), isNull);
      expect(mgr.get<String>('profile:1'), 'c');
    });

    test('clear removes everything', () {
      final mgr = CacheManager.instance;
      mgr.put('x', '1');
      mgr.put('y', '2');
      mgr.clear();
      expect(mgr.get<String>('x'), isNull);
      expect(mgr.get<String>('y'), isNull);
      expect(mgr.stats.size, 0);
    });

    test('invalidatePrefix with no matches is a no-op', () {
      final mgr = CacheManager.instance;
      mgr.put('entity:1', 'a');
      mgr.put('profile:1', 'c');
      mgr.invalidatePrefix('missing:');
      expect(mgr.get<String>('entity:1'), 'a');
      expect(mgr.get<String>('profile:1'), 'c');
      expect(mgr.stats.size, 2);
    });
  });

  group('CacheManager — concurrency', () {
    setUp(() async {
      CacheManager.dispose();
      await CacheManager.initialize(_config(maxEntries: 500, ttlSeconds: 300));
    });

    tearDown(() => CacheManager.dispose());

    test('concurrent put/get stays consistent (no corruption)', () async {
      final mgr = CacheManager.instance;
      final List<Future<void>> tasks = <Future<void>>[];
      // Concurrent writes to distinct keys, interleaved with reads that must
      // never observe a corrupted value (only null or the exact int).
      for (int i = 0; i < 200; i++) {
        tasks.add(Future<void>(() async {
          mgr.put('k$i', i);
        }));
        tasks.add(Future<void>(() async {
          final int? observed = mgr.get<int>('k$i');
          expect(observed == null || observed == i, isTrue);
        }));
      }
      await Future.wait(tasks);
      // After all writes settle, every key reads back its exact value.
      for (int i = 0; i < 200; i++) {
        expect(mgr.get<int>('k$i'), i);
      }
    });
  });
}
