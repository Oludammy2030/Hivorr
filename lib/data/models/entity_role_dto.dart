/// Data Transfer Object mirroring the `entity_roles` table (EP-01-06).
///
/// Field names match the server column names exactly.
class EntityRoleDto {
  const EntityRoleDto({
    required this.entityId,
    required this.role,
    required this.isActive,
    this.activatedAt,
  });

  /// Factory parsing a self-scoped PostgREST row.
  factory EntityRoleDto.fromJson(Map<String, dynamic> json) => EntityRoleDto(
        entityId: json['entity_id'] as String,
        role: json['role'] as String,
        isActive: json['is_active'] as bool,
        activatedAt: json['activated_at'] == null
            ? null
            : DateTime.parse(json['activated_at'] as String),
      );

  final String entityId;
  final String role;
  final bool isActive;
  final DateTime? activatedAt;

  /// Serializes the binding for payloads.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'entity_id': entityId,
        'role': role,
        'is_active': isActive,
        if (activatedAt != null) 'activated_at': activatedAt!.toIso8601String(),
      };
}
