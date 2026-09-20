import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/validators/password_policy.dart';

/// Live password-strength indicator.
///
/// A three-segment bar plus an explicit label (`Weak` / `Medium` / `Strong`).
/// Segments fill up to the current classification level and take the
/// classification tone (red / amber / green via design tokens). The text label
/// means the state is not communicated by color alone.
///
/// The classification comes from [PasswordStrength] computed by the
/// [PasswordPolicy] — never from length alone — and is guidance only; Supabase
/// remains the authoritative enforcement layer.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.strength});

  /// The current classification of the password input.
  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final TextTheme text = context.textTheme;
    final int level = switch (strength) {
      PasswordStrength.weak => 1,
      PasswordStrength.medium => 2,
      PasswordStrength.strong => 3,
    };
    final Color tone = switch (strength) {
      PasswordStrength.weak => colors.error,
      PasswordStrength.medium => ext.warning,
      PasswordStrength.strong => ext.success,
    };
    return Semantics(
      container: true,
      label: 'Password strength: ${strength.label}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Password strength: ${strength.label}',
            style: text.labelMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Row(
            children: <Widget>[
              for (int i = 1; i <= 3; i++) ...<Widget>[
                if (i > 1) const SizedBox(width: HivorrSpacing.xs),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= level ? tone : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
