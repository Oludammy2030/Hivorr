import 'package:hivorr/core/notifications/models/notification_priority.dart';

/// Immutable definition of an Android notification channel.
///
/// Android 8.0+ (API 26+) requires channels for all notifications. On iOS and
/// Web this concept does not exist and is silently ignored by the channel
/// manager. Channel ids are validated (alphanumeric + underscore) before use
/// to prevent injection of arbitrary channel identifiers (EP-01-18 §12).
class NotificationChannel {
  const NotificationChannel({
    required this.id,
    required this.name,
    this.description,
    required this.importance,
    this.enableSound = true,
    this.enableVibration = true,
    this.enableLed = false,
    this.ledColor,
  });

  /// Unique channel identifier (e.g. `'hivorr_default'`, `'hivorr_messages'`).
  final String id;

  /// User-visible channel name.
  final String name;

  /// User-visible channel description.
  final String? description;

  /// Default importance for notifications posted to this channel.
  final NotificationPriority importance;

  /// Whether notifications in this channel play sound.
  final bool enableSound;

  /// Whether notifications in this channel vibrate.
  final bool enableVibration;

  /// Whether the notification LED is enabled for this channel.
  final bool enableLed;

  /// ARGB color for the notification LED (Android only).
  final int? ledColor;

  /// Returns a copy with the given fields replaced.
  NotificationChannel copyWith({
    String? id,
    String? name,
    String? description,
    NotificationPriority? importance,
    bool? enableSound,
    bool? enableVibration,
    bool? enableLed,
    int? ledColor,
  }) {
    return NotificationChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      importance: importance ?? this.importance,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      enableLed: enableLed ?? this.enableLed,
      ledColor: ledColor ?? this.ledColor,
    );
  }
}
