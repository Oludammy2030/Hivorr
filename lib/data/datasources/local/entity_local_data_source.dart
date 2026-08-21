import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';

/// Abstract contract for the local (cache) side of entity data.
///
/// Defined by EP-01-08 as the integration seam for EP-01-11 (storage) and
/// EP-01-12 (sync). Only the interface and an in-memory default live here;
/// concrete persistence is deferred to later tasks (EP-01-08 §5.5).
abstract class EntityLocalDataSource {
  /// Returns the cached profile for [entityId], or `null` if absent.
  Future<EntityProfileDto?> getProfile(String entityId);

  /// Caches [profile].
  Future<void> saveProfile(EntityProfileDto profile);

  /// Returns the cached roles for [entityId] (may be empty).
  Future<List<EntityRoleDto>> getRoles(String entityId);

  /// Caches [roles] for their owning entity.
  Future<void> saveRoles(List<EntityRoleDto> roles);

  /// Clears all cached entity data.
  Future<void> clear();
}

/// In-memory implementation of [EntityLocalDataSource].
///
/// Satisfies the contract so the repository compiles and runs in tests/CI
/// today. EP-01-11 replaces this with a SQLite/Hive/Isar-backed store and
/// EP-01-12 adds queue/replay — without changing the repository contract.
class InMemoryEntityLocalDataSource implements EntityLocalDataSource {
  /// Creates an in-memory store, optionally seeded (used by tests).
  InMemoryEntityLocalDataSource({
    Map<String, EntityProfileDto>? profiles,
    Map<String, List<EntityRoleDto>>? roles,
  })  : _profiles = profiles ?? <String, EntityProfileDto>{},
        _roles = roles ?? <String, List<EntityRoleDto>>{};

  final Map<String, EntityProfileDto> _profiles;
  final Map<String, List<EntityRoleDto>> _roles;

  @override
  Future<EntityProfileDto?> getProfile(String entityId) async =>
      _profiles[entityId];

  @override
  Future<void> saveProfile(EntityProfileDto profile) async {
    _profiles[profile.entityId] = profile;
  }

  @override
  Future<List<EntityRoleDto>> getRoles(String entityId) async =>
      List<EntityRoleDto>.from(_roles[entityId] ?? const <EntityRoleDto>[]);

  @override
  Future<void> saveRoles(List<EntityRoleDto> roles) async {
    final String? entityId = roles.isEmpty ? null : roles.first.entityId;
    if (entityId != null) {
      _roles[entityId] = List<EntityRoleDto>.from(roles);
    }
  }

  @override
  Future<void> clear() async {
    _profiles.clear();
    _roles.clear();
  }
}
