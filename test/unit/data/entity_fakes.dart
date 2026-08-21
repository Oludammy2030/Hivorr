import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/entity_remote_data_source.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';

/// Shared, dependency-free fakes for data-layer unit tests.
///
/// Implements the datasource abstractions with controllable in-memory state so
/// repositories and providers can be exercised without a live backend.
class FakeEntityRemoteDataSource extends EntityRemoteDataSource {
  /// Profile returned by [getProfile] / set by [updateProfile].
  EntityProfileDto? profile;

  /// Role bindings returned by [getRoles].
  List<EntityRoleDto> roles = <EntityRoleDto>[];

  /// When `true`, [activateRole] throws a validation [ApiException].
  bool throwOnActivate = false;

  @override
  Future<EntityProfileDto?> getProfile(String entityId) async => profile;

  @override
  Future<EntityProfileDto> updateProfile({
    required String entityId,
    required String legalName,
    required String displayName,
    String? bio,
  }) async {
    profile = EntityProfileDto(
      entityId: entityId,
      legalName: legalName,
      displayName: displayName,
      bio: bio,
    );
    return profile!;
  }

  @override
  Future<void> activateRole({
    required String entityId,
    required String role,
  }) async {
    if (throwOnActivate) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid role.',
        code: 'PLT003',
      );
    }
    roles = <EntityRoleDto>[
      EntityRoleDto(entityId: entityId, role: role, isActive: true),
    ];
  }

  @override
  Future<List<EntityRoleDto>> getRoles(String entityId) async => roles;
}

/// In-memory fake of [EntityLocalDataSource] for tests.
class FakeEntityLocalDataSource extends EntityLocalDataSource {
  EntityProfileDto? cachedProfile;
  List<EntityRoleDto> cachedRoles = <EntityRoleDto>[];

  @override
  Future<EntityProfileDto?> getProfile(String entityId) async => cachedProfile;

  @override
  Future<void> saveProfile(EntityProfileDto profile) async {
    cachedProfile = profile;
  }

  @override
  Future<List<EntityRoleDto>> getRoles(String entityId) async => cachedRoles;

  @override
  Future<void> saveRoles(List<EntityRoleDto> roles) async {
    cachedRoles = roles;
  }

  @override
  Future<void> clear() async {
    cachedProfile = null;
    cachedRoles = <EntityRoleDto>[];
  }
}
