/// Data Transfer Object mirroring the `entity_profiles` table (EP-01-06).
///
/// Field names match the server column names exactly to avoid silent
/// deserialization drift. Optional fields tolerate `null`.
class EntityProfileDto {
  const EntityProfileDto({
    required this.entityId,
    required this.legalName,
    required this.displayName,
    this.bio,
    this.avatarPath,
    this.countryCode,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  /// Factory parsing a self-scoped PostgREST row.
  factory EntityProfileDto.fromJson(Map<String, dynamic> json) =>
      EntityProfileDto(
        entityId: json['entity_id'] as String,
        legalName: json['legal_name'] as String,
        displayName: json['display_name'] as String,
        bio: json['bio'] as String?,
        avatarPath: json['avatar_path'] as String?,
        countryCode: json['country_code'] as String?,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.parse(json['updated_at'] as String),
        createdBy: json['created_by'] as String?,
      );

  final String entityId;
  final String legalName;
  final String displayName;
  final String? bio;
  final String? avatarPath;
  final String? countryCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  /// Serializes the mutable fields for RPC/update payloads.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'entity_id': entityId,
    'legal_name': legalName,
    'display_name': displayName,
    if (bio != null) 'bio': bio,
    if (avatarPath != null) 'avatar_path': avatarPath,
    if (countryCode != null) 'country_code': countryCode,
  };
}
