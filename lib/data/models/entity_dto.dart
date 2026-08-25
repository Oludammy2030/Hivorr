/// Data Transfer Object mirroring the `entities` root table (EP-01-06).
///
/// Field names match the server column names exactly. Used to model the
/// aggregate root in the reference slice.
class EntityDto {
  const EntityDto({
    required this.id,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory parsing a self-scoped PostgREST row.
  factory EntityDto.fromJson(Map<String, dynamic> json) => EntityDto(
    id: json['id'] as String,
    status: json['status'] as String,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
  );

  final String id;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Serializes the minimal root fields.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'status': status,
  };
}
