import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/messaging_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/messaging_remote_data_source.dart';
import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:hivorr/data/models/messaging_envelopes_dto.dart';

/// Supabase-backed implementation of [MessagingRemoteDataSource] (EP-04-04).
///
/// Wraps the **four client-callable** messaging RPCs via `supabase.rpc(...)`
/// and unwraps the standard `{success, code, message, data}` envelope with
/// [MessagingEnvelopeParser]. Ciphertext passes through untouched — the
/// caller (systems layer) encrypts before send.
class SupabaseMessagingRemoteDataSource extends BaseApiService
    implements MessagingRemoteDataSource {
  SupabaseMessagingRemoteDataSource({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw mapDataException(e);
    }
  }

  @override
  Future<ConversationEnsureEnvelopeDto> ensureForContract(String contractId) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'conversation_ensure_for_contract',
              params: <String, dynamic>{'p_contract_id': contractId},
            );
        return ConversationEnsureEnvelopeDto.fromJson(
          MessagingEnvelopeParser.unwrap(response),
        );
      });

  @override
  Future<ConversationListEnvelopeDto> listConversations({
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'conversation_list',
          params: <String, dynamic>{'p_limit': limit, 'p_cursor': ?cursor},
        );
    return ConversationListEnvelopeDto.fromJson(
      MessagingEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<MessageListEnvelopeDto> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'message_list',
          params: <String, dynamic>{
            'p_conversation_id': conversationId,
            'p_limit': limit,
            'p_cursor': ?cursor,
          },
        );
    return MessageListEnvelopeDto.fromJson(
      MessagingEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<MessageDto> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'message_send',
          params: <String, dynamic>{
            'p_conversation_id': conversationId,
            'p_body_encrypted': bodyEncrypted,
            'p_body_preview': ?bodyPreview,
            'p_client_message_id': clientMessageId,
          },
        );
    return MessageDto.fromJson(MessagingEnvelopeParser.unwrap(response));
  });
}
