// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/messaging_remote_data_source.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/mappers/messaging_mapper.dart';
import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';

/// Default implementation of [MessagingRepository].
///
/// Reads via `conversation_list`/`message_list` and writes via
/// `conversation_ensure_for_contract`/`message_send`, mapped through
/// [MessagingMapper]. Lightweight fail-fast checks (non-empty ids, limit
/// bounds, non-empty ciphertext) mirror the server contract so preventable
/// `PLT003` never round-trips. Ciphertext is opaque here — never inspected,
/// never logged. This implementation never writes messaging tables directly
/// (AGENT.md Rule 4).
class MessagingRepositoryImpl implements MessagingRepository {
  MessagingRepositoryImpl({required MessagingRemoteDataSource remote})
    : _remote = remote;

  final MessagingRemoteDataSource _remote;

  @override
  Future<Conversation> ensureForContract(String contractId) async {
    _requireNonEmpty(contractId, 'contractId');
    final envelope = await _remote.ensureForContract(contractId);
    return MessagingMapper.conversationToEntity(envelope.conversation);
  }

  @override
  Future<ConversationPage> listConversations({
    int limit = 20,
    String? cursor,
  }) async {
    _requireLimit(limit);
    final dto = await _remote.listConversations(limit: limit, cursor: cursor);
    return ConversationPage(
      conversations: MessagingMapper.listEnvelopeToEntities(dto),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  @override
  Future<MessagePage> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  }) async {
    _requireNonEmpty(conversationId, 'conversationId');
    _requireLimit(limit);
    final dto = await _remote.listMessages(
      conversationId,
      limit: limit,
      cursor: cursor,
    );
    return MessagePage(
      messages: MessagingMapper.messageListToEntities(dto),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  @override
  Future<ConversationMessage> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  }) async {
    _requireNonEmpty(conversationId, 'conversationId');
    _requireNonEmpty(bodyEncrypted, 'bodyEncrypted');
    _requireNonEmpty(clientMessageId, 'clientMessageId');
    final MessageDto dto = await _remote.sendMessage(
      conversationId: conversationId,
      bodyEncrypted: bodyEncrypted,
      bodyPreview: bodyPreview,
      clientMessageId: clientMessageId,
    );
    return MessagingMapper.messageToEntity(dto);
  }

  void _requireLimit(int limit) {
    if (limit < 1 || limit > 100) {
      _fail('Limit must be between 1 and 100.');
    }
  }

  static void _fail(String message) {
    throw ApiException(
      kind: ApiExceptionKind.validation,
      message: message,
      code: 'PLT003',
    );
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      _fail('$field is required.');
    }
  }
}
