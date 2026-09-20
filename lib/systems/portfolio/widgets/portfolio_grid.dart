import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/portfolio/widgets/portfolio_item_card.dart';

/// Responsive showcase grid for portfolio work samples (EP-02-19 §5.6,
/// DoD FV-16/FV-25).
///
/// Reorders items by `sort_order` (nulls last, stable), then lays them out as a
/// single column on mobile (< 600dp), two columns on tablet (600–1023dp) and
/// three on desktop (≥ 1024dp) — mirroring the `shared/layouts/breakpoints.dart`
/// phone → side-rail hierarchy. Renders an empty placeholder when the list is
/// empty so the section header can stay consistent.
class PortfolioGrid extends StatelessWidget {
  const PortfolioGrid({super.key, required this.items, this.mediaUrlBuilder});

  /// Work samples in server order (already `sort_order`-sorted); re-sorted
  /// defensively to guarantee stable nulls-last ordering.
  final List<PortfolioItem> items;

  /// Resolves a public media URL for [item], or `null` for the placeholder.
  final String? Function(PortfolioItem item)? mediaUrlBuilder;

  /// Gap between grid tiles.
  static const double _gap = HivorrSpacing.md;

  /// Columns per width band (mirrors [Breakpoint]).
  static const Map<String, int> _columnsByBand = <String, int>{
    'mobile': 1,
    'tablet': 2,
    'desktop': 3,
  };

  @override
  Widget build(BuildContext context) {
    final List<PortfolioItem> ordered = _sorted(items);
    if (ordered.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = _columnsForWidth(constraints.maxWidth);
        final double tileWidth =
            (constraints.maxWidth - (_gap * (columns - 1))) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: <Widget>[
            for (final PortfolioItem item in ordered)
              SizedBox(
                width: tileWidth,
                child: PortfolioItemCard(
                  item: item,
                  mediaUrl: mediaUrlBuilder?.call(item),
                ),
              ),
          ],
        );
      },
    );
  }

  static int _columnsForWidth(double maxWidth) {
    if (maxWidth < 600) return _columnsByBand['mobile']!;
    if (maxWidth < 1024) return _columnsByBand['tablet']!;
    return _columnsByBand['desktop']!;
  }

  /// Stable sort — `sort_order` ascending with nulls last.
  static List<PortfolioItem> _sorted(List<PortfolioItem> source) {
    final List<PortfolioItem> copy = List<PortfolioItem>.of(source);
    copy.sort((PortfolioItem a, PortfolioItem b) {
      final int? aOrder = a.sortOrder;
      final int? bOrder = b.sortOrder;
      if (aOrder == null && bOrder == null) return 0;
      if (aOrder == null) return 1;
      if (bOrder == null) return -1;
      return aOrder.compareTo(bOrder);
    });
    return copy;
  }
}
