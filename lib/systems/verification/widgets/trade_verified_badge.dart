import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// A trust signal shown once a profession's trade verification is approved
/// (EP-02-11 §5.6, §10), releasing the `AGENT.md:15` Rule 2 bid-lock.
///
/// Uses `colorScheme.secondary` for the checkmark tint and a soft
/// `successContainer` surface with `radiusSm` — premium, never a hard shadow.
class TradeVerifiedBadge extends StatelessWidget {
  const TradeVerifiedBadge({
    super.key,
    required this.professionName,
    this.subtitle,
  });

  /// Primary line, e.g. the profession name.
  final String professionName;

  /// Optional supportive line, e.g. "Bidding unlocked".
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    return Semantics(
      label: 'Trade verified — $professionName',
      child: Container(
        padding: const EdgeInsets.all(HivorrSpacing.md),
        decoration: BoxDecoration(
          color: ext.successContainer,
          borderRadius: BorderRadius.circular(ext.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.verified, size: 32, color: colors.secondary),
            const SizedBox(width: HivorrSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    professionName,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: ext.onSuccessContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
