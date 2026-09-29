import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:hivorr/data/models/messaging_envelopes_dto.dart';

/// Contract for messaging transport (EP-04-04).
///
/// Wraps exactly the **four client-callable** RPCs granted to `authenticated`
/// (`supabase/migrations/20260925090001_service_messaging_schema.sql`):
/// `conversation_ensure_for_contract`, `conversation_list`, `message_list`,
/// `message_send`. Payloads stay opaque: `body_encrypted` is AES-GCM
/// ciphertext produced by `MessageCrypto` (systems layer) — this contract
/// never sees plaintext.
abstract class MessagingRemoteDataSource {
  /// Ensures the 1:1 thread for a contract (idempotent,
  /// `conversation_ensure_for_contract`, VOLATILE).
  Future<ConversationEnsureEnvelopeDto> ensureForContract(String contractId);

  /// Participant-scoped thread list (`conversation_list`, STABLE).
  Future<ConversationListEnvelopeDto> listConversations({
    int limit = 20,
    String? cursor,
  });

  /// Thread messages, newest first (`message_list`, VOLATILE — also marks
  /// the caller's `last_read_at` server-side).
  Future<MessageListEnvelopeDto> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  });

  /// Sends one message (`message_send`, VOLATILE, idempotent on
  /// [clientMessageId]).
  Future<MessageDto> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  });
}
