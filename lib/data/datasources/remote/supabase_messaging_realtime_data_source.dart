import 'dart:async';

import 'package:hivorr/data/datasources/remote/messaging_realtime_data_source.dart';
import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed [MessagingRealtimeDataSource] (EP-03-13).
///
/// One `RealtimeChannel` per conversation:
/// `channel('messages:<id>')` with `onPostgresChanges` for `insert` on
/// `public.messages` filtered to the open `conversation_id`.
/// Subscription is RLS-filtered server-side, so non-participants receive
/// zero events. Malformed rows are dropped, never thrown.
///
/// Channel names never carry ciphertext, previews, or PII — only the
/// conversation id, which is an unguessable UUID already known to
/// participants via `conversation_list`.
class SupabaseMessagingRealtimeDataSource
    implements MessagingRealtimeDataSource {
  SupabaseMessagingRealtimeDataSource(this._client);

  final SupabaseClient _client;

  final Map<String, RealtimeChannel> _channels = <String, RealtimeChannel>{};
  final Map<String, StreamController<MessageDto>> _controllers =
      <String, StreamController<MessageDto>>{};

  @override
  Stream<MessageDto> messagesFor(String conversationId) {
    final StreamController<MessageDto>? existing =
        _controllers[conversationId];
    if (existing != null && !existing.isClosed) {
      return existing.stream;
    }
    final StreamController<MessageDto> controller =
        StreamController<MessageDto>.broadcast();
    _controllers[conversationId] = controller;
    final RealtimeChannel channel = _client.channel('messages:$conversationId');
    _channels[conversationId] = channel;
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (PostgresChangePayload payload) {
        final MessageDto? dto = _mapRecord(payload.newRecord);
        if (dto != null && !controller.isClosed) {
          controller.add(dto);
        }
      },
    );
    channel.subscribe();
    return controller.stream;
  }

  @override
  Future<void> unsubscribe(String conversationId) async {
    final RealtimeChannel? channel = _channels.remove(conversationId);
    final StreamController<MessageDto>? controller = _controllers.remove(
      conversationId,
    );
    if (channel != null) {
      await _client.removeChannel(channel);
    }
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  @override
  Future<void> dispose() async {
    final List<String> ids = _channels.keys.toList(growable: false);
    for (final String id in ids) {
      await unsubscribe(id);
    }
  }

  static MessageDto? _mapRecord(Map<String, dynamic> record) {
    try {
      final MessageDto dto = MessageDto.fromJson(record);
      if (dto.id.isEmpty || dto.conversationId.isEmpty) {
        return null;
      }
      return dto;
    } on Object {
      return null;
    }
  }
}
