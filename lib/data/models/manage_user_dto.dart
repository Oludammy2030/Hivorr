// Data Transfer Objects for the Manage User (admin console) RPCs (EP-02-11).
//
// Field names are camelCase in Dart but map the server snake_case columns
// exactly via [fromJson] to avoid silent deserialization drift. The canonical
// shapes below are locked server-side by
// supabase/tests/database/022_manage_user.sql; the client adopts them verbatim
// (migration 20260917090002).

/// A single directory row returned by `manage_user_list` (data.users[]).
///
/// Canonical server row:
///   id, display_name, legal_name, avatar_path, status, roles[],
///   kyc_tier, is_admin, onboarding_completed, created_at
class ManageUserListItemDto {
  const ManageUserListItemDto({
    required this.id,
    required this.displayName,
    this.legalName,
    this.avatarPath,
    required this.status,
    required this.roles,
    this.kycTier,
    required this.isAdmin,
    required this.onboardingCompleted,
    required this.createdAt,
  });

  factory ManageUserListItemDto.fromJson(Map<String, dynamic> json) {
    final Object? rolesValue = json['roles'];
    return ManageUserListItemDto(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      legalName: json['legal_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
      status: (json['status'] as String?) ?? 'active',
      roles: rolesValue is List
          ? rolesValue.whereType<String>().toList(growable: false)
          : const <String>[],
      kycTier: json['kyc_tier'] as String?,
      isAdmin: (json['is_admin'] as bool?) ?? false,
      onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
      createdAt:
          _parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String displayName;
  final String? legalName;
  final String? avatarPath;
  final String status;
  final List<String> roles;
  final String? kycTier;
  final bool isAdmin;
  final bool onboardingCompleted;
  final DateTime createdAt;
}

/// The directory page returned by `manage_user_list` (data).
///
/// Canonical server data:
///   { users: [...], total_count: int }
class ManageUserListEnvelopeDto {
  const ManageUserListEnvelopeDto({
    required this.users,
    required this.totalCount,
  });

  factory ManageUserListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? usersValue = json['users'];
    return ManageUserListEnvelopeDto(
      users: usersValue is List
          ? usersValue
                .whereType<Map<String, dynamic>>()
                .map(ManageUserListItemDto.fromJson)
                .toList(growable: false)
          : const <ManageUserListItemDto>[],
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  final List<ManageUserListItemDto> users;
  final int totalCount;
}

/// The single-user posture returned by `manage_user_get` (data.user).
///
/// Canonical server shape:
///   entity  {id, status, capability, onboarding_completed_at, created_at}
///   profile {display_name, legal_name, bio, avatar_path, country_code}
///   roles   [{role, is_active, activated_at}]
///   kyc     {tier_code, status, assigned_at}   (null when no KYC level)
///   is_admin
///   summary {credential_count, approved_credentials, pending_submissions,
///            total_submissions}
///
/// `profile` is `null` when the entity has not created a profile row yet.
class ManageUserDetailDto {
  const ManageUserDetailDto({
    required this.entity,
    this.profile,
    required this.roles,
    this.kyc,
    this.isAdmin = false,
    required this.summary,
  });

  factory ManageUserDetailDto.fromJson(Map<String, dynamic> json) {
    final Object? entity = json['entity'];
    final Object? profile = json['profile'];
    final Object? kyc = json['kyc'];
    final Object? summary = json['summary'];
    if (entity is! Map || summary is! Map) {
      throw const FormatException('Malformed manage_user_get payload.');
    }
    return ManageUserDetailDto(
      entity: ManageUserEntityDto.fromJson(Map<String, dynamic>.from(entity)),
      profile: profile is Map
          ? ManageUserProfileDto.fromJson(Map<String, dynamic>.from(profile))
          : null,
      roles: _parseRoles(json['roles']),
      kyc: kyc is Map
          ? ManageUserKycDto.fromJson(Map<String, dynamic>.from(kyc))
          : null,
      isAdmin: (json['is_admin'] as bool?) ?? false,
      summary: ManageUserSummaryDto.fromJson(
        Map<String, dynamic>.from(summary),
      ),
    );
  }

  final ManageUserEntityDto entity;
  final ManageUserProfileDto? profile;
  final List<ManageUserRoleDto> roles;
  final ManageUserKycDto? kyc;
  final bool isAdmin;
  final ManageUserSummaryDto summary;

  static List<ManageUserRoleDto> _parseRoles(Object? value) {
    if (value is! List) return const <ManageUserRoleDto>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(ManageUserRoleDto.fromJson)
        .toList(growable: false);
  }
}

/// Entity core block of [ManageUserDetailDto].
class ManageUserEntityDto {
  const ManageUserEntityDto({
    required this.id,
    required this.status,
    this.capability,
    this.onboardingCompletedAt,
    required this.createdAt,
  });

  factory ManageUserEntityDto.fromJson(Map<String, dynamic> json) {
    return ManageUserEntityDto(
      id: json['id'] as String,
      status: (json['status'] as String?) ?? 'active',
      capability: json['capability'] as String?,
      onboardingCompletedAt: _parseDate(json['onboarding_completed_at']),
      createdAt:
          _parseDate(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String status;
  final String? capability;
  final DateTime? onboardingCompletedAt;
  final DateTime createdAt;
}

/// Profile block of [ManageUserDetailDto]. `null` when the entity has no
/// profile row.
class ManageUserProfileDto {
  const ManageUserProfileDto({
    this.displayName,
    this.legalName,
    this.bio,
    this.avatarPath,
    this.countryCode,
  });

  factory ManageUserProfileDto.fromJson(Map<String, dynamic> json) {
    return ManageUserProfileDto(
      displayName: json['display_name'] as String?,
      legalName: json['legal_name'] as String?,
      bio: json['bio'] as String?,
      avatarPath: json['avatar_path'] as String?,
      countryCode: json['country_code'] as String?,
    );
  }

  final String? displayName;
  final String? legalName;
  final String? bio;
  final String? avatarPath;
  final String? countryCode;
}

/// A single role assignment block of [ManageUserDetailDto].
class ManageUserRoleDto {
  const ManageUserRoleDto({
    required this.role,
    this.isActive = false,
    this.activatedAt,
  });

  factory ManageUserRoleDto.fromJson(Map<String, dynamic> json) {
    return ManageUserRoleDto(
      role: (json['role'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? false,
      activatedAt: _parseDate(json['activated_at']),
    );
  }

  final String role;
  final bool isActive;
  final DateTime? activatedAt;
}

/// Current KYC block of [ManageUserDetailDto]. `null` when the entity has no
/// KYC level row.
class ManageUserKycDto {
  const ManageUserKycDto({this.tierCode, this.status, this.assignedAt});

  factory ManageUserKycDto.fromJson(Map<String, dynamic> json) {
    return ManageUserKycDto(
      tierCode: json['tier_code'] as String?,
      status: json['status'] as String?,
      assignedAt: _parseDate(json['assigned_at']),
    );
  }

  final String? tierCode;
  final String? status;
  final DateTime? assignedAt;
}

/// Verification summary block of [ManageUserDetailDto].
class ManageUserSummaryDto {
  const ManageUserSummaryDto({
    this.credentialCount = 0,
    this.approvedCredentials = 0,
    this.pendingSubmissions = 0,
    this.totalSubmissions = 0,
  });

  factory ManageUserSummaryDto.fromJson(Map<String, dynamic> json) {
    return ManageUserSummaryDto(
      credentialCount: (json['credential_count'] as num?)?.toInt() ?? 0,
      approvedCredentials: (json['approved_credentials'] as num?)?.toInt() ?? 0,
      pendingSubmissions: (json['pending_submissions'] as num?)?.toInt() ?? 0,
      totalSubmissions: (json['total_submissions'] as num?)?.toInt() ?? 0,
    );
  }

  final int credentialCount;
  final int approvedCredentials;
  final int pendingSubmissions;
  final int totalSubmissions;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
