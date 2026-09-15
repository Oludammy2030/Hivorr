/// Pure Dart domain model for a portfolio work-sample item (EP-02-19).
///
/// Mirrors the `portfolio_items` table columns projected by the
/// `portfolio_public_profile_get` RPC. Contains only whitelisted fields —
/// never `entity_id` or `created_by`.
class PortfolioItem {
  const PortfolioItem({
    required this.id,
    this.itemType,
    this.title,
    this.description,
    this.mediaPath,
    this.sortOrder,
  });

  /// Primary key (UUID).
  final String id;

  /// Optional type vocabulary: `image`, `video`, `document`, `link`.
  final String? itemType;

  /// Optional display title.
  final String? title;

  /// Optional description text.
  final String? description;

  /// Optional storage object path under `portfolio-items/{entityId}/`.
  final String? mediaPath;

  /// Display order, nulls last.
  final int? sortOrder;
}
