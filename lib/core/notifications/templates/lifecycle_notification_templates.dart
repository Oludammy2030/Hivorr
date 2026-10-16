import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/notifications/channels/lifecycle_channels.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';

/// Server template mirror for local echo previews (EP-03-18 §7.4).
///
/// Titles/bodies use `***last4` only — never emails, phones, amounts,
/// message bodies, or review text. [payload] carries IDs + `event` only.
/// The server trigger is authoritative; these builders only shape the
/// foreground local echo so offline/self actions look identical.
abstract final class LifecycleNotificationTemplates {
  const LifecycleNotificationTemplates._();

  /// Last-4 redaction shared with `dispute_notify` / SQL triggers.
  static String shortId(String id) =>
      id.length <= 4 ? '***$id' : '***${id.substring(id.length - 4)}';

  static LifecycleNotificationTemplate contractOffered(String contractId) => LifecycleNotificationTemplate(
    title: 'New contract offer',
    body: 'Contract ${shortId(contractId)} is awaiting your review.',
    channelId: LifecycleChannels.contracts.id,
    priority: NotificationPriority.normal,
    actionRoute: RoutePaths.contractDetail(contractId),
    payload: <String, dynamic>{'contractId': contractId, 'event': 'contract_offered'},
  );

  static LifecycleNotificationTemplate contractAccepted(String contractId) => LifecycleNotificationTemplate(
    title: 'Contract accepted',
    body: 'Contract ${shortId(contractId)} is now active.',
    channelId: LifecycleChannels.contracts.id,
    priority: NotificationPriority.normal,
    actionRoute: RoutePaths.contractDetail(contractId),
    payload: <String, dynamic>{'contractId': contractId, 'event': 'contract_accepted'},
  );

  static LifecycleNotificationTemplate milestoneReleased(String contractId, String milestoneId) => LifecycleNotificationTemplate(
    title: 'Milestone released',
    body: 'Contract ${shortId(contractId)} milestone was released.',
    channelId: LifecycleChannels.escrow.id,
    priority: NotificationPriority.high,
    actionRoute: RoutePaths.contractDetail(contractId),
    payload: <String, dynamic>{
      'contractId': contractId,
      'milestoneId': milestoneId,
      'event': 'milestone_released',
    },
  );

  static LifecycleNotificationTemplate earningsReleased(String contractId, String milestoneId) => LifecycleNotificationTemplate(
    title: 'Payment received',
    body: 'Contract ${shortId(contractId)} earnings are available.',
    channelId: LifecycleChannels.escrow.id,
    priority: NotificationPriority.high,
    actionRoute: RoutePaths.earningsDetail,
    payload: <String, dynamic>{
      'contractId': contractId,
      'milestoneId': milestoneId,
      'event': 'earnings_released',
    },
  );

  static LifecycleNotificationTemplate messageReceived(String contractId, String conversationId) => LifecycleNotificationTemplate(
    title: 'New message',
    body: 'Contract ${shortId(contractId)} has a new message.',
    channelId: LifecycleChannels.messages.id,
    priority: NotificationPriority.high,
    actionRoute: RoutePaths.dashboardMessageThread(conversationId),
    payload: <String, dynamic>{
      'contractId': contractId,
      'conversationId': conversationId,
      'event': 'message_received',
    },
  );

  static LifecycleNotificationTemplate reviewRevealed(String contractId) => LifecycleNotificationTemplate(
    title: 'Review revealed',
    body: 'Contract ${shortId(contractId)} reviews are now visible.',
    channelId: LifecycleChannels.reviews.id,
    priority: NotificationPriority.normal,
    actionRoute: RoutePaths.contractReviewsFor(contractId),
    payload: <String, dynamic>{'contractId': contractId, 'event': 'review_revealed'},
  );
}

/// Lightweight template value (presentation only, no business logic).
class LifecycleNotificationTemplate {
  const LifecycleNotificationTemplate({
    required this.title,
    required this.body,
    required this.channelId,
    required this.priority,
    required this.actionRoute,
    required this.payload,
  });

  /// Notification title (pre-redacted).
  final String title;

  /// Notification body (pre-redacted).
  final String body;

  /// Target Android channel id.
  final String channelId;

  /// Rendering priority.
  final NotificationPriority priority;

  /// GoRouter deep-link.
  final String actionRoute;

  /// IDs + event only (no PII).
  final Map<String, dynamic> payload;
}
