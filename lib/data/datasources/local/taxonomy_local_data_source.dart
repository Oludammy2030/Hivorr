import 'package:hivorr/core/cache/cache_manager.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

/// Abstract contract for the local (cache) side of taxonomy data.
///
/// Provides the persistent seam the repository reads before calling the remote
/// datasource. The concrete implementation is backed by the transient
/// [CacheManager] under the `taxonomy:` prefix (EP-01-11) — process-lifetime,
/// no Hive persistence, avoiding PII-at-rest concerns (EP-02-07 plan §5.5).
abstract class TaxonomyLocalDataSource {
  /// Returns the cached industries, or `null` on miss.
  Future<List<IndustryDto>?> getIndustries();

  /// Caches [industries].
  Future<void> saveIndustries(List<IndustryDto> industries);

  /// Returns the cached professions for [industryId], or `null` on miss.
  Future<List<ProfessionDto>?> getProfessions(String industryId);

  /// Caches [professions] for their owning industry.
  Future<void> saveProfessions(
    String industryId,
    List<ProfessionDto> professions,
  );

  /// Evicts every `taxonomy:`-prefixed entry (after an admin taxonomy
  /// mutation or on demand), leaving unrelated prefixes intact.
  void invalidateTaxonomy();
}

/// In-memory, [CacheManager]-backed implementation of [TaxonomyLocalDataSource].
///
/// Entries live under the `taxonomy:` prefix and inherit the configured TTL /
/// LRU policy from [CacheManager.instance]. Reads promote the entry to
/// most-recently-used (`LruCache.get`); `invalidateTaxonomy()` clears only the
/// taxonomy keys.
class InMemoryTaxonomyLocalDataSource implements TaxonomyLocalDataSource {
  /// Creates the cache-backed local datasource, optionally accepting a
  /// [cacheManager] (injectable for tests; defaults to the singleton).
  InMemoryTaxonomyLocalDataSource({CacheManager? cacheManager})
    : _cache = cacheManager ?? CacheManager.instance;

  static const String _prefix = 'taxonomy:';
  static const String _industriesKey = '${_prefix}industries';
  static String _professionsKey(String industryId) =>
      '${_prefix}professions:$industryId';

  final CacheManager _cache;

  @override
  Future<List<IndustryDto>?> getIndustries() async =>
      _cache.get<List<IndustryDto>>(_industriesKey);

  @override
  Future<void> saveIndustries(List<IndustryDto> industries) async {
    _cache.put<List<IndustryDto>>(_industriesKey, industries);
  }

  @override
  Future<List<ProfessionDto>?> getProfessions(String industryId) async =>
      _cache.get<List<ProfessionDto>>(_professionsKey(industryId));

  @override
  Future<void> saveProfessions(
    String industryId,
    List<ProfessionDto> professions,
  ) async {
    _cache.put<List<ProfessionDto>>(
      _professionsKey(industryId),
      professions,
    );
  }

  @override
  void invalidateTaxonomy() {
    _cache.invalidatePrefix(_prefix);
  }
}
