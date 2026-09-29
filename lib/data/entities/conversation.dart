/// A contract-scoped message thread (EP-04-04).
///
/// Mirrors `conversations`
/// (`supabase/migrations/20260925090001_service_messaging_schema.sql:53-61`)
/// joined with the lateral last-message preview from `conversation_list`.
/// Exactly one thread per `service_contracts` row; participants derive from
/// the linked contract and never cross entity boundaries (RLS).
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class Conversation {
  const Conversation({
    required this.id,
    required this.contractId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  /// The conversation row id.
  final String id;

  /// The linked `service_contracts` row (engagement atom).
  final String contractId;

  /// When the thread was created.
  final DateTime createdAt;

  /// When the thread was last updated.
  final DateTime updatedAt;

  /// Server-redacted preview of the latest message, when any.
  final String? lastMessagePreview;

  /// When the latest message arrived, when any.
  final DateTime? lastMessageAt;

  /// Whether any message exists yet.
  bool get hasMessages => lastMessageAt != null;
}

/// A single immutable message (EP-04-04).
///
/// Mirrors `messages`
/// (`supabase/migrations/20260925090001_service_messaging_schema.sql:106-119`).
/// [bodyEncrypted] is opaque AES-GCM ciphertext over JSON
/// (`MessageCrypto`); [decryptedBody] carries the verified plaintext once
/// [MessageCrypto] (systems layer) decrypts it — transport DTOs never hold
/// plaintext.
class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.senderEntityId,
    required this.bodyEncrypted,
    this.bodyPreview,
    required this.clientMessageId,
    required this.createdAt,
    this.decryptedBody,
  });

  /// The message row id.
  final String id;

  /// The parent thread.
  final String conversationId;

  /// The sending entity.
  final String senderEntityId;

  /// Opaque ciphertext (`EncryptedPayload {c,i,t}` JSON, base64).
  final String bodyEncrypted;

  /// Server-redacted preview (left 120), when present.
  final String? bodyPreview;

  /// Offline-replay dedup id (uuid v4, client-generated).
  final String clientMessageId;

  /// When the message was sent.
  final DateTime createdAt;

  /// Verified plaintext, set after AES-GCM authentication succeeds.
  ///
  /// `null` means not yet decrypted (or undecryptable — the UI must render
  /// a placeholder, never guess).
  final String? decryptedBody;

  /// Copies this message with verified [decryptedBody] applied.
  ConversationMessage decrypted(String plaintext) => ConversationMessage(
    id: id,
    conversationId: conversationId,
    senderEntityId: senderEntityId,
    bodyEncrypted: bodyEncrypted,
    bodyPreview: bodyPreview,
    clientMessageId: clientMessageId,
    createdAt: createdAt,
    decryptedBody: plaintext,
  );
}
