import 'package:hivorr/core/notifications/channels/notification_channel_manager.dart';
import 'package:hivorr/core/notifications/models/notification_channel.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';

/// EP-03-18 per-category Android channels.
///
/// All ids are `[a-zA-Z0-9_]` validated by [NotificationChannelManager].
/// Messages and escrow releases are `high` (heads-up); everything else is
/// `normal` (quiet by default). iOS/Web ignore channels (no-op backend).
abstract final class LifecycleChannels {
  const LifecycleChannels._();

  /// Contract lifecycle: offered / accepted / cancelled / completed / verified.
  static const NotificationChannel contracts = NotificationChannel(
    id: 'hivorr_contracts',
    name: 'Contracts',
    description: 'Contract offers, acceptances, and milestone updates.',
    importance: NotificationPriority.normal,
  );

  /// Escrow releases and earnings availability (heads-up).
  static const NotificationChannel escrow = NotificationChannel(
    id: 'hivorr_escrow',
    name: 'Payments',
    description: 'Milestone releases and earnings availability.',
    importance: NotificationPriority.high,
  );

  /// Contract-scoped messages (heads-up, mutable per user).
  static const NotificationChannel messages = NotificationChannel(
    id: 'hivorr_messages',
    name: 'Messages',
    description: 'New contract messages.',
    importance: NotificationPriority.high,
  );

  /// Appointments: booked / rescheduled / cancelled.
  static const NotificationChannel schedule = NotificationChannel(
    id: 'hivorr_schedule',
    name: 'Schedule',
    description: 'Appointment bookings and changes.',
    importance: NotificationPriority.normal,
  );

  /// Double-blind reviews: submitted / revealed.
  static const NotificationChannel reviews = NotificationChannel(
    id: 'hivorr_reviews',
    name: 'Reviews',
    description: 'Review submissions and reveals.',
    importance: NotificationPriority.normal,
  );

  /// Disputes: filed / withdrawn / resolved.
  static const NotificationChannel disputes = NotificationChannel(
    id: 'hivorr_disputes',
    name: 'Disputes',
    description: 'Dispute filings and resolutions.',
    importance: NotificationPriority.normal,
  );

  /// All lifecycle channels in registration order.
  static const List<NotificationChannel> all = <NotificationChannel>[
    contracts,
    escrow,
    messages,
    schedule,
    reviews,
    disputes,
  ];

  /// Registers every lifecycle channel (idempotent, Android-only).
  static Future<void> registerAll(NotificationChannelManager manager) async {
    for (final NotificationChannel channel in all) {
      await manager.createChannel(channel);
    }
  }
}
