/// Data Transfer Object mirroring the `industries` table (EP-02-01).
///
/// Field names are camelCase in Dart but map the server snake_case columns
/// exactly via [fromJson] to avoid silent deserialization drift. `toJson`
/// round-trips for the local cache. Optional fields tolerate `null`.
///
/// See also: EP-02-07 implementation plan §5.2, §7.1.
class IndustryDto {
  const IndustryDto({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
  });

  /// Parses a single `industries` row returned by the RPC envelope.
  factory IndustryDto.fromJson(Map<String, dynamic> json) => IndustryDto(
    id: json['id'] as String,
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
  final String slug;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;

  /// Serializes the DTO back to snake_case keyed JSON for local caching.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'slug': slug,
    'name': name,
    if (description != null) 'description': description,
    'is_active': isActive,
    'sort_order': sortOrder,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}
