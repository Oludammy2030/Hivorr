/// The fluid role vocabulary of a Universal Entity.
///
/// Mirrors the `entity_roles.role` CHECK vocabulary defined in EP-01-06
/// (`consumer`, `professional`, `merchant`, `rider`).
enum EntityRoleValue {
  consumer,
  professional,
  merchant,
  rider;

  /// Parses a server string into [EntityRoleValue], defaulting to [consumer].
  ///
  /// The server remains the authority on valid roles; this only maps stored
  /// values safely.
  static EntityRoleValue fromString(String value) =>
      EntityRoleValue.values.firstWhere(
        (EntityRoleValue e) => e.name == value,
        orElse: () => EntityRoleValue.consumer,
      );
}

/// Pure Dart domain model for a single role binding.
///
/// No framework or backend dependency; carries only data (EP-01-08 §5.3).
class EntityRole {
  const EntityRole({
    required this.role,
    required this.isActive,
    this.activatedAt,
  });

  /// The bound role.
  final EntityRoleValue role;

  /// Whether the role is currently active (fluid shift).
  final bool isActive;

  /// When the role was last activated, if known.
  final DateTime? activatedAt;
}
