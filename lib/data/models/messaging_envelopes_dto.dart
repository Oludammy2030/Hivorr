import 'package:hivorr/data/models/conversation_dto.dart';

/// Envelope for `conversation_list` (EP-04-04).
///
/// `data` shape: `{items: Conversation[], has_more, next_cursor}`.
class ConversationListEnvelopeDto {
  const ConversationListEnvelopeDto({
    required this.conversations,
    required this.hasMore,
    this.nextCursor,
  });

  factory ConversationListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    return ConversationListEnvelopeDto(
      conversations: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(ConversationDto.fromJson)
                .toList(growable: false)
          : const <ConversationDto>[],
      hasMore: (json['has_more'] as bool?) ?? false,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<ConversationDto> conversations;
  final bool hasMore;
  final String? nextCursor;
}

/// Envelope for `message_list` (EP-04-04).
///
/// `data` shape: `{items: Message[] (newest first), has_more, next_cursor}`.
class MessageListEnvelopeDto {
  const MessageListEnvelopeDto({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  factory MessageListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    return MessageListEnvelopeDto(
      messages: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(MessageDto.fromJson)
                .toList(growable: false)
          : const <MessageDto>[],
      hasMore: (json['has_more'] as bool?) ?? false,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<MessageDto> messages;
  final bool hasMore;
  final String? nextCursor;
}

/// Envelope for `conversation_ensure_for_contract` (EP-04-04).
///
/// `data` shape: `{conversation, participants[]}`. Participants are
/// passthrough row maps (membership proof, not displayed).
class ConversationEnsureEnvelopeDto {
  const ConversationEnsureEnvelopeDto({required this.conversation});

  factory ConversationEnsureEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['conversation'];
    return ConversationEnsureEnvelopeDto(
      conversation: ConversationDto.fromJson(
        raw is Map<String, dynamic> ? raw : const <String, dynamic>{},
      ),
    );
  }

  final ConversationDto conversation;
}
