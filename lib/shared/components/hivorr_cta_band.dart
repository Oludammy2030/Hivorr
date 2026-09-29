import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Closing call-to-action band for public pages (VISUAL-IDENTITY.md §17).
///
/// `primaryContainer`-tinted panel (adaptive in dark mode) with a section
/// heading, supporting copy and caller-provided actions (pass `HivorrButton`s).
/// Ends the page with a clear purpose — never a trailing dead-end.
class HivorrCtaBand extends StatelessWidget {
  const HivorrCtaBand({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      padding: const EdgeInsets.all(HivorrSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: context.textTheme.headlineSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              subtitle!,
              style: context.textTheme.bodyLarge?.copyWith(
                color: colors.onPrimaryContainer.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.lg),
            Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
