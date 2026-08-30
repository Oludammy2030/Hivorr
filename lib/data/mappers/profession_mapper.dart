import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/models/profession_dto.dart';

/// Transforms [ProfessionDto] ↔ [Profession].
///
/// The single transformation boundary between the transport DTO and the
/// pure-Dart domain entity (EP-01-08 §5.3). No I/O and no business logic.
class ProfessionMapper {
  const ProfessionMapper._();

  /// Maps a server DTO into the domain entity.
  static Profession toEntity(ProfessionDto dto) => Profession(
    id: dto.id,
    industryId: dto.industryId,
    slug: dto.slug,
    name: dto.name,
    description: dto.description,
    isActive: dto.isActive,
    sortOrder: dto.sortOrder,
    createdAt: dto.createdAt,
  );

  /// Maps a domain entity into a DTO (used for cache/test round-trips).
  static ProfessionDto fromEntity(Profession entity) => ProfessionDto(
    id: entity.id,
    industryId: entity.industryId,
    slug: entity.slug,
    name: entity.name,
    description: entity.description,
    isActive: entity.isActive,
    sortOrder: entity.sortOrder,
    createdAt: entity.createdAt,
    createdBy: null,
  );
}
