import 'package:hivorr/core/cache/cache_config.dart';
import 'package:hivorr/core/cache/lru_cache.dart';

/// Process-wide in-memory cache manager with LRU eviction, TTL expiry, prefix
/// invalidation, and hit/miss/eviction stats.
///
/// Transient by design: entries live only for the process lifetime and are
/// never persisted. This satisfies the "transient memory cache" mandate and
/// avoids PII-at-rest concerns (plan §5.4, §12).
class CacheManager {
  CacheManager._(this._cache);

  final LruCache<dynamic> _cache;

  static CacheManager? _instance;

  /// The singleton instance, or throws if [initialize] was not called.
  static CacheManager get instance {
    final CacheManager? i = _instance;
    if (i == null) {
      throw StateError('CacheManager not initialized. Call initializeCache().');
    }
    return i;
  }

  /// Whether the manager has been initialized.
  static bool get isInitialized => _instance != null;

  // ─── Stats ────────────────────────────────────────────────────────────

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// Snapshot of cache statistics.
  CacheStats get stats =>
      CacheStats(size: _cache.length, hits: _hits, misses: _misses, evictions: _evictions);

  /// Initializes the cache manager for [config]. Idempotent.
  static Future<CacheManager> initialize(CacheConfig config) async {
    final CacheManager? existing = _instance;
    if (existing != null) {
      return existing;
    }
    final LruCache<dynamic> cache = LruCache<dynamic>(
      maxEntries: config.maxEntries,
      defaultTtl: config.defaultTtl,
    );
    _instance = CacheManager._(cache);
    return _instance!;
  }

  /// Returns the cached value for [key], or `null` on miss/expiry.
  T? get<T>(String key) {
    final T? value = _cache.get(key) as T?;
    if (value == null) {
      _misses++;
      return null;
    }
    _hits++;
    return value;
  }

  /// Stores [value] at [key] with optional [ttl] (defaults to config TTL).
  void put<T>(String key, T value, {Duration? ttl}) {
    _evictions += _cache.put(key, value, ttl: ttl);
  }

  /// Removes [key].
  void remove(String key) => _cache.remove(key);

  /// Clears all entries and resets stats.
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  /// Removes every key whose name starts with [prefix].
  ///
  /// For example, `invalidatePrefix('entity:')` clears only entity-scoped
  /// entries, leaving other prefixes intact (plan §5.4).
  void invalidatePrefix(String prefix) {
    final List<String> toRemove =
        _cache.keys.where((String k) => k.startsWith(prefix)).toList();
    for (final String key in toRemove) {
      _cache.remove(key);
    }
  }

  /// Resets the singleton (test helper / re-init boundary).
  static void dispose() {
    _instance?._resetStats();
    _instance = null;
  }

  void _resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }
}

/// Immutable cache statistics snapshot.
class CacheStats {
  const CacheStats({
    required this.size,
    required this.hits,
    required this.misses,
    required this.evictions,
  });

  /// Current number of live entries.
  final int size;

  /// Successful lookups.
  final int hits;

  /// Failed lookups (miss/expiry/absent).
  final int misses;

  /// Entries evicted due to capacity pressure.
  final int evictions;

  /// Hit ratio in [0, 1]; `0` when there are no lookups yet.
  double get hitRatio {
    final int total = hits + misses;
    return total == 0 ? 0.0 : hits / total;
  }

  @override
  String toString() {
    return 'CacheStats(size: $size, hits: $hits, misses: $misses, '
        'evictions: $evictions, hitRatio: ${hitRatio.toStringAsFixed(2)})';
  }
}
