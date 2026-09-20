/// Abstract contract for Manage User (admin console) data operations
/// (EP-02-11 §5.3).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface (ARCHITECTURE.md).
abstract class ManageUserRepository {
  /// Returns a paginated directory page of users.
  Future<ManageUserDirectoryPage> listUsers({
    String? search,
    String? status,
    int offset = 0,
    int limit = 20,
  });

  /// Returns the full posture for a single user.
  Future<ManageUserDetail> getUser(String userId);

  /// Sets an entity lifecycle status (`active | suspended | deactivated`).
  Future<void> setUserStatus(String userId, String status);

  /// Resets onboarding for a user (clears capability + completion stamp).
  Future<void> resetOnboarding(String userId);
}

/// A page of the admin user directory.
class ManageUserDirectoryPage {
  const ManageUserDirectoryPage({
    required this.users,
    required this.totalCount,
  });

  final List<ManageUserListItem> users;
  final int totalCount;
}

/// A single row in the admin user directory.
class ManageUserListItem {
  const ManageUserListItem({
    required this.id,
    required this.displayName,
    required this.status,
    required this.roles,
    required this.isAdmin,
    required this.onboardingCompleted,
    required this.createdAt,
    this.legalName,
    this.avatarPath,
    this.kycTier,
  });

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

/// The full posture of a single user (lifecycle, profile, roles, KYC,
/// verification summary) from `manage_user_get`.
class ManageUserDetail {
  const ManageUserDetail({
    required this.entity,
    required this.roles,
    required this.isAdmin,
    required this.summary,
    this.profile,
    this.kyc,
  });

  final ManageUserEntityCore entity;
  final ManageUserProfile? profile;
  final List<ManageUserRoleAssignment> roles;
  final ManageUserKycSummary? kyc;
  final bool isAdmin;
  final ManageUserVerificationSummary summary;
}

/// Entity core block of [ManageUserDetail].
class ManageUserEntityCore {
  const ManageUserEntityCore({
    required this.id,
    required this.status,
    required this.createdAt,
    this.capability,
    this.onboardingCompletedAt,
  });

  final String id;
  final String status;
  final String? capability;
  final DateTime? onboardingCompletedAt;
  final DateTime createdAt;
}

/// Profile block of [ManageUserDetail]. `null` when the entity has no profile.
class ManageUserProfile {
  const ManageUserProfile({
    this.displayName,
    this.legalName,
    this.bio,
    this.avatarPath,
    this.countryCode,
  });

  final String? displayName;
  final String? legalName;
  final String? bio;
  final String? avatarPath;
  final String? countryCode;
}

/// A single role assignment of [ManageUserDetail].
class ManageUserRoleAssignment {
  const ManageUserRoleAssignment({
    required this.role,
    required this.isActive,
    this.activatedAt,
  });

  final String role;
  final bool isActive;
  final DateTime? activatedAt;
}

/// Current KYC summary of [ManageUserDetail]. `null` when no KYC level exists.
class ManageUserKycSummary {
  const ManageUserKycSummary({this.tierCode, this.status, this.assignedAt});

  final String? tierCode;
  final String? status;
  final DateTime? assignedAt;
}

/// Verification summary counts of [ManageUserDetail].
class ManageUserVerificationSummary {
  const ManageUserVerificationSummary({
    this.credentialCount = 0,
    this.approvedCredentials = 0,
    this.pendingSubmissions = 0,
    this.totalSubmissions = 0,
  });

  final int credentialCount;
  final int approvedCredentials;
  final int pendingSubmissions;
  final int totalSubmissions;
}
