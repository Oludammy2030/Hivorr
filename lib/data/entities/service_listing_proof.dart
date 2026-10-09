import 'package:hivorr/data/entities/portfolio_item.dart';

/// A portfolio work sample linked to a service listing as proof-of-work
/// (EP-03-15).
///
/// Wraps the reused [PortfolioItem] (entity-scoped showcase fields) with the
/// per-listing curation order from `service_listing_portfolio_links.sort_order`
/// ([linkSortOrder]). The link order — not the item's own `sortOrder` — is the
/// ordering authority for listing detail; consumers render it verbatim and
/// never re-sort. Pure Dart, no Flutter/Supabase imports.
class LinkedPortfolioItem {
  const LinkedPortfolioItem({required this.item, this.linkSortOrder});

  /// The linked work sample (whitelisted showcase fields only).
  final PortfolioItem item;

  /// Per-listing curation position (`link_sort_order` from the list RPC).
  final int? linkSortOrder;
}
