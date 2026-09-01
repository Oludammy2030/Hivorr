import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Full-area error placeholder with a message and a retry action.
///
/// The [message] is supplied by the caller — this widget never generates or
/// logs its own message (security: no sensitive data leakage).
class HivorrErrorState extends StatelessWidget {
  const HivorrErrorState({
    super.key,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.onRetry,
  });

  /// Error caption shown to the user.
  final String message;

  /// Optional secondary caption (e.g. admin decision notes / guidance).
  final String? detail;

  /// Optional primary action label (e.g. "Resubmit"). When `null` no button is
  /// shown.
  final String? actionLabel;

  /// Handler for the primary action.
  final VoidCallback? onAction;

  /// Optional retry handler. When `null` no button is shown.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final String? actionLabelText = actionLabel;
    final VoidCallback? action = onAction;
    final VoidCallback? retry = onRetry;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: HivorrSpacing.md),
            Text(
              message,
              style: context.textTheme.titleMedium
                  ?.copyWith(color: context.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            if (detail != null && detail!.isNotEmpty) ...<Widget>[
              const SizedBox(height: HivorrSpacing.sm),
              Text(
                detail!,
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: context.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabelText != null && action != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
              HivorrButton(
                label: actionLabelText,
                isExpanded: true,
                onPressed: action,
              ),
            ],
            if (retry != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
              HivorrButton(
                label: 'Retry',
                variant: HivorrButtonVariant.outline,
                onPressed: retry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
