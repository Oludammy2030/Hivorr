import 'package:hivorr/core/cache/cache_manager.dart';
import 'package:hivorr/data/models/service_listing_dto.dart';

/// Cache key prefix for ranked search pages.
const String serviceSearchCachePrefix = 'service_search:';

/// Default TTL for ranked pages (5 minutes per plan §7.4).
const Duration serviceSearchCacheTtl = Duration(minutes: 5);

/// Abstract contract for the local (cache) side of ranked search.
///
/// Defines the cache-first seam the repository consumes, mirroring
/// `TaxonomyLocalDataSource` (`lib/data/datasources/local/taxonomy_local_data_source.dart:9`).
abstract class ServiceSearchLocalDataSource {
  /// Returns the cached ranked page for [key], or `null` on miss/expiry.
  Future<ServiceSearchPageDto?> getPage(String key);

  /// Caches [page] under `[serviceSearchCachePrefix][key]`.
  Future<void> savePage(String key, ServiceSearchPageDto page);

  /// Returns the last seen `weights_version` or `null` if none.
  Future<DateTime?> getWeightsVersion();

  /// Persists `weights_version` for invalidation checks.
  Future<void> saveWeightsVersion(DateTime version);

  /// Clears all `service_search:` entries (on `weights_version` bump).
  Future<void> invalidate();
}

/// [CacheManager]-backed implementation of [ServiceSearchLocalDataSource].
class CacheManagerServiceSearchLocalDataSource
    implements ServiceSearchLocalDataSource {
  CacheManagerServiceSearchLocalDataSource({this.cache});

  /// The cache manager backing reads/writes, or `null` to use the shared
  /// singleton (falls back to in-memory when uninitialized).
  final CacheManager? cache;

  final Map<String, ServiceSearchPageDto> _fallback =
      <String, ServiceSearchPageDto>{};
  DateTime? _fallbackVersion;

  CacheManager? get _resolved =>
      cache ?? (CacheManager.isInitialized ? CacheManager.instance : null);

  String _k(String key) => '$serviceSearchCachePrefix$key';

  @override
  Future<ServiceSearchPageDto?> getPage(String key) async {
    final CacheManager? c = _resolved;
    if (c != null) {
      return c.get<ServiceSearchPageDto>(_k(key));
    }
    return _fallback[_k(key)];
  }

  @override
  Future<void> savePage(String key, ServiceSearchPageDto page) async {
    final CacheManager? c = _resolved;
    if (c != null) {
      c.put<ServiceSearchPageDto>(
        _k(key),
        page,
        ttl: serviceSearchCacheTtl,
      );
    } else {
      _fallback[_k(key)] = page;
    }
  }

  @override
  Future<DateTime?> getWeightsVersion() async {
    final CacheManager? c = _resolved;
    if (c != null) {
      return c.get<DateTime>('${serviceSearchCachePrefix}weights_version');
    }
    return _fallbackVersion;
  }

  @override
  Future<void> saveWeightsVersion(DateTime version) async {
    final CacheManager? c = _resolved;
    if (c != null) {
      c.put<DateTime>(
        '${serviceSearchCachePrefix}weights_version',
        version,
      );
    }
    _fallbackVersion = version;
  }

  @override
  Future<void> invalidate() async {
    final CacheManager? c = _resolved;
    if (c != null) {
      c.invalidatePrefix(serviceSearchCachePrefix);
    }
    _fallback.clear();
    _fallbackVersion = null;
  }
}

/// In-memory implementation for tests / dependency-free wiring.
class InMemoryServiceSearchLocalDataSource
    implements ServiceSearchLocalDataSource {
  InMemoryServiceSearchLocalDataSource();

  final Map<String, ServiceSearchPageDto> _pages =
      <String, ServiceSearchPageDto>{};
  DateTime? _weightsVersion;

  @override
  Future<ServiceSearchPageDto?> getPage(String key) async =>
      _pages['$serviceSearchCachePrefix$key'];

  @override
  Future<void> savePage(String key, ServiceSearchPageDto page) async {
    _pages['$serviceSearchCachePrefix$key'] = page;
  }

  @override
  Future<DateTime?> getWeightsVersion() async => _weightsVersion;

  @override
  Future<void> saveWeightsVersion(DateTime version) async {
    _weightsVersion = version;
  }

  @override
  Future<void> invalidate() async {
    _pages.clear();
    _weightsVersion = null;
  }
}
