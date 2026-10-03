import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Compact pill action for dense operational tables
/// (VISUAL-IDENTITY.md §21c exception).
///
/// ~34dp effective height keeps ≥720dp admin table rows near ~52dp. The pill
/// sizes to its label (no forced min-height: centering constraints expand
/// intrinsically-sized pills inside tight flex cells). Form CTAs, dialog
/// actions, standalone buttons, and narrow-card (touch) actions always stay
/// ≥48dp via [HivorrButton].
class HivorrTableAction extends StatelessWidget {
  const HivorrTableAction({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback? onTap;

  /// Optional leading icon (14dp, e.g. card actions with glyphs).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    final Widget labelChild = Text(
      label,
      style: context.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    );
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(ext.radiusXs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radiusXs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.smMd,
            vertical: HivorrSpacing.sm,
          ),
          child: icon == null
              ? labelChild
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 14, color: foreground),
                    const SizedBox(width: HivorrSpacing.xs),
                    // Ellipsizing guard: inside wrapped clusters the run can
                    // be narrower than icon + full label (caught by the
                    // density pilot tests). Roomy layouts render the full
                    // label — the Flexible only flexes under pressure.
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
