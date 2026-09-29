import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';

/// Notifications center shell (EP-04-03).
///
/// Local lifecycle notifications (hire hired/completed, job published,
/// application submitted) are emitted through the app notification provider
/// today; the remote notification feed lands here when its read path is
/// connected. Until then the honest empty state explains what triggers
/// notifications.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: context.textTheme.titleLarge),
      ),
      body: const SafeArea(
        child: HivorrEmptyState(
          icon: Icon(Icons.notifications_outlined),
          title: 'No notifications yet',
          subtitle:
              'Hire updates, application decisions, and payment events will appear here.',
        ),
      ),
    );
  }
}
