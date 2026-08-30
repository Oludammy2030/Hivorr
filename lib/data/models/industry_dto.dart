import 'package:hivorr/data/models/taxonomy_slug.dart';

/// Data Transfer Object mirroring the `industries` table (EP-01-06) as returned
/// inside the `taxonomy_industries_list` RPC `data` array.
///
/// Field names match the server column names exactly to avoid silent
/// deserialization drift. Optional fields tolerate `null`. The `slug` format
/// is validated defensively before mapping (server remains the authority).
class IndustryDto {
  const IndustryDto({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
    this.createdBy,
  });

  /// Factory parsing one `industries` row from the RPC envelope `data`.
  factory IndustryDto.fromJson(Map<String, dynamic> json) {
    final String slug = json['slug'] as String;
    if (!TaxonomySlug.isValid(slug)) {
      throw FormatException('Industry slug is not valid: "$slug"');
    }
    return IndustryDto(
      id: json['id'] as String,
      slug: slug,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
      sortOrder: json['sort_order'] as int,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  final String id;
  final String slug;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final String? createdBy;

  /// Serializes the full row shape (all keys present, nulls included) for
  /// cache round-trips and test diffs against the column contract.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'slug': slug,
        'name': name,
        'description': description,
        'is_active': isActive,
        'sort_order': sortOrder,
        'created_at': createdAt?.toIso8601String(),
        'created_by': createdBy,
      };
}
