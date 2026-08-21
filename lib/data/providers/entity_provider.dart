import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';
import 'package:hivorr/data/repositories/entity_repository.dart';

/// Lifecycle states exposed by [EntityProvider].
enum EntityProviderState {
  /// No operation has been performed yet.
  idle,

  /// An operation is in flight.
  loading,

  /// The last operation succeeded.
  loaded,

  /// The last operation failed (see [EntityProvider.error]).
  error,
}

/// Provider exposing entity data state to the widget tree.
///
/// Depends only on the [EntityRepository] abstraction and surfaces a single
/// [ApiException] on failure. No Supabase/Dio imports (EP-01-08 §5.7).
class EntityProvider extends ChangeNotifier {
  /// Creates the provider bound to [repository].
  EntityProvider({required this.repository});

  /// The repository backing this provider.
  final EntityRepository repository;

  EntityProviderState _state = EntityProviderState.idle;
  EntityProfile? _profile;
  List<EntityRole> _roles = <EntityRole>[];
  ApiException? _error;

  /// Current lifecycle state.
  EntityProviderState get state => _state;

  /// The latest loaded profile, if any.
  EntityProfile? get profile => _profile;

  /// The latest loaded role bindings.
  List<EntityRole> get roles => _roles;

  /// The latest error, if [state] is [EntityProviderState.error].
  ApiException? get error => _error;

  /// Loads the profile for [entityId].
  Future<void> loadProfile(String entityId) => _run(
        () async => _profile = await repository.getProfile(entityId),
      );

  /// Loads the role bindings for [entityId].
  Future<void> loadRoles(String entityId) => _run(
        () async => _roles = await repository.getRoles(entityId),
      );

  /// Updates the profile and refreshes local state.
  Future<void> updateProfile({
    required String entityId,
    required String legalName,
    required String displayName,
    String? bio,
  }) =>
      _run(
        () async =>           _profile = await repository.updateProfile(
          entityId: entityId,
          legalName: legalName,
          displayName: displayName,
          bio: bio,
        ),
      );

  /// Activates a role and refreshes the role list.
  Future<void> activateRole({
    required String entityId,
    required String role,
  }) =>
      _run(
        () async {
          await repository.activateRole(entityId: entityId, role: role);
          _roles = await repository.getRoles(entityId);
        },
      );

  Future<void> _run(Future<void> Function() action) async {
    _state = EntityProviderState.loading;
    _error = null;
    notifyListeners();
    try {
      await action();
      _state = EntityProviderState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _state = EntityProviderState.error;
    }
    notifyListeners();
  }
}
