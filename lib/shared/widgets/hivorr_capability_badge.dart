import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';

/// Focus badge for `hire` / `offer` capabilities (VISUAL-IDENTITY.md §§3, 21b).
///
/// Same metrics as [HivorrBadge]; colors come from [RoleThemeExtension]
/// (role identity, never status semantics). Unknown capabilities (including
/// the retired `both`) render the raw value in a neutral badge so real data
/// is never hidden; null/empty renders an em dash.
class HivorrCapabilityBadge extends StatelessWidget {
  const HivorrCapabilityBadge({super.key, required this.capability});

  final String? capability;

  @override
  Widget build(BuildContext context) {
    final String? label = _labelOf(capability);
    if (label == null) {
      return Text(
        '—',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final RoleThemeExtension roles = context.roleTheme;
    final Color foreground;
    final Color background;
    switch (label) {
      case 'Professional':
        foreground = roles.professionalPrimary;
        background = roles.professionalContainer;
      case 'Employer':
        foreground = roles.clientPrimary;
        background = roles.clientContainer;
      default:
        return HivorrBadge(label: label, variant: HivorrBadgeVariant.neutral);
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
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

/// Screenshot vocabulary for capabilities: `hire` clients are Employers.
/// The retired `both` value falls through to the raw-value neutral badge.
String? _labelOf(String? capability) => switch (capability) {
  'hire' || 'client' => 'Employer',
  'offer' || 'professional' => 'Professional',
  null || '' => null,
  _ => capability,
};
