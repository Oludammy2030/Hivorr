import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

/// Immutable in-memory cache configuration for the Hivorr client.
///
/// Carries only non-secret, deployment-sourced cache metadata: the maximum
/// number of entries before LRU eviction and the default entry TTL. All values
/// are sourced exclusively from [EnvironmentConfig] (EP-01-03).
class CacheConfig {
  const CacheConfig({
    required this.maxEntries,
    required this.defaultTtl,
    this.evictionPolicy = EvictionPolicy.lru,
  });

  /// Maximum number of entries retained before the least-recently-used entry
  /// is evicted.
  final int maxEntries;

  /// Default time-to-live applied to entries that do not specify their own.
  final Duration defaultTtl;

  /// Cache eviction strategy.
  final EvictionPolicy evictionPolicy;

  /// Builds [CacheConfig] from an [EnvironmentValueSource].
  ///
  /// Missing values fall back to safe defaults so the loader stays fail-closed
  /// on the core Supabase/schema contract while caching remains opt-in.
  static CacheConfig fromSource(EnvironmentValueSource source) {
    final int max = _parseInt(
      source,
      AppConstants.envCacheMaxEntries,
      AppConstants.defaultCacheMaxEntries,
    );
    final int ttlSeconds = _parseInt(
      source,
      AppConstants.envCacheDefaultTtlSeconds,
      AppConstants.defaultCacheDefaultTtlSeconds,
    );
    return CacheConfig(
      maxEntries: max,
      defaultTtl: Duration(seconds: ttlSeconds),
      evictionPolicy: EvictionPolicy.lru,
    );
  }

  /// Integer parse with a safe fallback; malformed → throws.
  static int _parseInt(
    EnvironmentValueSource source,
    String key,
    int fallback,
  ) {
    final String? raw = source.read(key);
    if (raw == null) {
      return fallback;
    }
    final int? parsed = int.tryParse(raw);
    if (parsed == null) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Cache value must be an integer.',
      );
    }
    return parsed;
  }

  @override
  String toString() {
    return 'CacheConfig('
        'maxEntries: $maxEntries, '
        'defaultTtl: ${defaultTtl.inSeconds}s, '
        'evictionPolicy: $evictionPolicy)';
  }
}

/// Supported cache eviction policies.
enum EvictionPolicy {
  /// Least-recently-used eviction (plan §5.4).
  lru,
}
