import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/data/datasources/local/messaging_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/messaging_realtime_data_source.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/systems/communication/services/message_crypto.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';

import '../../support/fakes/fake_storage.dart';

/// Controllable realtime fake: tests push inserts deterministically.
class FakeMessagingRealtime implements MessagingRealtimeDataSource {
  final Map<String, StreamController<MessageDto>> controllers =
      <String, StreamController<MessageDto>>{};
  final List<String> unsubscribed = <String>[];

  @override
  Stream<MessageDto> messagesFor(String conversationId) {
    final StreamController<MessageDto> controller =
        controllers.putIfAbsent(
          conversationId,
          () => StreamController<MessageDto>.broadcast(),
        );
    return controller.stream;
  }

  void emit(String conversationId, MessageDto dto) {
    controllers[conversationId]?.add(dto);
  }

  @override
  Future<void> unsubscribe(String conversationId) async {
    unsubscribed.add(conversationId);
    await controllers.remove(conversationId)?.close();
  }

  @override
  Future<void> dispose() async {
    final List<StreamController<MessageDto>> open = controllers.values.toList(
      growable: false,
    );
    controllers.clear();
    for (final StreamController<MessageDto> c in open) {
      await c.close();
    }
  }
}

/// Single-thread repository with real-crypto rows.
class StubMessagingRepository implements MessagingRepository {
  static const String contractId = 'contract-1';
  static const String conversationId = 'conv-1';

  Conversation _conversation() => Conversation(
    id: conversationId,
    contractId: contractId,
    createdAt: DateTime.utc(2026, 9, 5, 10),
    updatedAt: DateTime.utc(2026, 9, 5, 11),
  );

  Future<ConversationMessage> _row(String id, String text) async =>
      ConversationMessage(
        id: id,
        conversationId: conversationId,
        senderEntityId: 'u2',
        bodyEncrypted: await MessageCrypto.encryptText(
          contractId: contractId,
          text: text,
        ),
        bodyPreview: text,
        clientMessageId: 'cm-$id',
        createdAt: DateTime.utc(2026, 9, 5, 11),
      );

  @override
  Future<Conversation> ensureForContract(String contractId) async =>
      _conversation();

  @override
  Future<ConversationPage> listConversations({
    int limit = 20,
    String? cursor,
  }) async => ConversationPage(
    conversations: <Conversation>[_conversation()],
    hasMore: false,
  );

  @override
  Future<MessagePage> listMessages(
    String conversationId, {
    int limit = 30,
    String? cursor,
  }) async => MessagePage(
    messages: <ConversationMessage>[await _row('m-1', 'Seed hello')],
    hasMore: false,
  );

  @override
  Future<ConversationMessage> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  }) async => throw UnimplementedError();
}

Future<MessageDto> _liveDto(String id, String text) async => MessageDto(
  id: id,
  conversationId: StubMessagingRepository.conversationId,
  senderEntityId: 'u2',
  bodyEncrypted: await MessageCrypto.encryptText(
    contractId: StubMessagingRepository.contractId,
    text: text,
  ),
  bodyPreview: text,
  clientMessageId: 'cm-$id',
  createdAt: DateTime.now().toUtc(),
);

void main() {
  group('MessagingProvider realtime (EP-03-13)', () {
    test('live insert appends decrypted; duplicates and foreign rows ignored',
        () async {
      final StubMessagingRepository repo = StubMessagingRepository();
      final FakeMessagingRealtime realtime = FakeMessagingRealtime();
      final MessagingProvider provider = MessagingProvider(
        service: MessagingService(repository: repo),
        realtime: realtime,
        cache: MessagingLocalDataSource(
          store: LocalStore(FakeStorageEngine()),
        ),
      );
      await provider.select(StubMessagingRepository.conversationId);
      expect(provider.messages, hasLength(1));

      realtime.emit(
        StubMessagingRepository.conversationId,
        await _liveDto('m-2', 'Realtime hello'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.messages, hasLength(2));
      expect(provider.messages.last.decryptedBody, 'Realtime hello');

      // Duplicate delivery (same row id) is ignored — no double bubble.
      realtime.emit(
        StubMessagingRepository.conversationId,
        await _liveDto('m-2', 'Realtime hello'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.messages, hasLength(2));

      // Foreign conversation rows never leak into the open thread.
      final MessageDto foreign = MessageDto(
        id: 'm-x',
        conversationId: 'conv-other',
        senderEntityId: 'u9',
        bodyEncrypted: 'opaque',
        clientMessageId: 'cm-x',
        createdAt: DateTime.now().toUtc(),
      );
      realtime.emit('conv-other', foreign);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.messages, hasLength(2));

      provider.dispose();
      // Unsubscribe is best-effort async teardown on dispose.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(realtime.unsubscribed, contains('conv-1'));
      await realtime.dispose();
    });

    test('tampered realtime rows render as placeholders, never plaintext',
        () async {
      final StubMessagingRepository repo = StubMessagingRepository();
      final FakeMessagingRealtime realtime = FakeMessagingRealtime();
      final MessagingProvider provider = MessagingProvider(
        service: MessagingService(repository: repo),
        realtime: realtime,
      );
      await provider.select(StubMessagingRepository.conversationId);

      realtime.emit(
        StubMessagingRepository.conversationId,
        MessageDto(
          id: 'm-evil',
          conversationId: StubMessagingRepository.conversationId,
          senderEntityId: 'u2',
          bodyEncrypted: '{"c":"@@@","i":"@@@","t":"@@@"}',
          bodyPreview: 'forged preview',
          clientMessageId: 'cm-evil',
          createdAt: DateTime.now().toUtc(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.messages, hasLength(2));
      expect(provider.messages.last.decryptedBody, isNull);
      provider.dispose();
      await realtime.dispose();
    });
  });
}
