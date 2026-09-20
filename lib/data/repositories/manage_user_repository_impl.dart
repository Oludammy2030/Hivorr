// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/data/datasources/remote/manage_user_remote_data_source.dart';
import 'package:hivorr/data/models/manage_user_dto.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';

/// Default implementation of [ManageUserRepository].
///
/// Maps DTOs to domain entities and delegates transport to the injected
/// [ManageUserRemoteDataSource].
class ManageUserRepositoryImpl implements ManageUserRepository {
  ManageUserRepositoryImpl({required ManageUserRemoteDataSource remote})
    : _remote = remote;

  final ManageUserRemoteDataSource _remote;

  @override
  Future<ManageUserDirectoryPage> listUsers({
    String? search,
    String? status,
    int offset = 0,
    int limit = 20,
  }) async {
    final ManageUserListEnvelopeDto envelope = await _remote.listUsers(
      search: search,
      status: status,
      offset: offset,
      limit: limit,
    );
    return ManageUserDirectoryPage(
      users: envelope.users.map(_listItemToEntity).toList(growable: false),
      totalCount: envelope.totalCount,
    );
  }

  @override
  Future<ManageUserDetail> getUser(String userId) async {
    final ManageUserDetailDto dto = await _remote.getUser(userId);
    return ManageUserDetail(
      entity: ManageUserEntityCore(
        id: dto.entity.id,
        status: dto.entity.status,
        capability: dto.entity.capability,
        onboardingCompletedAt: dto.entity.onboardingCompletedAt,
        createdAt: dto.entity.createdAt,
      ),
      profile: dto.profile == null
          ? null
          : ManageUserProfile(
              displayName: dto.profile!.displayName,
              legalName: dto.profile!.legalName,
              bio: dto.profile!.bio,
              avatarPath: dto.profile!.avatarPath,
              countryCode: dto.profile!.countryCode,
            ),
      roles: dto.roles
          .map(
            (ManageUserRoleDto role) => ManageUserRoleAssignment(
              role: role.role,
              isActive: role.isActive,
              activatedAt: role.activatedAt,
            ),
          )
          .toList(growable: false),
      kyc: dto.kyc == null
          ? null
          : ManageUserKycSummary(
              tierCode: dto.kyc!.tierCode,
              status: dto.kyc!.status,
              assignedAt: dto.kyc!.assignedAt,
            ),
      isAdmin: dto.isAdmin,
      summary: ManageUserVerificationSummary(
        credentialCount: dto.summary.credentialCount,
        approvedCredentials: dto.summary.approvedCredentials,
        pendingSubmissions: dto.summary.pendingSubmissions,
        totalSubmissions: dto.summary.totalSubmissions,
      ),
    );
  }

  @override
  Future<void> setUserStatus(String userId, String status) =>
      _remote.setUserStatus(userId, status);

  @override
  Future<void> resetOnboarding(String userId) =>
      _remote.resetOnboarding(userId);

  ManageUserListItem _listItemToEntity(ManageUserListItemDto dto) {
    return ManageUserListItem(
      id: dto.id,
      displayName: dto.displayName,
      legalName: dto.legalName,
      avatarPath: dto.avatarPath,
      status: dto.status,
      roles: dto.roles,
      kycTier: dto.kycTier,
      isAdmin: dto.isAdmin,
      onboardingCompleted: dto.onboardingCompleted,
      createdAt: dto.createdAt,
    );
  }
}
