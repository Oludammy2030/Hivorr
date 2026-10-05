import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Dense operational table for admin surfaces (VISUAL-IDENTITY.md §20).
///
/// Highest information density: a muted header row plus tappable data rows
/// separated by hairlines. Cells share one flex plan so columns align across
/// the header and every row. On narrow screens callers should keep cards
/// instead — this widget is for wide directory/queue views where tables
/// communicate better than cards (VISUAL-IDENTITY.md §15).
class HivorrDataTable extends StatelessWidget {
  const HivorrDataTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  /// Header labels, one per column.
  final List<HivorrDataColumn> columns;

  /// Data rows.
  final List<HivorrDataRow> rows;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: HivorrSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              for (final HivorrDataColumn column in columns)
                Expanded(
                  flex: column.flex,
                  child: Text(
                    column.label.toUpperCase(),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: colors.outline),
        for (final HivorrDataRow row in rows) ...<Widget>[
          InkWell(
            onTap: row.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HivorrSpacing.md,
                  vertical: HivorrSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    for (final HivorrDataCell cell in row.cells)
                      Expanded(flex: cell.flex, child: cell.child),
                  ],
                ),
              ),
            ),
          ),
          Container(height: 1, color: colors.outline.withValues(alpha: 0.5)),
        ],
      ],
    );
  }
}

/// Header column definition for [HivorrDataTable].
class HivorrDataColumn {
  const HivorrDataColumn(this.label, {this.flex = 1});

  final String label;
  final int flex;
}

/// Data row for [HivorrDataTable].
class HivorrDataRow {
  const HivorrDataRow({required this.cells, this.onTap});

  final List<HivorrDataCell> cells;
  final VoidCallback? onTap;
}

/// Single cell for [HivorrDataRow]. Flex must mirror the column plan.
class HivorrDataCell {
  const HivorrDataCell(this.child, {this.flex = 1});

  final Widget child;
  final int flex;
}
