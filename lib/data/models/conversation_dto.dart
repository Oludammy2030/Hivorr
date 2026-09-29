/// Data Transfer Object for a `conversations` row joined with its lateral
/// last-message preview (EP-04-04).
///
/// Mirrors the `conversation_list` item shape
/// (`supabase/migrations/20260925090001_service_messaging_schema.sql:467-478`).
class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.contractId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  factory ConversationDto.fromJson(Map<String, dynamic> json) =>
      ConversationDto(
        id: (json['id'] as String?) ?? '',
        contractId: (json['contract_id'] as String?) ?? '',
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
        lastMessagePreview: json['last_message_preview'] as String?,
        lastMessageAt: _parseNullableDateTime(json['last_message_at']),
      );

  final String id;
  final String contractId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Data Transfer Object for a `messages` row (EP-04-04).
///
/// Mirrors the `message_list` item shape
/// (`supabase/migrations/20260925090001_service_messaging_schema.sql:551-556`).
/// `body_encrypted` stays opaque here — decryption is a systems-layer
/// concern (`MessageCrypto`).
class MessageDto {
  const MessageDto({
    required this.id,
    required this.conversationId,
    required this.senderEntityId,
    required this.bodyEncrypted,
    this.bodyPreview,
    required this.clientMessageId,
    required this.createdAt,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) => MessageDto(
    id: (json['id'] as String?) ?? '',
    conversationId: (json['conversation_id'] as String?) ?? '',
    senderEntityId: (json['sender_entity_id'] as String?) ?? '',
    bodyEncrypted: (json['body_encrypted'] as String?) ?? '',
    bodyPreview: json['body_preview'] as String?,
    clientMessageId: (json['client_message_id'] as String?) ?? '',
    createdAt: _parseDateTime(json['created_at']),
  );

  final String id;
  final String conversationId;
  final String senderEntityId;
  final String bodyEncrypted;
  final String? bodyPreview;
  final String clientMessageId;
  final DateTime createdAt;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
