import 'package:hivorr/core/cache/cache_manager.dart';
import 'package:hivorr/core/database/database.dart';
import 'package:hivorr/data/datasources/local/service_search_local_data_source.dart';
import 'package:hivorr/data/models/service_listing_dto.dart';

/// Persistent [Hive]-backed implementation of [ServiceSearchLocalDataSource].
///
/// Mirrors `HiveOnboardingProgressStore` pattern — reuses `LocalStore`
/// (`lib/core/database/local_store.dart:13`) over `AppBoxes.cache`
/// (`lib/core/database/boxes/app_boxes.dart:15`) with `serviceSearchCachePrefix`
/// (`service_search_local_data_source.dart:5`) key namespace. This provides
/// offline browse resilience that survives process restart (airplane mode,
/// app cold-start).
///
/// Designed as a **second-tier** underneath `CacheManagerServiceSearchLocalDataSource:31`
/// (transient `5m TTL`) — the repository can compose both, with this one
/// acting as the durable warm cache for `ServiceSearchIndex.hydrateOffline`.
///
/// No new `AppBoxes` box required — reuses `cache` namespace. Falls back to
/// in-memory `Map` when `LocalStore` is `null` (tests / pre-init).
class HiveServiceSearchLocalDataSource implements ServiceSearchLocalDataSource {
  HiveServiceSearchLocalDataSource({
    this.store,
    this.cache,
  });

  /// The typed [LocalStore] accessor over [HiveStorageEngine], or `null` to
  /// use in-memory fallback (tests / dependency-free wiring).
  final LocalStore? store;

  /// Optional transient [CacheManager] fronting the persistent store (second-tier).
  /// When non-null, `getPage` prefers `CacheManager` hit, else falls back to
  /// [LocalStore]. Writes update both.
  final CacheManager? cache;

  final Map<String, ServiceSearchPageDto> _fallback =
      <String, ServiceSearchPageDto>{};
  DateTime? _fallbackVersion;

  String _k(String key) => '$serviceSearchCachePrefix$key';

  /// The box name backing reads/writes. Reuses `AppBoxes.cache` — no new
  /// box constant required per plan §7.2.
  static const String _box = AppBoxes.cache;

  @override
  Future<ServiceSearchPageDto?> getPage(String key) async {
    final String k = _k(key);

    // Tier 1: transient CacheManager hit (fast path).
    final CacheManager? c = cache;
    if (c != null) {
      final ServiceSearchPageDto? hit = c.get<ServiceSearchPageDto>(k);
      if (hit != null) return hit;
    }

    // Tier 2: persistent Hive (survives process restart).
    final LocalStore? s = store;
    if (s != null) {
      final ServiceSearchPageDto? persisted = await s.read<ServiceSearchPageDto>(
        _box,
        k,
        ServiceSearchPageDto.fromJson,
      );
      if (persisted != null) {
        // Promote to transient tier for subsequent reads.
        if (c != null) {
          c.put<ServiceSearchPageDto>(k, persisted, ttl: serviceSearchCacheTtl);
        }
        return persisted;
      }
      return null;
    }

    // Tier 3: in-memory fallback (tests / no engine).
    return _fallback[k];
  }

  @override
  Future<void> savePage(String key, ServiceSearchPageDto page) async {
    final String k = _k(key);
    final CacheManager? c = cache;
    if (c != null) {
      c.put<ServiceSearchPageDto>(k, page, ttl: serviceSearchCacheTtl);
    }
    final LocalStore? s = store;
    if (s != null) {
      await s.write<ServiceSearchPageDto>(
        _box,
        k,
        page,
        (ServiceSearchPageDto dto) => dto.toJson(),
      );
    } else {
      _fallback[k] = page;
    }
  }

  @override
  Future<DateTime?> getWeightsVersion() async {
    const String k = '${serviceSearchCachePrefix}weights_version';
    final CacheManager? c = cache;
    if (c != null) {
      final DateTime? hit = c.get<DateTime>(k);
      if (hit != null) return hit;
    }
    final LocalStore? s = store;
    if (s != null) {
      final _WeightsVersionBox? v = await s.read<_WeightsVersionBox>(
        _box,
        k,
        _WeightsVersionBox.fromJson,
      );
      if (v != null) {
        if (c != null) c.put<DateTime>(k, v.value);
        return v.value;
      }
      return null;
    }
    return _fallbackVersion;
  }

  @override
  Future<void> saveWeightsVersion(DateTime version) async {
    const String k = '${serviceSearchCachePrefix}weights_version';
    final CacheManager? c = cache;
    if (c != null) c.put<DateTime>(k, version);
    final LocalStore? s = store;
    if (s != null) {
      await s.write<_WeightsVersionBox>(
        _box,
        k,
        _WeightsVersionBox(version),
        (_WeightsVersionBox v) => v.toJson(),
      );
    }
    _fallbackVersion = version;
  }

  @override
  Future<void> invalidate() async {
    final CacheManager? c = cache;
    if (c != null) {
      c.invalidatePrefix(serviceSearchCachePrefix);
    }
    final LocalStore? s = store;
    if (s != null) {
      // Hive does not support prefix-scan natively; iterate keys and delete
      // those with `service_search:` prefix (best-effort atomic via writeBatch).
      final List<String> allKeys = await s.keys(_box);
      final List<String> targets = allKeys
          .where((String k) => k.startsWith(serviceSearchCachePrefix))
          .toList(growable: false);
      if (targets.isNotEmpty) {
        await s.writeBatch(
          _box,
          targets
              .map((String k) => DeleteOp(k))
              .toList(growable: false),
        );
      }
    }
    _fallback.clear();
    _fallbackVersion = null;
  }
}

/// Tiny wrapper so we can persist `DateTime` via [LocalStore.write] which
/// requires a typed `toJson/fromJson` pair. Internal to this file — never
/// exported.
class _WeightsVersionBox {
  const _WeightsVersionBox(this.value);
  final DateTime value;
  Map<String, dynamic> toJson() => <String, dynamic>{'v': value.toIso8601String()};
  static _WeightsVersionBox fromJson(Map<String, dynamic> json) =>
      _WeightsVersionBox(DateTime.parse(json['v'] as String));
}
