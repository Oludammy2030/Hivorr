import 'package:hivorr/data/models/manage_user_dto.dart';

/// Abstract contract for the remote (Supabase) side of Manage User operations
/// (EP-02-11 §5.2).
///
/// Implementations access the backend only through the EP-01-07
/// [BaseApiService] channel and the manage-user RPCs. Admin authorization is
/// server-enforced (`is_platform_admin()`); the client never caches or trusts
/// the admin flag beyond the current session.
abstract class ManageUserRemoteDataSource {
  /// Returns a paginated directory page of users.
  ///
  /// Backed by `manage_user_list`. [search] filters case-insensitively on
  /// display/legal name; [status] filters on the entity lifecycle status
  /// (`active | suspended | deactivated | deleted`). Pagination via
  /// [offset]/[limit] (1..100). Throws [ApiException] `PLT002` for non-admin
  /// callers.
  Future<ManageUserListEnvelopeDto> listUsers({
    String? search,
    String? status,
    int offset = 0,
    int limit = 20,
  });

  /// Returns the full posture for a single user.
  ///
  /// Backed by `manage_user_get`. Throws [ApiException] `PLT004` when the
  /// target does not exist.
  Future<ManageUserDetailDto> getUser(String userId);

  /// Sets an entity lifecycle status (`active | suspended | deactivated`).
  ///
  /// Backed by `manage_user_set_status`. Lockout guards are server-enforced
  /// (`PLT005`: cannot self-suspend or suspend a platform admin).
  Future<void> setUserStatus(String userId, String status);

  /// Resets onboarding (clears capability + completion stamp) for a user.
  ///
  /// Backed by `manage_user_reset_onboarding`. Mirrors the service-role reset
  /// for the authenticated admin path.
  Future<void> resetOnboarding(String userId);
}
