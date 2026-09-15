/// DTO for a public profession badge returned by `portfolio_public_profile_get`.
///
/// Maps the snake_case JSON keys from the RPC projection exactly.
class PublicProfessionDto {
  const PublicProfessionDto({
    required this.id,
    required this.professionId,
    required this.isPrimary,
    required this.professionSlug,
    required this.professionName,
    required this.industrySlug,
    required this.industryName,
  });

  factory PublicProfessionDto.fromJson(Map<String, dynamic> json) =>
      PublicProfessionDto(
        id: json['id'] as String,
        professionId: json['profession_id'] as String,
        isPrimary: json['is_primary'] as bool? ?? false,
        professionSlug: json['profession_slug'] as String? ?? '',
        professionName: json['profession_name'] as String? ?? '',
        industrySlug: json['industry_slug'] as String? ?? '',
        industryName: json['industry_name'] as String? ?? '',
      );

  final String id;
  final String professionId;
  final bool isPrimary;
  final String professionSlug;
  final String professionName;
  final String industrySlug;
  final String industryName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'profession_id': professionId,
    'is_primary': isPrimary,
    'profession_slug': professionSlug,
    'profession_name': professionName,
    'industry_slug': industrySlug,
    'industry_name': industryName,
  };
}
