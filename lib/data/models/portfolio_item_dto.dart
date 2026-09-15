/// DTO for a portfolio work-sample item returned by
/// `portfolio_public_profile_get` (EP-02-19).
///
/// Maps the snake_case JSON keys from the RPC projection exactly.
class PortfolioItemDto {
  const PortfolioItemDto({
    required this.id,
    this.itemType,
    this.title,
    this.description,
    this.mediaPath,
    this.sortOrder,
  });

  factory PortfolioItemDto.fromJson(Map<String, dynamic> json) =>
      PortfolioItemDto(
        id: json['id'] as String,
        itemType: json['item_type'] as String?,
        title: json['title'] as String?,
        description: json['description'] as String?,
        mediaPath: json['media_path'] as String?,
        sortOrder: json['sort_order'] as int?,
      );

  final String id;
  final String? itemType;
  final String? title;
  final String? description;
  final String? mediaPath;
  final int? sortOrder;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (itemType != null) 'item_type': itemType,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (mediaPath != null) 'media_path': mediaPath,
    if (sortOrder != null) 'sort_order': sortOrder,
  };
}
