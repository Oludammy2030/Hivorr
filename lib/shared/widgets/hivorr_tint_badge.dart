import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Explicitly-tinted label pill with [HivorrBadge] metrics
/// (VISUAL-IDENTITY.md §21b).
///
/// For labels that are neither status semantics (use [HivorrBadge]) nor role
/// identity (use [HivorrCapabilityBadge]): taxonomy tags, category pills,
/// count chips. Colors are always passed from theme reads — never raw hex.
class HivorrTintBadge extends StatelessWidget {
  const HivorrTintBadge({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ext.radiusSm),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
