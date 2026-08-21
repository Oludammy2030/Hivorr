import 'package:hivorr/data/entities/entity_role.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';

/// Transforms [EntityRoleDto] ↔ [EntityRole].
///
/// The single transformation boundary for role bindings (EP-01-08 §5.3).
/// Vocabulary parsing is delegated to [EntityRoleValue]; the server remains
/// the authority on valid roles.
class EntityRoleMapper {
  const EntityRoleMapper._();

  /// Maps a server DTO into the domain entity.
  static EntityRole toEntity(EntityRoleDto dto) => EntityRole(
        role: EntityRoleValue.fromString(dto.role),
        isActive: dto.isActive,
        activatedAt: dto.activatedAt,
      );

  /// Maps a domain entity into a DTO bound to [entityId].
  static EntityRoleDto fromEntity(EntityRole role, String entityId) =>
      EntityRoleDto(
        entityId: entityId,
        role: role.role.name,
        isActive: role.isActive,
        activatedAt: role.activatedAt,
      );
}
