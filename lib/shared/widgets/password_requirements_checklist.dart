import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/validators/password_policy.dart';

/// Live password-requirements checklist.
///
/// Shows one row per required character class with an unambiguous state:
/// satisfied → filled check icon + emphasized label; unsatisfied → neutral
/// outline circle + muted label. State is conveyed by icon + text (and
/// `Semantics`), never by color alone, so it stays understandable without
/// color vision.
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    super.key,
    required this.result,
    required this.requirements,
  });

  /// Evaluation of the current password input.
  final PasswordPolicyResult result;

  /// The required classes to display (normally `PasswordPolicy.required`).
  final List<PasswordCharacterClass> requirements;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final TextTheme text = context.textTheme;
    return Semantics(
      container: true,
      label: 'Password requirements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.xs),
            child: Text(
              'Password requirements',
              style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          for (final PasswordCharacterClass cls in requirements)
            _RequirementRow(
              label: cls.label,
              satisfied: result.satisfied[cls] ?? false,
            ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.satisfied});

  final String label;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final TextTheme text = context.textTheme;
    final Color rowColor = satisfied ? ext.success : colors.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.xs / 2),
      child: Semantics(
        label: satisfied ? '$label: satisfied' : '$label: required',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              satisfied ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: rowColor,
            ),
            const SizedBox(width: HivorrSpacing.xs),
            Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: satisfied ? colors.onSurface : colors.onSurfaceVariant,
                fontWeight: satisfied ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
