/// Data Transfer Object mirroring the `professions` table (EP-02-01).
///
/// Field names are camelCase in Dart but map the server snake_case columns
/// exactly via [fromJson] (including `industry_id → industryId`). `toJson`
/// round-trips for the local cache. Optional fields tolerate `null`.
///
/// See also: EP-02-07 implementation plan §5.2, §7.2.
class ProfessionDto {
  const ProfessionDto({
    required this.id,
    required this.industryId,
    required this.slug,
    required this.name,
    this.description,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
  });

  /// Parses a single `professions` row returned by the RPC envelope.
  factory ProfessionDto.fromJson(Map<String, dynamic> json) => ProfessionDto(
    id: json['id'] as String,
    industryId: json['industry_id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    isActive: json['is_active'] as bool? ?? false,
    sortOrder: json['sort_order'] as int? ?? 0,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String industryId;
  final String slug;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;

  /// Serializes the DTO back to snake_case keyed JSON for local caching.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'industry_id': industryId,
    'slug': slug,
    'name': name,
    if (description != null) 'description': description,
    'is_active': isActive,
    'sort_order': sortOrder,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}
