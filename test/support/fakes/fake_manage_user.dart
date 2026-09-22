// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';

/// In-memory [ManageUserRepository] for provider/widget tests.
///
/// Surfaces scripted directory rows + a single-user posture with call
/// counters; set [nextError] to exercise failure paths exactly as the real RPC
/// layer throws [ApiException]. Admin gating stays with the separate
/// [FakeAdminReviewRepository] — this fake never checks admin status.
class FakeManageUserRepository implements ManageUserRepository {
  FakeManageUserRepository({
    List<ManageUserListItem>? users,
    ManageUserDetail? detail,
    ApiException? nextError,
  }) : _users = users ?? const <ManageUserListItem>[],
       _detail = detail,
       nextError = nextError;

  List<ManageUserListItem> _users;
  ManageUserDetail? _detail;

  ApiException? nextError;
  int listCallCount = 0;
  int detailCallCount = 0;
  int setStatusCallCount = 0;
  int resetCallCount = 0;
  String? lastQueriedStatus;
  String? lastQueriedCapability;
  String? lastStatusChange;
  String? lastResetId;

  /// Mutates the directory rows the fake serves.
  void setUsers(List<ManageUserListItem> users) => _users = users;

  /// Mutates the detail the fake serves.
  void setDetail(ManageUserDetail detail) => _detail = detail;

  @override
  Future<ManageUserDirectoryPage> listUsers({
    String? search,
    String? status,
    String? capability,
    int offset = 0,
    int limit = 20,
  }) async {
    listCallCount++;
    lastQueriedStatus = status;
    lastQueriedCapability = capability;
    if (nextError != null) throw _consumeError();
    Iterable<ManageUserListItem> filtered = _users;
    if (capability != null) {
      filtered = filtered.where((ManageUserListItem u) {
        if (capability == 'professional') {
          return u.capability == 'offer' || u.capability == 'both';
        }
        if (capability == 'client') {
          return u.capability == 'hire' || u.capability == 'both';
        }
        return u.capability == capability;
      });
    }
    if (search != null && search.isNotEmpty) {
      final String term = search.toLowerCase();
      filtered = filtered.where(
        (ManageUserListItem u) =>
            u.displayName.toLowerCase().contains(term) ||
            (u.legalName?.toLowerCase().contains(term) ?? false),
      );
    }
    if (status != null) {
      filtered = filtered.where((ManageUserListItem u) => u.status == status);
    }
    final List<ManageUserListItem> list = filtered.toList(growable: false);
    final int start = offset.clamp(0, list.length);
    final int end = (offset + limit).clamp(start, list.length);
    return ManageUserDirectoryPage(
      users: list.sublist(start, end),
      totalCount: list.length,
    );
  }

  @override
  Future<ManageUserDetail> getUser(String userId) async {
    detailCallCount++;
    if (nextError != null) throw _consumeError();
    final ManageUserDetail? detail = _detail;
    if (detail == null || detail.entity.id != userId) {
      throw const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'User not found.',
        code: 'PLT004',
      );
    }
    return detail;
  }

  @override
  Future<void> setUserStatus(String userId, String status) async {
    setStatusCallCount++;
    lastStatusChange = status;
    if (nextError != null) throw _consumeError();
    _users = _users
        .map((ManageUserListItem e) {
          if (e.id != userId) return e;
          return ManageUserListItem(
            id: e.id,
            displayName: e.displayName,
            legalName: e.legalName,
            avatarPath: e.avatarPath,
            status: status,
            capability: e.capability,
            roles: e.roles,
            kycTier: e.kycTier,
            isAdmin: e.isAdmin,
            onboardingCompleted: e.onboardingCompleted,
            createdAt: e.createdAt,
          );
        })
        .toList(growable: false);
    final ManageUserDetail? detail = _detail;
    if (detail != null && detail.entity.id == userId) {
      _detail = ManageUserDetail(
        entity: ManageUserEntityCore(
          id: detail.entity.id,
          status: status,
          capability: detail.entity.capability,
          onboardingCompletedAt: detail.entity.onboardingCompletedAt,
          createdAt: detail.entity.createdAt,
        ),
        profile: detail.profile,
        roles: detail.roles,
        kyc: detail.kyc,
        isAdmin: detail.isAdmin,
        summary: detail.summary,
      );
    }
  }

  @override
  Future<void> resetOnboarding(String userId) async {
    resetCallCount++;
    lastResetId = userId;
    if (nextError != null) throw _consumeError();
    final ManageUserDetail? detail = _detail;
    if (detail != null && detail.entity.id == userId) {
      _detail = ManageUserDetail(
        entity: ManageUserEntityCore(
          id: detail.entity.id,
          status: detail.entity.status,
          capability: null,
          onboardingCompletedAt: null,
          createdAt: detail.entity.createdAt,
        ),
        profile: detail.profile,
        roles: detail.roles,
        kyc: detail.kyc,
        isAdmin: detail.isAdmin,
        summary: detail.summary,
      );
    }
  }

  ApiException _consumeError() {
    final ApiException e = nextError!;
    nextError = null;
    return e;
  }
}

/// A directory row fixture with the given id.
ManageUserListItem manageUserListItem({
  String id = 'u1',
  String displayName = 'Test User',
  String? legalName,
  String? avatarPath,
  String status = 'active',
  String? capability = 'hire',
  List<String> roles = const <String>['freelancer'],
  String? kycTier = 'tier_1',
  bool isAdmin = false,
  bool onboardingCompleted = true,
  DateTime? createdAt,
}) => ManageUserListItem(
  id: id,
  displayName: displayName,
  legalName: legalName,
  avatarPath: avatarPath,
  status: status,
  capability: capability,
  roles: roles,
  kycTier: kycTier,
  isAdmin: isAdmin,
  onboardingCompleted: onboardingCompleted,
  createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
);

/// A full posture fixture for [ManageUserDetail].
ManageUserDetail manageUserDetail({
  String id = 'u1',
  String status = 'active',
  String? capability = 'full_trading',
  bool? onboardingCompleted = true,
  String displayName = 'Test User',
  List<ManageUserRoleAssignment> roles = const <ManageUserRoleAssignment>[],
  ManageUserKycSummary? kyc = const ManageUserKycSummary(
    tierCode: 'tier_1',
    status: 'verified',
  ),
  bool isAdmin = false,
  ManageUserVerificationSummary summary = const ManageUserVerificationSummary(
    credentialCount: 2,
  ),
}) => ManageUserDetail(
  entity: ManageUserEntityCore(
    id: id,
    status: status,
    capability: capability,
    onboardingCompletedAt: (onboardingCompleted ?? false)
        ? DateTime.fromMillisecondsSinceEpoch(2000)
        : null,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
  ),
  profile: ManageUserProfile(
    displayName: displayName,
    legalName: 'Legal $displayName',
    bio: 'Sample bio',
    countryCode: 'US',
  ),
  roles: roles,
  kyc: kyc,
  isAdmin: isAdmin,
  summary: summary,
);
