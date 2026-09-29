import 'package:hivorr/data/entities/conversation.dart';

/// Repository contract for contract-scoped messaging (EP-04-04).
///
/// Pure domain entities in and out — ciphertext passes through opaquely.
/// Encryption/decryption is a systems-layer concern (`MessageCrypto`); this
/// contract never sees plaintext.
abstract class MessagingRepository {
  /// Ensures (idempotently) the 1:1 thread for a contract.
  Future<Conversation> ensureForContract(String contractId);

  /// Participant-scoped thread list (newest threads first).
  Future<ConversationPage> listConversations({int limit = 20, String? cursor});

  /// Thread messages, newest first (also marks `last_read_at` server-side).
  Future<MessagePage> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  });

  /// Sends one message (idempotent on [clientMessageId]).
  Future<ConversationMessage> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  });
}

/// A keyset page of conversations.
class ConversationPage {
  const ConversationPage({
    required this.conversations,
    required this.hasMore,
    this.nextCursor,
  });

  /// The page items.
  final List<Conversation> conversations;

  /// Whether further pages exist.
  final bool hasMore;

  /// Cursor for the next page, when [hasMore].
  final String? nextCursor;
}

/// A keyset page of messages (newest first, server order).
class MessagePage {
  const MessagePage({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  /// The page items, newest first.
  final List<ConversationMessage> messages;

  /// Whether older pages exist.
  final bool hasMore;

  /// Cursor for the next (older) page, when [hasMore].
  final String? nextCursor;
}

/// A keyset page of verified-plaintext messages (newest first).
class DecryptedMessagePage {
  const DecryptedMessagePage({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  /// The page items with plaintext applied where verification succeeded.
  final List<ConversationMessage> messages;

  /// Whether older pages exist.
  final bool hasMore;

  /// Cursor for the next (older) page, when [hasMore].
  final String? nextCursor;
}
