import 'package:flutter/material.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Icon + title + body row used across public information pages.
///
/// Pure presentation, token-driven (AGENT.md Rule 5).
class PublicInfoRow extends StatelessWidget {
  const PublicInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: colors.primary, size: 28),
        const SizedBox(width: HivorrSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                body,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
