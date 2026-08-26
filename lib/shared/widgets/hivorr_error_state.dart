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
    this.onRetry,
  });

  /// Error caption shown to the user.
  final String message;

  /// Optional retry handler. When `null` no button is shown.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
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
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
              HivorrButton(
                label: 'Retry',
                variant: HivorrButtonVariant.outline,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
