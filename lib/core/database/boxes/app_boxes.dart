/// Named-box (collection) registry for the local storage engine.
///
/// Boxes provide logical isolation between features so that keys never
/// collide across subsystems. The persistent store is shared, but each box is
/// an independent namespace. This also keeps the sensitive-vs-operational
/// boundary explicit: operational/offline cache data lives in its own box,
/// separate from the secrets handled by `lib/core/storage/` (EP-01-10).
///
/// EP-01-12 (Offline Sync Engine) persists its action queue in [syncQueue];
/// EP-01-08 (`EntityLocalDataSource`) may cache entity data in [entityCache].
class AppBoxes {
  AppBoxes._();

  /// Transient or miscellaneous operational cache.
  static const String cache = 'cache';

  /// Durable queue of pending offline mutations (EP-01-12).
  static const String syncQueue = 'sync_queue';

  /// Cached entity/profile DTOs (EP-01-08). Holds only non-sensitive fields.
  static const String entityCache = 'entity_cache';

  /// Catch-all box for miscellaneous non-secret local state.
  static const String misc = 'misc';

  /// All pre-registered box names.
  static const List<String> all = <String>[
    cache,
    syncQueue,
    entityCache,
    misc,
  ];
}
