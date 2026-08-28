import 'dart:async';

import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/core/logging/logging.dart';
import 'package:hivorr/core/notifications/channels/notification_channel_manager.dart';
import 'package:hivorr/core/notifications/notification_config.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/core/notifications/push/push_notification_receiver.dart';
import 'package:hivorr/core/notifications/push/supabase_push_receiver.dart';
import 'package:hivorr/core/notifications/services/local_notification_service.dart';
import 'package:hivorr/core/notifications/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:hivorr/core/notifications/channels/notification_channel_manager.dart';
export 'package:hivorr/core/notifications/models/hivorr_notification.dart';
export 'package:hivorr/core/notifications/models/notification_channel.dart';
export 'package:hivorr/core/notifications/models/notification_permission_status.dart';
export 'package:hivorr/core/notifications/models/notification_priority.dart';
export 'package:hivorr/core/notifications/notification_config.dart';
export 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
export 'package:hivorr/core/notifications/providers/notification_provider.dart';
export 'package:hivorr/core/notifications/push/push_notification_receiver.dart';
export 'package:hivorr/core/notifications/push/supabase_push_receiver.dart';
export 'package:hivorr/core/notifications/services/local_notification_service.dart';
export 'package:hivorr/core/notifications/services/notification_service.dart';

/// Aggregate of the wired notification engine, returned by
/// [initializeNotifications].
class NotificationLayer {
  /// Creates the notification layer aggregate.
  const NotificationLayer({
    required this.service,
    required this.pushReceiver,
    required this.permissionManager,
    required this.channelManager,
    required this.provider,
    required this.config,
  });

  /// Local notification dispatch.
  final NotificationService service;

  /// Push reception (null when disabled by configuration).
  final PushNotificationReceiver? pushReceiver;

  /// Permission lifecycle.
  final NotificationPermissionManager permissionManager;

  /// Android channel lifecycle.
  final NotificationChannelManager channelManager;

  /// Widget-tree state propagation.
  final NotificationProvider provider;

  /// Active notification configuration.
  final NotificationConfig config;
}

/// Constructs and wires the full notification engine.
///
/// This is the single EP-01-15 bootstrap entry point. It does NOT modify
/// `main.dart` or any app bootstrap — it only exports the initializer. Push
/// is constructed only when BOTH [NotificationConfig.enablePushNotifications]
/// and [EnvironmentConfig.featureFlags.enablePushNotifications] are true and
/// [entityId] is provided (fail-closed, EP-01-18 §5.15).
///
/// [loggerFactory] is optional; when supplied, notification components obtain
/// a scoped [HivorrLogger] named `'hivorr.notifications'` for PII-safe logging.
NotificationLayer initializeNotifications(
  EnvironmentConfig config,
  SupabaseClient supabaseClient, {
  String? entityId,
  LoggerFactory? loggerFactory,
}) {
  final logger = loggerFactory?.named('hivorr.notifications');
  final notificationConfig = config.notificationConfig;

  final backend = FlutterLocalNotificationsBackend(notificationConfig);
  final channelManager = NotificationChannelManager(backend, logger: logger);
  final service = LocalNotificationService(
    notificationConfig,
    backend: backend,
    logger: logger,
    knownChannels: channelManager.channels,
  );
  unawaited(service.initialize());
  unawaited(channelManager.createDefaultChannel(notificationConfig));

  final permissionManager = NotificationPermissionManager();

  PushNotificationReceiver? pushReceiver;
  if (notificationConfig.enablePushNotifications &&
      config.featureFlags.enablePushNotifications &&
      entityId != null) {
    final gateway = SupabasePushRealtimeGateway(supabaseClient, notificationConfig);
    pushReceiver = SupabasePushReceiver(
      notificationConfig,
      gateway,
      logger: logger,
    );
  }

  final provider = NotificationProvider(
    service,
    permissionManager,
    pushReceiver: pushReceiver,
    entityId: entityId,
    logger: logger,
  );
  unawaited(provider.initialize());

  return NotificationLayer(
    service: service,
    pushReceiver: pushReceiver,
    permissionManager: permissionManager,
    channelManager: channelManager,
    provider: provider,
    config: notificationConfig,
  );
}
