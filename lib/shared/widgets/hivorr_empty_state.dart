import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_spot_illustration.dart';

/// Full-area empty-state placeholder with a brand illustration, title,
/// optional subtitle, and an optional action button.
class HivorrEmptyState extends StatelessWidget {
  const HivorrEmptyState({
    super.key,
    this.icon,
    this.illustration,
    this.illustrationVariant = HivorrSpotVariant.general,
    required this.title,
    this.subtitle,
    this.actionButton,
    this.compact = false,
  });

  /// Explicit leading icon. When provided it wins over [illustration]:
  /// existing call sites with a chosen icon keep their look.
  final Widget? icon;

  /// Explicit illustration override. Defaults to the brand spot
  /// illustration for [illustrationVariant] (§16a).
  final Widget? illustration;

  /// Constellation variant for the default illustration.
  final HivorrSpotVariant illustrationVariant;

  /// Primary message.
  final String title;

  /// Secondary, supportive message.
  final String? subtitle;

  /// Optional call-to-action (typically a [HivorrButton]).
  final Widget? actionButton;

  /// Compact mobile density: smaller icon/padding/gaps. Desktop unchanged.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double artSize = compact ? 72 : 96;
    final Widget art =
        icon ??
        illustration ??
        HivorrSpotIllustration(
          variant: illustrationVariant,
          size: artSize,
        );
    // Legacy icon path keeps the old 32/48 sizing; the spot illustration
    // carries its own size.
    final bool legacyIcon = icon != null && illustration == null;
    final double iconSize = compact ? 32 : 48;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? HivorrSpacing.md : HivorrSpacing.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (legacyIcon)
              IconTheme.merge(
                data: IconThemeData(
                  size: iconSize,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                child: art,
              )
            else
              art,
            SizedBox(
              height: compact ? HivorrSpacing.sm : HivorrSpacing.md,
            ),
            Text(
              title,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                subtitle!,
                style: (compact
                        ? context.textTheme.bodySmall
                        : context.textTheme.bodyMedium)
                    ?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionButton != null) ...<Widget>[
              SizedBox(
                height: compact ? HivorrSpacing.sm : HivorrSpacing.md,
              ),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}
