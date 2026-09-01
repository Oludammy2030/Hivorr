import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// A trust signal shown once an identity is verified (EP-02-10 §5.6, §10).
///
/// Uses `colorScheme.secondary` for the checkmark tint and a soft
/// `successContainer` surface with `radiusSm` — premium, never a hard shadow.
class IdentityVerifiedBadge extends StatelessWidget {
  const IdentityVerifiedBadge({
    super.key,
    required this.label,
    this.subtitle,
  });

  /// Primary line, e.g. "Identity Verified".
  final String label;

  /// Optional supportive line, e.g. "tier_1".
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    return Semantics(
      label: label,
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
                    label,
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
