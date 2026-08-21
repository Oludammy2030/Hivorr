import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/entity_remote_data_source.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';
import 'package:hivorr/data/mappers/entity_profile_mapper.dart';
import 'package:hivorr/data/mappers/entity_role_mapper.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';
import 'package:hivorr/data/repositories/entity_repository.dart';

/// Default implementation composing remote + local datasources.
///
/// Reads are cache-first (delegating to the local seam), writes go through the
/// remote and refresh the local cache. All errors are propagated as typed
/// [ApiException]s — no business decisions are made here (EP-01-08 §5.6).
class EntityRepositoryImpl implements EntityRepository {
  /// Creates the repository from its two datasource dependencies.
  EntityRepositoryImpl({
    required this.remote,
    required this.local,
  });

  /// The remote (Supabase) datasource.
  final EntityRemoteDataSource remote;

  /// The local (cache) datasource.
  final EntityLocalDataSource local;

  @override
  Future<EntityProfile> getProfile(String entityId) async {
    final EntityProfileDto? cached = await local.getProfile(entityId);
    if (cached != null) {
      return EntityProfileMapper.toEntity(cached);
    }
    final EntityProfileDto fetched = await remote.getProfile(entityId) ??
        (throw const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'Profile not found.',
          code: 'PLT004',
        ));
    await local.saveProfile(fetched);
    return EntityProfileMapper.toEntity(fetched);
  }

  @override
  Future<EntityProfile> updateProfile({
    required String entityId,
    required String legalName,
    required String displayName,
    String? bio,
  }) async {
    final EntityProfileDto updated = await remote.updateProfile(
      entityId: entityId,
      legalName: legalName,
      displayName: displayName,
      bio: bio,
    );
    await local.saveProfile(updated);
    return EntityProfileMapper.toEntity(updated);
  }

  @override
  Future<void> activateRole({
    required String entityId,
    required String role,
  }) async {
    await remote.activateRole(entityId: entityId, role: role);
    final List<EntityRoleDto> roles = await remote.getRoles(entityId);
    await local.saveRoles(roles);
  }

  @override
  Future<List<EntityRole>> getRoles(String entityId) async {
    final List<EntityRoleDto> cached = await local.getRoles(entityId);
    if (cached.isNotEmpty) {
      return cached.map(EntityRoleMapper.toEntity).toList();
    }
    final List<EntityRoleDto> fetched = await remote.getRoles(entityId);
    await local.saveRoles(fetched);
    return fetched.map(EntityRoleMapper.toEntity).toList();
  }
}
