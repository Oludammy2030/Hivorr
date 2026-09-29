import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:hivorr/data/models/messaging_envelopes_dto.dart';

/// Transformations between the messaging transport DTOs and the pure-Dart
/// domain entities (EP-04-04).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying (EP-01-08 §5.3).
/// Ciphertext is never inspected here; decryption is a systems-layer concern.
abstract final class MessagingMapper {
  /// Maps a `conversation_list` item into a domain [Conversation].
  static Conversation conversationToEntity(ConversationDto dto) => Conversation(
    id: dto.id,
    contractId: dto.contractId,
    createdAt: dto.createdAt,
    updatedAt: dto.updatedAt,
    lastMessagePreview: dto.lastMessagePreview,
    lastMessageAt: dto.lastMessageAt,
  );

  /// Maps a `messages` DTO into a domain [ConversationMessage].
  static ConversationMessage messageToEntity(MessageDto dto) =>
      ConversationMessage(
        id: dto.id,
        conversationId: dto.conversationId,
        senderEntityId: dto.senderEntityId,
        bodyEncrypted: dto.bodyEncrypted,
        bodyPreview: dto.bodyPreview,
        clientMessageId: dto.clientMessageId,
        createdAt: dto.createdAt,
      );

  /// Maps a `conversation_list` envelope into domain [Conversation]s.
  static List<Conversation> listEnvelopeToEntities(
    ConversationListEnvelopeDto dto,
  ) => dto.conversations.map(conversationToEntity).toList(growable: false);

  /// Maps a `message_list` envelope into domain [ConversationMessage]s.
  static List<ConversationMessage> messageListToEntities(
    MessageListEnvelopeDto dto,
  ) => dto.messages.map(messageToEntity).toList(growable: false);
}
