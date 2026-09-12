import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';

/// Abstract contract for entity data operations.
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface, not the Supabase
/// implementation. This abstraction is the vendor-lock-in mitigation required
/// by ARCHITECTURE.md and the EP-01 phase plan (EP-01-08 §5.6).
abstract class EntityRepository {
  /// Returns the entity profile, preferring cache then remote.
  Future<EntityProfile> getProfile(String entityId);

  /// Updates the profile via the server and returns the mapped result.
  Future<EntityProfile> updateProfile({
    required String entityId,
    required String legalName,
    required String displayName,
    String? bio,
  });

  /// Activates a role for the entity (fluid shift).
  Future<void> activateRole({
    required String entityId,
    required String role,
  });

  /// Returns the entity's role bindings.
  Future<List<EntityRole>> getRoles(String entityId);

  /// Binds the entity to a profession via `entity_profession_bind`.
  ///
  /// The server validates existence/active state (`PLT004`), rejects duplicate
  /// bindings (`PLT005`), and lands `trade_verification_status = unverified`.
  Future<void> bindProfession({required String professionId});

  /// Persists a Storage-uploaded avatar path via the self-scoped REST update.
  ///
  /// Returns the refreshed profile (cache refreshed).
  Future<EntityProfile> updateAvatarPath({
    required String entityId,
    required String avatarPath,
  });
}
