import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';

/// Lifecycle status of a Universal Entity root record.
///
/// Mirrors the `entities.status` CHECK vocabulary defined in EP-01-06
/// (`active`, `suspended`, `deactivated`, `deleted`). The client only models
/// the values; all transitions are enforced server-side via RPC + RLS.
enum EntityStatus { active, suspended, deactivated, deleted }

/// Parsing helpers for [EntityStatus].
extension EntityStatusX on EntityStatus {
  /// Parses a server string into [EntityStatus], defaulting to [active].
  ///
  /// The server remains the authority; this only maps stored values safely.
  static EntityStatus fromString(String value) =>
      EntityStatus.values.firstWhere(
        (EntityStatus e) => e.name == value,
        orElse: () => EntityStatus.active,
      );

  /// The server-stored string representation.
  String get value => name;
}

/// The Universal Entity aggregate.
///
/// Pure Dart domain model (no Flutter/Supabase/Dio imports). Represents one
/// account operating with fluid, multi-role capability per the EP-01-06
/// Universal Entity model. Holds only data and getters — no business logic.
class Entity {
  const Entity({
    required this.id,
    required this.status,
    this.profile,
    this.roles = const <EntityRole>[],
  });

  /// The entity root identifier (matches `auth.users.id`).
  final String id;

  /// The lifecycle status of the root record.
  final EntityStatus status;

  /// The 1:1 financial-anchor profile, when loaded.
  final EntityProfile? profile;

  /// The active/known role bindings for this entity.
  final List<EntityRole> roles;
}
