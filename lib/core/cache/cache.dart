import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/core/cache/cache_manager.dart';

export 'package:hivorr/core/cache/cache_config.dart';
export 'package:hivorr/core/cache/cache_entry.dart';
export 'package:hivorr/core/cache/cache_manager.dart';
export 'package:hivorr/core/cache/lru_cache.dart';

/// Bootstraps the in-memory cache subsystem from the validated [config].
///
/// Exported for EP-01-15 to call during app startup. Does not modify
/// `main.dart` or bootstrap; it only initializes the cache manager.
Future<CacheManager> initializeCache(EnvironmentConfig config) async {
  return CacheManager.initialize(config.cacheConfig);
}
