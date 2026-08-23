/// A single cached entry with TTL and LRU bookkeeping.
///
/// [expiresAt] drives lazy expiry; [lastAccessedAt] drives LRU ordering. The
/// entry is immutable — updates produce a new instance via [touched].
class CacheEntry<T> {
  CacheEntry({
    required this.value,
    required this.expiresAt,
    required this.lastAccessedAt,
  });

  /// The cached value.
  final T value;

  /// Absolute expiry timestamp. After this, the entry is a miss.
  final DateTime expiresAt;

  /// Last access timestamp, used for LRU eviction ordering.
  final DateTime lastAccessedAt;

  /// Whether this entry has expired relative to [now].
  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  /// Returns a copy with [lastAccessedAt] refreshed to [now].
  CacheEntry<T> touched(DateTime now) => CacheEntry<T>(
        value: value,
        expiresAt: expiresAt,
        lastAccessedAt: now,
      );
}
