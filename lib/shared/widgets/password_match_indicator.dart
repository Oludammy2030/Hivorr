import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Live confirm-password match status.
///
/// Shown beneath the Confirm password field once the user has typed into it:
/// a positive check for a match, or a clear error state for a mismatch.
/// Conveyed by icon + text (`Passwords match` / `Passwords do not match`) so
/// the state is not communicated by color alone. The entered password value is
/// never rendered.
class PasswordMatchIndicator extends StatelessWidget {
  const PasswordMatchIndicator({super.key, required this.matches});

  /// Whether the confirm field currently equals the password field.
  final bool matches;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final TextTheme text = context.textTheme;
    final Color tone = matches ? ext.success : colors.error;
    return Semantics(
      liveRegion: true,
      label: matches ? 'Passwords match.' : 'Passwords do not match.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            matches ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 16,
            color: tone,
          ),
          const SizedBox(width: HivorrSpacing.xs),
          Text(
            matches ? 'Passwords match' : 'Passwords do not match',
            style: text.bodyMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
