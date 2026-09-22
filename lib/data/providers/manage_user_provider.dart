// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';

/// Provider exposing Manage User (admin console) state to the widget tree
/// (EP-02-11 §5.5).
///
/// Depends only on the [ManageUserRepository] abstraction. Owns the directory
/// list (search + status filters + pagination), the selected user's posture,
/// and the lifecycle actions (suspend/reactivate/deactivate + onboarding
/// reset). UI consumes this provider, never the repository directly.
///
/// Admin gating is shared with the EP-02-11 review console: the router guard
/// and screens use [AdminGate.isAdmin] over the [AdminReviewProvider] —
/// this provider never makes an admin check of its own.
class ManageUserProvider extends ChangeNotifier {
  ManageUserProvider({required ManageUserRepository repo, HivorrLogger? logger})
    : _repo = repo,
      _logger = logger;

  final ManageUserRepository _repo;
  final HivorrLogger? _logger;

  List<ManageUserListItem> _users = const <ManageUserListItem>[];
  int _totalCount = 0;
  ManageUserDetail? _selectedUser;
  ApiException? _error;
  bool _loading = false;
  bool _loadingDetail = false;
  bool _acting = false;
  int _currentOffset = 0;
  bool _hasMore = true;
  String? _search;
  String? _status;
  String? _capability;
  bool _listHydrated = false;
  static const int _pageSize = 20;

  /// The current user directory page(s).
  List<ManageUserListItem> get users => _users;

  /// Total matches across all pages (server `total_count`).
  int get totalCount => _totalCount;

  /// The currently selected user's full posture (detail view).
  ManageUserDetail? get selectedUser => _selectedUser;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Whether the directory is currently loading.
  bool get isLoading => _loading;

  /// Whether the selected user's detail is currently loading.
  bool get isLoadingDetail => _loadingDetail;

  /// Whether a lifecycle action is in flight.
  bool get isActing => _acting;

  /// Whether more pages are available.
  bool get hasMore => _hasMore;

  /// The active search term applied to the last [loadUsers] call.
  String? get search => _search;

  /// The active status filter applied to the last [loadUsers] call.
  String? get statusFilter => _status;

  /// The active capability filter applied to the last [loadUsers] call.
  /// `null` = All Users, `professional` = offer+both, `client` = hire+both.
  String? get capabilityFilter => _capability;

  /// Whether the directory has been fetched at least once.
  bool get isListHydrated => _listHydrated;

  /// Fetches the first page of the directory (resets pagination).
  ///
  /// [search]/[status]/[capability] change the active filter; pass `null` to
  /// clear. `capability` values: `hire|offer|both|professional|client`.
  Future<void> loadUsers({
    String? search,
    String? status,
    String? capability,
  }) async {
    _loading = true;
    _error = null;
    _search = search;
    _status = status;
    _capability = capability;
    _currentOffset = 0;
    _hasMore = true;
    _listHydrated = true;
    notifyListeners();
    try {
      final ManageUserDirectoryPage page = await _repo.listUsers(
        search: search,
        status: status,
        capability: capability,
        limit: _pageSize,
        offset: 0,
      );
      _users = page.users;
      _totalCount = page.totalCount;
      _hasMore = page.users.length >= _pageSize;
      _currentOffset = page.users.length;
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Manage user directory load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Appends the next page to the directory.
  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    notifyListeners();
    try {
      final ManageUserDirectoryPage page = await _repo.listUsers(
        search: _search,
        status: _status,
        capability: _capability,
        limit: _pageSize,
        offset: _currentOffset,
      );
      _users = [..._users, ...page.users];
      _totalCount = page.totalCount;
      _hasMore = page.users.length >= _pageSize;
      _currentOffset += page.users.length;
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Manage user load-more failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads the full posture for a single user.
  Future<void> loadDetail(String userId) async {
    _loadingDetail = true;
    _error = null;
    notifyListeners();
    try {
      _selectedUser = await _repo.getUser(userId);
    } on ApiException catch (e) {
      _error = e;
      _selectedUser = null;
    } finally {
      _loadingDetail = false;
      notifyListeners();
    }
  }

  /// Sets an entity lifecycle status and mirrors the change into the cached
  /// directory row + selected user.
  Future<void> setUserStatus(String userId, String status) async {
    _acting = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.setUserStatus(userId, status);
      _users = _users
          .map((ManageUserListItem e) {
            if (e.id == userId) return _copyUserWithStatus(e, status);
            return e;
          })
          .toList(growable: false);
      final ManageUserDetail? selected = _selectedUser;
      if (selected != null && selected.entity.id == userId) {
        _selectedUser = _copyDetailWithStatus(selected, status);
      }
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Manage user set-status failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  /// Resets onboarding for a user and mirrors the change into the cached
  /// selected user (capability + completion stamp cleared).
  Future<void> resetOnboarding(String userId) async {
    _acting = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.resetOnboarding(userId);
      final ManageUserDetail? selected = _selectedUser;
      if (selected != null && selected.entity.id == userId) {
        _selectedUser = ManageUserDetail(
          entity: ManageUserEntityCore(
            id: selected.entity.id,
            status: selected.entity.status,
            capability: null,
            onboardingCompletedAt: null,
            createdAt: selected.entity.createdAt,
          ),
          profile: selected.profile,
          roles: selected.roles,
          kyc: selected.kyc,
          isAdmin: selected.isAdmin,
          summary: selected.summary,
        );
      }
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Manage user reset-onboarding failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  ManageUserListItem _copyUserWithStatus(
    ManageUserListItem user,
    String status,
  ) {
    return ManageUserListItem(
      id: user.id,
      displayName: user.displayName,
      legalName: user.legalName,
      avatarPath: user.avatarPath,
      status: status,
      capability: user.capability,
      roles: user.roles,
      kycTier: user.kycTier,
      isAdmin: user.isAdmin,
      onboardingCompleted: user.onboardingCompleted,
      createdAt: user.createdAt,
    );
  }

  ManageUserDetail _copyDetailWithStatus(
    ManageUserDetail detail,
    String status,
  ) {
    return ManageUserDetail(
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
