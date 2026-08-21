import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';

/// Abstract contract for the remote (Supabase) side of entity data.
///
/// Implementations must access the backend only through the EP-01-07
/// `BaseApiService` channel — never constructing clients directly
/// (EP-01-08 §5.4).
abstract class EntityRemoteDataSource {
  /// Fetches the self-scoped profile for [entityId], or `null` if absent.
  Future<EntityProfileDto?> getProfile(String entityId);

  /// Updates the profile via the EP-01-06 `entity_profile_update` RPC.
  Future<EntityProfileDto> updateProfile({
    required String entityId,
    required String legalName,
    required String displayName,
    String? bio,
  });

  /// Activates a role via the EP-01-06 `entity_roles_activate` RPC.
  Future<void> activateRole({
    required String entityId,
    required String role,
  });

  /// Fetches the self-scoped role bindings for [entityId].
  Future<List<EntityRoleDto>> getRoles(String entityId);
}
