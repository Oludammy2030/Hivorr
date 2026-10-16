import 'package:flutter/material.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:provider/provider.dart';

/// Permission-disabled notice reusing [HivorrErrorState] (EP-03-18 §12).
///
/// Shows when notifications are [NotificationPermissionStatus.denied] or
/// `permanentlyDenied`. The primary action re-requests permission when the
/// platform still allows it; otherwise it shows OS-settings guidance text
/// (no new `app_settings` dependency — keeps the base installer lean per
/// ARCHITECTURE.md on-demand delivery).
class NotificationPermissionPrompt extends StatelessWidget {
  /// Creates the prompt, optionally overriding the guidance copy.
  const NotificationPermissionPrompt({super.key, this.guidance});

  /// Extra guidance shown under the error state (e.g. screen-specific help).
  final String? guidance;

  @override
  Widget build(BuildContext context) {
    final NotificationProvider provider = context.watch<NotificationProvider>();
    final NotificationPermissionStatus status = provider.permissionStatus;
    if (status != NotificationPermissionStatus.denied &&
        status != NotificationPermissionStatus.permanentlyDenied) {
      return const SizedBox.shrink();
    }
    final bool permanentlyDenied =
        status == NotificationPermissionStatus.permanentlyDenied;
    return HivorrErrorState(
      message: 'Notifications are off',
      detail:
          guidance ??
          (permanentlyDenied
              ? 'Enable notifications in your device Settings > Notifications to receive contract and message updates.'
              : 'Enable notifications to receive contract and message updates.'),
      actionLabel: permanentlyDenied ? null : 'Enable notifications',
      onAction: permanentlyDenied
          ? null
          : () => provider.requestPermission(),
    );
  }
}
