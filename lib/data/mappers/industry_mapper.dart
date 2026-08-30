import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/models/industry_dto.dart';

/// Transforms [IndustryDto] ↔ [Industry].
///
/// The single transformation boundary between the transport DTO and the
/// pure-Dart domain entity (EP-01-08 §5.3). No I/O and no business logic.
class IndustryMapper {
  const IndustryMapper._();

  /// Maps a server DTO into the domain entity.
  static Industry toEntity(IndustryDto dto) => Industry(
    id: dto.id,
    slug: dto.slug,
    name: dto.name,
    description: dto.description,
    isActive: dto.isActive,
    sortOrder: dto.sortOrder,
    createdAt: dto.createdAt,
  );

  /// Maps a domain entity into a DTO (used for cache/test round-trips).
  static IndustryDto fromEntity(Industry entity) => IndustryDto(
    id: entity.id,
    slug: entity.slug,
    name: entity.name,
    description: entity.description,
    isActive: entity.isActive,
    sortOrder: entity.sortOrder,
    createdAt: entity.createdAt,
    createdBy: null,
  );
}
