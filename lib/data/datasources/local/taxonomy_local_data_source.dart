import 'package:hivorr/core/cache/cache_manager.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

/// Abstract contract for the local (cache) side of taxonomy data.
///
/// Defines the cache-first seam the repository consumes (EP-02-07 plan §5.3).
/// Implementations store DTO lists under the `taxonomy:` key prefix.
abstract class TaxonomyLocalDataSource {
  /// Returns the cached industries, or `null` on miss/expiry.
  Future<List<IndustryDto>?> getIndustries();

  /// Caches [industries] under the `taxonomy:industries` key.
  Future<void> saveIndustries(List<IndustryDto> industries);

  /// Returns the cached professions for [industryId], or `null` on miss/expiry.
  Future<List<ProfessionDto>?> getProfessions(String industryId);

  /// Caches [professions] under the `taxonomy:professions:<industryId>` key.
  Future<void> saveProfessions(String industryId, List<ProfessionDto> professions);

  /// Clears all taxonomy-scoped cache entries.
  Future<void> invalidate();
}

/// Cache key prefix for all taxonomy entries.
const String taxonomyCachePrefix = 'taxonomy:';

/// [CacheManager]-backed implementation of [TaxonomyLocalDataSource].
///
/// Uses the process-wide [CacheManager] singleton with a TTL sourced from
/// [CacheConfig.defaultTtl] so warm reads hit memory and yield zero network.
/// If the cache manager has not been initialized by the app (EP-01-11), this
/// implementation degrades gracefully to a private in-memory map rather than
/// throwing, keeping the read path functional.
class CacheManagerTaxonomyLocalDataSource implements TaxonomyLocalDataSource {
  /// Creates the datasource. [cache] defaults to the shared [CacheManager].
  CacheManagerTaxonomyLocalDataSource({this._cache});

  /// The cache manager backing reads/writes, or `null` to use the shared
  /// [CacheManager] singleton (falling back to in-memory when uninitialized).
  final CacheManager? _cache;
  final Map<String, List<Map<String, dynamic>>> _fallback =
      <String, List<Map<String, dynamic>>>{};

  CacheManager? get _resolved =>
      _cache ?? (CacheManager.isInitialized ? CacheManager.instance : null);

  @override
  Future<List<IndustryDto>?> getIndustries() async {
    final CacheManager? cache = _resolved;
    if (cache != null) {
      final List<IndustryDto>? cached =
          cache.get<List<IndustryDto>>('${taxonomyCachePrefix}industries');
      return cached;
    }
    final List<Map<String, dynamic>>? raw =
        _fallback['${taxonomyCachePrefix}industries'];
    return raw?.map(IndustryDto.fromJson).toList();
  }

  @override
  Future<void> saveIndustries(List<IndustryDto> industries) async {
    final CacheManager? cache = _resolved;
    if (cache != null) {
      cache.put<List<IndustryDto>>(
        '${taxonomyCachePrefix}industries',
        industries,
      );
    } else {
      _fallback['${taxonomyCachePrefix}industries'] = industries
          .map((IndustryDto dto) => dto.toJson())
          .toList();
    }
  }

  @override
  Future<List<ProfessionDto>?> getProfessions(String industryId) async {
    final String key = '${taxonomyCachePrefix}professions:$industryId';
    final CacheManager? cache = _resolved;
    if (cache != null) {
      final List<ProfessionDto>? cached = cache.get<List<ProfessionDto>>(key);
      return cached;
    }
    final List<Map<String, dynamic>>? raw = _fallback[key];
    return raw?.map(ProfessionDto.fromJson).toList();
  }

  @override
  Future<void> saveProfessions(
    String industryId,
    List<ProfessionDto> professions,
  ) async {
    final String key = '${taxonomyCachePrefix}professions:$industryId';
    final CacheManager? cache = _resolved;
    if (cache != null) {
      cache.put<List<ProfessionDto>>(
        key,
        professions,
      );
    } else {
      _fallback[key] = professions
          .map((ProfessionDto dto) => dto.toJson())
          .toList();
    }
  }

  @override
  Future<void> invalidate() async {
    final CacheManager? cache = _resolved;
    if (cache != null) {
      cache.invalidatePrefix(taxonomyCachePrefix);
    }
    _fallback.clear();
  }
}

/// In-memory implementation of [TaxonomyLocalDataSource] for tests and
/// dependency-free default wiring.
class InMemoryTaxonomyLocalDataSource implements TaxonomyLocalDataSource {
  /// Creates an in-memory store, optionally pre-seeded (used by tests).
  InMemoryTaxonomyLocalDataSource({
    List<IndustryDto>? industries,
    Map<String, List<ProfessionDto>>? professionsByIndustry,
  })  : _industries = industries ?? <IndustryDto>[],
        _professionsByIndustry = professionsByIndustry ?? <String, List<ProfessionDto>>{};

  List<IndustryDto> _industries;
  final Map<String, List<ProfessionDto>> _professionsByIndustry;

  @override
  Future<List<IndustryDto>?> getIndustries() async =>
      _industries.isEmpty ? null : List<IndustryDto>.from(_industries);

  @override
  Future<void> saveIndustries(List<IndustryDto> industries) async {
    _industries = List<IndustryDto>.from(industries);
  }

  @override
  Future<List<ProfessionDto>?> getProfessions(String industryId) async {
    final List<ProfessionDto>? cached = _professionsByIndustry[industryId];
    return cached == null ? null : List<ProfessionDto>.from(cached);
  }

  @override
  Future<void> saveProfessions(
    String industryId,
    List<ProfessionDto> professions,
  ) async {
    _professionsByIndustry[industryId] = List<ProfessionDto>.from(professions);
  }

  @override
  Future<void> invalidate() async {
    _industries = <IndustryDto>[];
    _professionsByIndustry.clear();
  }
}
