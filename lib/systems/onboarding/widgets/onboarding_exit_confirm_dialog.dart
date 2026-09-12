import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Confirms the exit protocol for the EP-02-18 wizard (FV-37).
///
/// "Save my progress and exit?" — [onExit] persists the current position and
/// leaves the wizard; progress is saved at every advance, so exiting never
/// loses state. Styling uses [ColorScheme] tokens only.
class OnboardingExitConfirmDialog extends StatelessWidget {
  const OnboardingExitConfirmDialog({
    super.key,
    required this.onExit,
    this.onStay,
  });

  /// Persists progress and exits the wizard.
  final VoidCallback onExit;

  /// Dismisses the dialog and continues the wizard (optional).
  final VoidCallback? onStay;

  /// Shows the dialog from [context], resolving with `true` when the user
  /// chooses "Save & exit", `false`/`null` when staying.
  static Future<bool?> show(
    BuildContext context, {
    required VoidCallback onExit,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) =>
          OnboardingExitConfirmDialog(onExit: onExit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    return AlertDialog(
      title: Text('Save my progress and exit?', style: context.textTheme.titleLarge),
      content: Text(
        'Your progress is saved automatically. You can pick up right where '
        'you left off when you come back.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      actions: <Widget>[
        HivorrButton(
          label: 'Stay',
          variant: HivorrButtonVariant.text,
          onPressed: onStay == null
              ? () => Navigator.of(context).pop(false)
              : () {
                  Navigator.of(context).pop(false);
                  onStay!();
                },
        ),
        const SizedBox(width: HivorrSpacing.xs),
        HivorrButton(
          label: 'Save & exit',
          variant: HivorrButtonVariant.primary,
          onPressed: () {
            Navigator.of(context).pop(true);
            onExit();
          },
        ),
      ],
    );
  }
}