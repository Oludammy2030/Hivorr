import 'package:hivorr/core/notifications/models/notification_priority.dart';

/// Immutable notification payload delivered through the notification engine.
///
/// This is a pure presentation/transport value object. It carries no business
/// logic, no domain entities, and never any secrets, tokens, or credentials
/// (EP-01-18 §12). The `payload` field is opaque display/routing data only —
/// downstream systems (EP-02+) use [actionRoute] for deep-link navigation.
class HivorrNotification {
  const HivorrNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.channelId,
    this.priority = NotificationPriority.normal,
    this.payload,
    this.actionRoute,
    required this.timestamp,
    this.isRead = false,
  });

  /// Unique notification identifier (used for cancel/update).
  final int id;

  /// Notification title.
  final String title;

  /// Notification body text.
  final String body;

  /// Target notification channel id.
  final String channelId;

  /// Rendering priority/importance.
  final NotificationPriority priority;

  /// Optional structured data for deep-link routing. Display/routing only.
  final Map<String, dynamic>? payload;

  /// Optional GoRouter path invoked when the notification is tapped.
  final String? actionRoute;

  /// When the notification was created/received.
  final DateTime timestamp;

  /// Whether the user has acknowledged it.
  final bool isRead;

  /// Serializes to JSON for persistent storage by downstream tasks.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'channelId': channelId,
      'priority': priority.name,
      'payload': payload,
      'actionRoute': actionRoute,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  /// Deserializes from JSON, applying safe defaults for missing fields.
  factory HivorrNotification.fromJson(Map<String, dynamic> json) {
    final priorityName = json['priority'] as String?;
    final NotificationPriority priority = priorityName == null
        ? NotificationPriority.normal
        : NotificationPriority.values.firstWhere(
            (NotificationPriority p) => p.name == priorityName,
            orElse: () => NotificationPriority.normal,
          );

    final timestampRaw = json['timestamp'] as String?;
    final DateTime timestamp = timestampRaw == null
        ? DateTime.now()
        : DateTime.tryParse(timestampRaw) ?? DateTime.now();

    final payloadRaw = json['payload'];
    final Map<String, dynamic>? payload =
        payloadRaw is Map<String, dynamic> ? payloadRaw : null;

    return HivorrNotification(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      channelId: (json['channelId'] as String?) ?? 'hivorr_default',
      priority: priority,
      payload: payload,
      actionRoute: json['actionRoute'] as String?,
      timestamp: timestamp,
      isRead: (json['isRead'] as bool?) ?? false,
    );
  }
}
