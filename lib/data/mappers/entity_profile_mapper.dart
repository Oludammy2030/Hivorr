import 'package:hivorr/data/entities/entity_profile.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';

/// Transforms [EntityProfileDto] ↔ [EntityProfile].
///
/// The single transformation boundary between the transport DTO and the
/// pure-Dart domain entity (EP-01-08 §5.3). No I/O and no business logic.
class EntityProfileMapper {
  const EntityProfileMapper._();

  /// Maps a server DTO into the domain entity.
  static EntityProfile toEntity(EntityProfileDto dto) => EntityProfile(
    legalName: dto.legalName,
    displayName: dto.displayName,
    bio: dto.bio,
    avatarPath: dto.avatarPath,
    countryCode: dto.countryCode,
  );

  /// Maps a domain entity into a DTO bound to [entityId].
  static EntityProfileDto fromEntity(EntityProfile profile, String entityId) =>
      EntityProfileDto(
        entityId: entityId,
        legalName: profile.legalName,
        displayName: profile.displayName,
        bio: profile.bio,
        avatarPath: profile.avatarPath,
        countryCode: profile.countryCode,
      );
}
