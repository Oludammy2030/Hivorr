import 'package:hivorr/data/models/conversation_dto.dart';

/// Realtime transport for contract-scoped messaging (EP-03-13).
///
/// Wraps the Supabase Realtime `messages` publication
/// (`supabase/migrations/20260925090001_service_messaging_schema.sql`,
/// RLS-filtered `INSERT` on `public.messages`) behind a testable seam,
/// mirroring `SupabasePushRealtimeGateway`. Payloads stay opaque:
/// `body_encrypted` is AES-GCM ciphertext produced by `MessageCrypto`
/// (systems layer) — this contract never sees plaintext.
abstract class MessagingRealtimeDataSource {
  /// Subscribes to `INSERT` events for [conversationId].
  ///
  /// Emits one [MessageDto] per inserted row visible to the caller under
  /// RLS. Non-participant channels emit zero events (server-enforced).
  /// The stream is broadcast; late listeners receive only future events.
  Stream<MessageDto> messagesFor(String conversationId);

  /// Removes the channel for [conversationId]. No-op when absent.
  Future<void> unsubscribe(String conversationId);

  /// Removes every channel and closes all streams.
  Future<void> dispose();
}
