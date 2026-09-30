import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Full-area empty-state placeholder with an icon, title, optional subtitle,
/// and an optional action button.
class HivorrEmptyState extends StatelessWidget {
  const HivorrEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.actionButton,
    this.compact = false,
  });

  /// Leading illustration. Defaults to [Icons.inbox_outlined].
  final Widget? icon;

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
    final double iconSize = compact ? 34 : 48;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? HivorrSpacing.md : HivorrSpacing.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(
                size: iconSize,
                color: context.colorScheme.onSurfaceVariant,
              ),
              child: icon ?? const Icon(Icons.inbox_outlined),
            ),
            SizedBox(
              height: compact ? HivorrSpacing.sm : HivorrSpacing.md,
            ),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontSize: compact ? 15 : null,
              ),
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
                  fontSize: compact ? 12 : null,
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
