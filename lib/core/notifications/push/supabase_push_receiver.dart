import 'dart:async';

import 'package:hivorr/core/logging/logging.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/notification_config.dart';
import 'package:hivorr/core/notifications/push/push_notification_receiver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Concrete [PushNotificationReceiver] using Supabase Realtime.
///
/// Subscribes to entity-scoped `postgres_changes` insert events on the
/// configured channel. Incoming rows are mapped to [HivorrNotification] and
/// emitted on [onMessage]. Malformed payloads are logged (via [HivorrLogger])
/// and dropped — never crashing the app (EP-01-18 §5.12, §12).
class SupabasePushReceiver implements PushNotificationReceiver {
  /// Creates the receiver.
  ///
  /// [gateway] defaults to [SupabasePushRealtimeGateway]; inject a fake in
  /// tests. [logger] is optional.
  SupabasePushReceiver(this._config, this._gateway, {this.logger});

  final NotificationConfig _config;
  final PushRealtimeGateway _gateway;
  final HivorrLogger? logger;

  final StreamController<HivorrNotification> _messageController =
      StreamController<HivorrNotification>.broadcast();
  final StreamController<HivorrNotification> _backgroundController =
      StreamController<HivorrNotification>.broadcast();

  String? _subscribedEntityId;
  bool _disposed = false;

  @override
  Stream<HivorrNotification> get onMessage => _messageController.stream;

  @override
  Stream<HivorrNotification> get onBackgroundMessage =>
      _backgroundController.stream;

  @override
  bool get isSubscribed => _subscribedEntityId != null;

  @override
  Future<void> subscribe(String entityId) async {
    if (_disposed) return;
    if (_subscribedEntityId == entityId) return;
    if (_subscribedEntityId != null) {
      await unsubscribe();
    }
    await _gateway.subscribe(
      channelName: _config.pushChannelName,
      entityId: entityId,
      onEvent: _handleEvent,
    );
    _subscribedEntityId = entityId;
  }

  void _handleEvent(Map<String, dynamic> payload) {
    final notification = _mapPayload(payload);
    if (notification != null) {
      _messageController.add(notification);
    }
  }

  HivorrNotification? _mapPayload(Map<String, dynamic> payload) {
    try {
      return HivorrNotification(
        id: _asInt(payload['id']) ?? DateTime.now().microsecondsSinceEpoch,
        title: _asString(payload['title']) ?? '',
        body: _asString(payload['body']) ?? '',
        channelId: _asString(payload['channel_id']) ?? _config.defaultChannelId,
        priority: _priorityFromString(_asString(payload['priority'])),
        payload: payload['payload'] is Map<String, dynamic>
            ? payload['payload'] as Map<String, dynamic>
            : null,
        actionRoute: _asString(payload['action_route']),
        timestamp: DateTime.now(),
      );
    } on Object catch (e) {
      logger?.error(
        'Failed to map push notification payload',
        error: e,
        context: <String, Object?>{'channel': _config.pushChannelName},
      );
      return null;
    }
  }

  @override
  Future<void> unsubscribe() async {
    await _gateway.unsubscribe();
    _subscribedEntityId = null;
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_messageController.isClosed) {
      unawaited(_messageController.close());
    }
    if (!_backgroundController.isClosed) {
      unawaited(_backgroundController.close());
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    return value.toString();
  }

  static NotificationPriority _priorityFromString(String? value) {
    return switch (value) {
      'low' => NotificationPriority.low,
      'normal' => NotificationPriority.normal,
      'high' => NotificationPriority.high,
      'urgent' => NotificationPriority.urgent,
      _ => NotificationPriority.normal,
    };
  }
}

/// Default [PushRealtimeGateway] backed by Supabase Realtime.
class SupabasePushRealtimeGateway implements PushRealtimeGateway {
  /// Creates the gateway from an authenticated [SupabaseClient].
  SupabasePushRealtimeGateway(this._client, this._config);

  final SupabaseClient _client;
  final NotificationConfig _config;
  RealtimeChannel? _channel;

  @override
  Future<void> subscribe({
    required String channelName,
    required String entityId,
    required void Function(Map<String, dynamic> payload) onEvent,
  }) async {
    final name = channelName.isEmpty ? _config.pushChannelName : channelName;
    final channel = _channel = _client.channel(name);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: name,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'entity_id',
        value: entityId,
      ),
      callback: (PostgresChangePayload payload) {
        final record = payload.newRecord;
        onEvent(record);
      },
    );
    channel.subscribe();
  }

  @override
  Future<void> unsubscribe() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }
}
