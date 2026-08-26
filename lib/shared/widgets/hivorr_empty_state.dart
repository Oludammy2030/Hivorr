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
  });

  /// Leading illustration. Defaults to [Icons.inbox_outlined].
  final Widget? icon;

  /// Primary message.
  final String title;

  /// Secondary, supportive message.
  final String? subtitle;

  /// Optional call-to-action (typically a [HivorrButton]).
  final Widget? actionButton;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(
                size: 48,
                color: context.colorScheme.onSurfaceVariant,
              ),
              child: icon ?? const Icon(Icons.inbox_outlined),
            ),
            const SizedBox(height: HivorrSpacing.md),
            Text(
              title,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                subtitle!,
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: context.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionButton != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}
