import 'dart:async';

import 'package:hivorr/core/notifications/models/hivorr_notification.dart';

/// Abstract push notification receiver.
///
/// Decouples the notification engine from any concrete push transport. The
/// initial transport is Supabase Realtime ([SupabasePushReceiver]); a future
/// Firebase/FCM implementation can be added without changing the engine core
/// (EP-01-18 §5.11, §5.19).
abstract class PushNotificationReceiver {
  /// Subscribes to push events targeted at [entityId].
  Future<void> subscribe(String entityId);

  /// Unsubscribes from push events.
  Future<void> unsubscribe();

  /// Stream of notifications received while the app is in the foreground.
  Stream<HivorrNotification> get onMessage;

  /// Stream of notifications delivered while the app was in the background.
  ///
  /// For the Supabase Realtime transport this is populated when the app
  /// returns to the foreground and processes queued events; on mobile the
  /// Realtime connection may not persist in the background.
  Stream<HivorrNotification> get onBackgroundMessage;

  /// Whether a subscription is currently active.
  bool get isSubscribed;

  /// Releases resources held by the receiver.
  void dispose();
}

/// Abstraction over a Realtime push subscription source.
///
/// The default [SupabasePushRealtimeGateway] wraps `SupabaseClient`. Tests
/// inject a fake to verify subscription behavior without a live backend
/// (EP-01-18 §14.8).
abstract class PushRealtimeGateway {
  /// Subscribes to insert events on [channelName] filtered by [entityId].
  ///
  /// [onEvent] receives the new row record for each matching event.
  Future<void> subscribe({
    required String channelName,
    required String entityId,
    required void Function(Map<String, dynamic> payload) onEvent,
  });

  /// Removes the active subscription, if any.
  Future<void> unsubscribe();
}
