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

  /// Number of times [getProfile] was invoked (cache-first assertions).
  int getProfileCallCount = 0;

  /// Number of times [updateProfile] was invoked (write-through assertions).
  int updateProfileCallCount = 0;

  /// Number of times [activateRole] was invoked.
  int activateRoleCallCount = 0;

  /// The role most recently activated via [activateRole].
  String? lastActivatedRole;

  /// Number of times [getRoles] was invoked.
  int getRolesCallCount = 0;

  /// Number of times [bindProfession] was invoked.
  int bindProfessionCallCount = 0;

  /// Number of times [updateAvatarPath] was invoked.
  int updateAvatarPathCallCount = 0;

  /// The profession id most recently bound via [bindProfession].
  String? lastBoundProfessionId;

  /// The avatar path most recently persisted via [updateAvatarPath].
  String? lastAvatarPath;

  /// When `true`, [bindProfession] throws `PLT005` (`conflict`).
  bool throwConflictOnBind = false;

  @override
  Future<EntityProfileDto?> getProfile(String entityId) async {
    getProfileCallCount++;
    return profile;
  }

  @override
  Future<EntityProfileDto> updateProfile({
    required String entityId,
    required String legalName,
    required String displayName,
    String? bio,
  }) async {
    updateProfileCallCount++;
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
    activateRoleCallCount++;
    if (throwOnActivate) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid role.',
        code: 'PLT003',
      );
    }
    lastActivatedRole = role;
    roles = <EntityRoleDto>[
      EntityRoleDto(entityId: entityId, role: role, isActive: true),
    ];
  }

  @override
  Future<List<EntityRoleDto>> getRoles(String entityId) async {
    getRolesCallCount++;
    return roles;
  }

  @override
  Future<void> bindProfession({required String professionId}) async {
    bindProfessionCallCount++;
    if (throwConflictOnBind) {
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Profession already bound.',
        code: 'PLT005',
      );
    }
    lastBoundProfessionId = professionId;
  }

  @override
  Future<EntityProfileDto> updateAvatarPath({
    required String entityId,
    required String avatarPath,
  }) async {
    updateAvatarPathCallCount++;
    final EntityProfileDto current = profile ??
        EntityProfileDto(
          entityId: entityId,
          legalName: '',
          displayName: '',
        );
    profile = EntityProfileDto(
      entityId: current.entityId,
      legalName: current.legalName,
      displayName: current.displayName,
      bio: current.bio,
      avatarPath: avatarPath,
      countryCode: current.countryCode,
    );
    lastAvatarPath = avatarPath;
    return profile!;
  }
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
