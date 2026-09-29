import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/messaging_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/messaging_remote_data_source.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/mappers/messaging_mapper.dart';
import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:hivorr/data/models/messaging_envelopes_dto.dart';
import 'package:hivorr/data/repositories/messaging_repository_impl.dart';

/// Fake messaging transport with canned rows.
class FakeMessagingRemote implements MessagingRemoteDataSource {
  int listCalls = 0;

  static Map<String, dynamic> conversationRow() => <String, dynamic>{
    'id': 'conv-1',
    'contract_id': 'contract-1',
    'created_at': '2026-09-05T10:00:00Z',
    'updated_at': '2026-09-05T10:00:00Z',
    'last_message_preview': 'See you Monday',
    'last_message_at': '2026-09-05T11:00:00Z',
  };

  @override
  Future<ConversationEnsureEnvelopeDto> ensureForContract(
    String contractId,
  ) async => ConversationEnsureEnvelopeDto.fromJson(<String, dynamic>{
    'conversation': conversationRow(),
  });

  @override
  Future<ConversationListEnvelopeDto> listConversations({
    int limit = 20,
    String? cursor,
  }) async {
    listCalls++;
    return ConversationListEnvelopeDto.fromJson(<String, dynamic>{
      'items': <dynamic>[conversationRow()],
      'has_more': false,
    });
  }

  @override
  Future<MessageListEnvelopeDto> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  }) async => throw UnimplementedError();

  @override
  Future<MessageDto> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  }) async => throw UnimplementedError();
}

void main() {
  group('MessagingEnvelopeParser', () {
    test('unwraps data on PLT000', () {
      final Map<String, dynamic> data = MessagingEnvelopeParser.unwrap(
        <String, dynamic>{
          'success': true,
          'code': 'PLT000',
          'message': 'Conversations retrieved.',
          'data': <String, dynamic>{'items': <dynamic>[]},
        },
      );
      expect((data['items'] as List), isEmpty);
    });

    test('maps PLT004 to notFound with the server message', () {
      expect(
        () => MessagingEnvelopeParser.unwrap(<String, dynamic>{
          'success': false,
          'code': 'PLT004',
          'message': 'Conversation not found.',
          'data': null,
        }),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.notFound,
              )
              .having(
                (ApiException e) => e.message,
                'message',
                'Conversation not found.',
              ),
        ),
      );
    });
  });

  group('Messaging DTO + mapper', () {
    test('conversation maps preview and timestamps', () {
      final Conversation conversation = MessagingMapper.conversationToEntity(
        ConversationDto.fromJson(FakeMessagingRemote.conversationRow()),
      );
      expect(conversation.id, 'conv-1');
      expect(conversation.contractId, 'contract-1');
      expect(conversation.lastMessagePreview, 'See you Monday');
      expect(conversation.hasMessages, isTrue);
    });

    test('message maps opaquely (ciphertext untouched)', () {
      final ConversationMessage message = MessagingMapper.messageToEntity(
        MessageDto.fromJson(<String, dynamic>{
          'id': 'm-1',
          'conversation_id': 'conv-1',
          'sender_entity_id': 'pro-1',
          'body_encrypted': '{"c":"abc","i":"def","t":"ghi"}',
          'body_preview': 'Hello there',
          'client_message_id': 'cm-1',
          'created_at': '2026-09-05T11:00:00Z',
        }),
      );
      expect(message.bodyEncrypted, '{"c":"abc","i":"def","t":"ghi"}');
      expect(message.decryptedBody, isNull);
      expect(message.bodyPreview, 'Hello there');
    });

    test('list envelope degrades missing items to empty', () {
      final ConversationListEnvelopeDto envelope =
          ConversationListEnvelopeDto.fromJson(<String, dynamic>{
            'has_more': false,
          });
      expect(envelope.conversations, isEmpty);
    });
  });

  group('MessagingRepositoryImpl fail-fast validation', () {
    test('empty ids and bad limits never reach the RPC', () async {
      final MessagingRepositoryImpl repo = MessagingRepositoryImpl(
        remote: FakeMessagingRemote(),
      );
      expect(() => repo.ensureForContract('  '), throwsA(isA<ApiException>()));
      expect(
        () => repo.listConversations(limit: 0),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => repo.listMessages('', limit: 200),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => repo.sendMessage(
          conversationId: 'conv-1',
          bodyEncrypted: '',
          clientMessageId: 'cm-1',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('ensure maps the conversation', () async {
      final MessagingRepositoryImpl repo = MessagingRepositoryImpl(
        remote: FakeMessagingRemote(),
      );
      final Conversation conversation = await repo.ensureForContract(
        'contract-1',
      );
      expect(conversation.id, 'conv-1');
    });
  });
}
