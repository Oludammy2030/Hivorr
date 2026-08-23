import 'package:hivorr/core/cache/cache_entry.dart';

/// Bounded, TTL-aware least-recently-used (LRU) in-memory cache.
///
/// Pure Dart, no I/O. Get/put are O(1) amortized using a [Map] for lookup and
/// a [LinkedHashMap]-style insertion order for eviction. Entries are moved to
/// the most-recently-used position on access so the oldest-accessed entry is
/// always first and is evicted first when over [maxEntries].
///
/// Expiry is evaluated lazily on [get]: an expired entry is treated as a miss
/// and evicted on access. This keeps the hot path allocation-light.
class LruCache<T> {
  LruCache({required this.maxEntries, required this.defaultTtl})
      : _store = <String, CacheEntry<T>>{};

  /// Maximum number of entries before eviction.
  final int maxEntries;

  /// Default TTL applied when [put] does not supply one.
  final Duration defaultTtl;

  final Map<String, CacheEntry<T>> _store;

  /// Whether [key] currently holds a live (non-expired) entry.
  bool containsKey(String key) {
    final CacheEntry<T>? entry = _store[key];
    if (entry == null) {
      return false;
    }
    if (entry.isExpired(DateTime.now())) {
      _store.remove(key);
      return false;
    }
    return true;
  }

  /// Returns the live value for [key], or `null` on miss/expiry.
  T? get(String key) {
    final CacheEntry<T>? entry = _store[key];
    if (entry == null) {
      return null;
    }
    final DateTime now = DateTime.now();
    if (entry.isExpired(now)) {
      _store.remove(key);
      return null;
    }
    // Promote to most-recently-used by re-inserting at the end.
    _store.remove(key);
    _store[key] = entry.touched(now);
    return entry.value;
  }

  /// Stores [value] at [key], applying [ttl] (or [defaultTtl]).
  ///
  /// Evicts the least-recently-used entry when over capacity. Returns the
  /// number of entries evicted (0 or 1) for stats tracking.
  int put(String key, T value, {Duration? ttl}) {
    final DateTime now = DateTime.now();
    final Duration effectiveTtl = ttl ?? defaultTtl;
    _store[key] = CacheEntry<T>(
      value: value,
      expiresAt: now.add(effectiveTtl),
      lastAccessedAt: now,
    );
    return _evictIfNeeded();
  }

  /// Removes [key]; returns `true` if it was present.
  bool remove(String key) => _store.remove(key) != null;

  /// Removes every entry.
  void clear() => _store.clear();

  /// Total number of entries currently held (including not-yet-collected
  /// expired entries).
  int get length => _store.length;

  /// All keys currently present (including not-yet-collected expired entries).
  Iterable<String> get keys => _store.keys;

  /// Evicts the least-recently-used entry (first in insertion order, since
  /// accessed entries are re-inserted at the end). Returns 1 if an entry was
  /// evicted, otherwise 0.
  int _evictIfNeeded() {
    if (_store.length <= maxEntries) {
      return 0;
    }
    final String oldestKey = _store.keys.first;
    _store.remove(oldestKey);
    return 1;
  }
}
