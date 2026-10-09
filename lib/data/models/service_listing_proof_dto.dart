import 'package:hivorr/data/models/portfolio_item_dto.dart';

/// DTO for a linked proof row returned by `service_listing_portfolio_list`
/// (EP-03-15).
///
/// Extends the [PortfolioItemDto] showcase columns with `link_sort_order`
/// (per-listing curation position). Maps the snake_case JSON keys from the
/// whitelisted RPC projection exactly.
class ServiceListingProofDto {
  const ServiceListingProofDto({required this.item, this.linkSortOrder});

  factory ServiceListingProofDto.fromJson(Map<String, dynamic> json) =>
      ServiceListingProofDto(
        item: PortfolioItemDto.fromJson(json),
        linkSortOrder: json['link_sort_order'] as int?,
      );

  /// The linked portfolio item columns.
  final PortfolioItemDto item;

  /// Per-listing curation position (`link_sort_order`).
  final int? linkSortOrder;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...item.toJson(),
    if (linkSortOrder != null) 'link_sort_order': linkSortOrder,
  };
}
