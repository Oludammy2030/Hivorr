import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Single month value for [HivorrMonthBars]. Pass only numbers the backend
/// actually returned — never invented series (no mock-data rule).
class HivorrMonthDatum {
  const HivorrMonthDatum({required this.label, required this.value});

  /// Short month label (e.g. `Jan`). Rendered under its bar.
  final String label;
  final int value;
}

/// Vertical month bars with labeled axes (VISUAL-IDENTITY.md §§15b, 21).
///
/// Real numbers only: bars normalize to the series max, the final (current)
/// bar carries the accent fill while earlier bars use the accent tint, and
/// every bar is labeled with its month + value. When [items] is empty — or
/// every value is zero — renders the honest [emptyLabel] as plain text (the
/// caller owns the surrounding card, so no nested card is produced).
class HivorrMonthBars extends StatelessWidget {
  const HivorrMonthBars({
    super.key,
    required this.items,
    this.emptyLabel = 'No activity yet.',
    this.accent,
    this.height = 120,
  });

  final List<HivorrMonthDatum> items;
  final String emptyLabel;
  final Color? accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final int max = items.fold<int>(
      0,
      (int m, HivorrMonthDatum d) => d.value > m ? d.value : m,
    );
    if (items.isEmpty || max <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.md),
        child: Text(
          emptyLabel,
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }
    final Color barColor = accent ?? colors.primary;
    final Color barTint = barColor.withValues(alpha: 0.18);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : HivorrSpacing.xs / 2,
                      right: i == items.length - 1 ? 0 : HivorrSpacing.xs / 2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Text(
                          '${items[i].value}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == items.length - 1
                                  ? barColor
                                  : barTint,
                              borderRadius: BorderRadius.circular(
                                ext.radiusSm,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Row(
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : HivorrSpacing.xs / 2,
                    right: i == items.length - 1 ? 0 : HivorrSpacing.xs / 2,
                  ),
                  child: Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
