import 'package:hivorr/data/entities/entity.dart';
import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/entities/entity_role.dart';
import 'package:hivorr/data/models/entity_dto.dart';

/// Assembles the [Entity] aggregate from its component DTOs.
///
/// Reference-slice aggregator only; no business logic (EP-01-08 §5.3).
class EntityMapper {
  const EntityMapper._();

  /// Builds the aggregate from the root DTO plus optional profile/roles.
  static Entity toEntity({
    required EntityDto dto,
    EntityProfile? profile,
    List<EntityRole> roles = const <EntityRole>[],
  }) =>
      Entity(
        id: dto.id,
        status: EntityStatusX.fromString(dto.status),
        profile: profile,
        roles: roles,
      );
}
