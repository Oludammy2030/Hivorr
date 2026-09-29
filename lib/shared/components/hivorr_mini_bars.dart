import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Lightweight metric bars for operational overviews (VISUAL-IDENTITY.md §20).
///
/// Custom token bars — no chart dependency, keeping the installer light
/// (ARCHITECTURE.md). Renders real numbers only: pass items the backend
/// actually returned. When [items] is empty, renders the honest [emptyLabel]
/// instead of invented data (no mock-data rule).
class HivorrMiniBars extends StatelessWidget {
  const HivorrMiniBars({
    super.key,
    required this.items,
    this.emptyLabel = 'Not yet connected.',
    this.accent,
  });

  final List<HivorrBarDatum> items;
  final String emptyLabel;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    if (items.isEmpty) {
      return HivorrCard(
        child: Text(
          emptyLabel,
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }
    final int max = items
        .map((HivorrBarDatum item) => item.value)
        .reduce((int a, int b) => a > b ? a : b)
        .clamp(1, 1 << 31);
    final Color barColor = accent ?? colors.primary;
    return HivorrCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: HivorrSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Text(
                    items[i].label,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: items[i].value / max,
                      minHeight: 8,
                      backgroundColor: colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${items[i].value}',
                    textAlign: TextAlign.end,
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Single labeled value for [HivorrMiniBars].
class HivorrBarDatum {
  const HivorrBarDatum({required this.label, required this.value});

  final String label;
  final int value;
}
