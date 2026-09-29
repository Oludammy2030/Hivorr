/// Conversation summary for the dashboard Messages surface (EP-04-03).
///
/// Shapes the future `conversations`/`messages` read models
/// (`20260925090001_service_messaging_schema.sql`): contract-scoped threads
/// with two participants derived from the linked contract. The UI consumes
/// only this model so the RPC swap later touches the service, never widgets.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.contractId,
    required this.title,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  /// The conversation id.
  final String id;

  /// The linked `service_contracts` row.
  final String contractId;

  /// Display title (job title / counterparty).
  final String title;

  /// Preview of the latest message, when loaded.
  final String? lastMessage;

  /// When the latest message arrived, when loaded.
  final DateTime? lastMessageAt;

  /// Unread count for the current entity.
  final int unreadCount;
}

/// Abstract messaging seam for the dashboard (EP-04-03).
///
/// Lists contract-scoped conversation summaries for the current entity.
/// Implemented by [EmptyMessagingService] until the conversations read RPCs
/// land; the screens depend only on this contract.
abstract class MessagingService {
  /// Lists conversation summaries for the current entity.
  Future<List<ConversationSummary>> listConversations();
}

/// Messaging seam reporting no conversations (EP-04-03).
///
/// Returned until the `conversations` read path is connected: the Messages
/// UI renders its honest empty state instead of fabricated threads. Swap
/// with the Supabase implementation without touching any widget.
class EmptyMessagingService implements MessagingService {
  const EmptyMessagingService();

  @override
  Future<List<ConversationSummary>> listConversations() =>
      Future<List<ConversationSummary>>.value(const <ConversationSummary>[]);
}
