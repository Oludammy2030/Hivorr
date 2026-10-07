import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/core/sync/sync_config.dart';
import 'package:hivorr/data/datasources/local/messaging_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/messaging_realtime_data_source.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';

import '../../support/fakes/fake_storage.dart';

SyncConfig _testSyncConfig() => const SyncConfig(
  maxQueueDepth: 100,
  defaultMaxRetries: 3,
  baseDelay: Duration(milliseconds: 1),
  maxDelay: Duration(milliseconds: 10),
  jitterMax: Duration(milliseconds: 1),
  defaultPriority: 10,
  drainBatchSize: 20,
);

/// Repository fake with real-crypto rows and scripted send behavior.
class ScriptedMessagingRepository implements MessagingRepository {
  static const String contractId = 'contract-1';
  static const String conversationId = 'conv-1';

  /// Failures to throw (in order) on the next `sendMessage` calls.
  final List<ApiException> sendFailures = <ApiException>[];

  /// Server-side rows keyed by `client_message_id` (dedup mirror).
  final Map<String, ConversationMessage> serverRows =
      <String, ConversationMessage>{};

  int sendCalls = 0;

  Conversation _conversation() => Conversation(
    id: conversationId,
    contractId: contractId,
    createdAt: DateTime.utc(2026, 9, 5, 10),
    updatedAt: DateTime.utc(2026, 9, 5, 11),
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
    messages: serverRows.values.toList(growable: false),
    hasMore: false,
  );

  @override
  Future<ConversationMessage> sendMessage({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  }) async {
    sendCalls++;
    if (sendFailures.isNotEmpty) {
      throw sendFailures.removeAt(0);
    }
    // Server `ON CONFLICT (client_message_id) DO NOTHING` mirror.
    final ConversationMessage? existing = serverRows[clientMessageId];
    if (existing != null) return existing;
    final ConversationMessage row = ConversationMessage(
      id: 'srv-$sendCalls',
      conversationId: conversationId,
      senderEntityId: 'u1',
      bodyEncrypted: bodyEncrypted,
      bodyPreview: bodyPreview,
      clientMessageId: clientMessageId,
      createdAt: DateTime.now().toUtc(),
    );
    serverRows[clientMessageId] = row;
    return row;
  }
}

/// Never-emitting realtime fake (offline tests need no live channel).
class SilentRealtime implements MessagingRealtimeDataSource {
  final StreamController<MessageDto> _controller =
      StreamController<MessageDto>.broadcast();

  @override
  Stream<MessageDto> messagesFor(String conversationId) =>
      _controller.stream;

  @override
  Future<void> unsubscribe(String conversationId) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

MessagingProvider _provider(
  ScriptedMessagingRepository repo, {
  required bool online,
  ActionQueue? outbox,
}) => MessagingProvider(
  service: MessagingService(repository: repo),
  realtime: SilentRealtime(),
  cache: MessagingLocalDataSource(store: LocalStore(FakeStorageEngine())),
  outbox:
      outbox ??
      ActionQueue(engine: FakeStorageEngine(), config: _testSyncConfig()),
  isOnline: () => online,
);

void main() {
  group('MessagingService.isRetryable (EP-03-13 queue gate)', () {
    test('transient failures queue; authoritative rejections do not', () {
      for (final ApiExceptionKind kind in <ApiExceptionKind>[
        ApiExceptionKind.network,
        ApiExceptionKind.timeout,
        ApiExceptionKind.server,
        ApiExceptionKind.unknown,
      ]) {
        expect(
          MessagingService.isRetryable(
            ApiException(kind: kind, message: 'x'),
          ),
          isTrue,
          reason: '$kind should queue',
        );
      }
      for (final ApiExceptionKind kind in <ApiExceptionKind>[
        ApiExceptionKind.auth,
        ApiExceptionKind.forbidden,
        ApiExceptionKind.validation,
        ApiExceptionKind.notFound,
        ApiExceptionKind.conflict,
      ]) {
        expect(
          MessagingService.isRetryable(
            ApiException(kind: kind, message: 'x'),
          ),
          isFalse,
          reason: '$kind should surface immediately',
        );
      }
    });
  });

  group('MessagingProvider offline queue (EP-03-13)', () {
    test('offline send queues durably with an optimistic pending echo',
        () async {
      final ScriptedMessagingRepository repo = ScriptedMessagingRepository();
      final ActionQueue outbox = ActionQueue(
        engine: FakeStorageEngine(),
        config: _testSyncConfig(),
      );
      final MessagingProvider provider = _provider(
        repo,
        online: false,
        outbox: outbox,
      );
      await provider.select(ScriptedMessagingRepository.conversationId);

      await provider.send('Hello from airplane mode');

      expect(repo.sendCalls, 0);
      expect(provider.pendingCount, 1);
      expect(provider.messages, hasLength(1));
      expect(provider.messages.single.decryptedBody, 'Hello from airplane mode');
      final List<String> keys = await outbox.peek().then(
        (actions) => actions.map((a) => a.endpoint).toList(),
      );
      expect(keys, <String>[MessagingService.offlineEndpoint]);
      provider.dispose();
    });

    test('replay flushes exactly-once and a second replay is a no-op',
        () async {
      final ScriptedMessagingRepository repo = ScriptedMessagingRepository();
      final ActionQueue outbox = ActionQueue(
        engine: FakeStorageEngine(),
        config: _testSyncConfig(),
      );
      final MessagingProvider provider = _provider(
        repo,
        online: false,
        outbox: outbox,
      );
      await provider.select(ScriptedMessagingRepository.conversationId);
      await provider.send('queued hello');

      await provider.replayQueued();

      expect(repo.sendCalls, 1);
      expect(repo.serverRows, hasLength(1));
      expect(provider.pendingCount, 0);
      expect(await outbox.peek(), isEmpty);

      // Idempotent second replay: same `client_message_id` dedups.
      await provider.replayQueued();
      expect(repo.serverRows, hasLength(1));
      expect(provider.messages, hasLength(1));
      provider.dispose();
    });

    test('online retryable failure auto-queues instead of throwing',
        () async {
      final ScriptedMessagingRepository repo = ScriptedMessagingRepository()
        ..sendFailures.add(
          const ApiException(
            kind: ApiExceptionKind.network,
            message: 'socket reset',
          ),
        );
      final MessagingProvider provider = _provider(repo, online: true);
      await provider.select(ScriptedMessagingRepository.conversationId);

      await provider.send('flaky hello');

      expect(provider.pendingCount, 1);
      expect(provider.hasFailedSends, isFalse);
      provider.dispose();
    });

    test('online authoritative failure surfaces without queueing', () async {
      final ScriptedMessagingRepository repo = ScriptedMessagingRepository()
        ..sendFailures.add(
          const ApiException(
            kind: ApiExceptionKind.validation,
            message: 'Invalid encrypted payload size.',
            code: 'PLT003',
          ),
        );
      final MessagingProvider provider = _provider(repo, online: true);
      await provider.select(ScriptedMessagingRepository.conversationId);

      await expectLater(provider.send('bad payload'), throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'PLT003',
        ),
      ));
      expect(provider.pendingCount, 0);
      provider.dispose();
    });

    test('validation still rejects blank text before transport', () async {
      final ScriptedMessagingRepository repo = ScriptedMessagingRepository();
      final MessagingProvider provider = _provider(repo, online: false);
      await provider.select(ScriptedMessagingRepository.conversationId);
      await expectLater(provider.send('   '), throwsA(isA<ApiException>()));
      provider.dispose();
    });
  });

  group('MessagingProvider.clearCache (EP-03-13 logout eviction)', () {
    test('evicts cached windows and drafts', () async {
      final ScriptedMessagingRepository repo = ScriptedMessagingRepository();
      final MessagingLocalDataSource cache = MessagingLocalDataSource(
        store: LocalStore(FakeStorageEngine()),
      );
      final MessagingProvider provider = MessagingProvider(
        service: MessagingService(repository: repo),
        cache: cache,
      );
      await cache.writeThreadWindow(
        conversationId: ScriptedMessagingRepository.conversationId,
        messages: const <Map<String, dynamic>>[],
        hasMore: false,
      );
      await cache.writeDraft(
        ScriptedMessagingRepository.conversationId,
        'unsent draft',
      );

      await provider.clearCache();

      expect(
        await cache.readThreadWindow(
          ScriptedMessagingRepository.conversationId,
        ),
        isNull,
      );
      expect(
        await cache.readDraft(ScriptedMessagingRepository.conversationId),
        isNull,
      );
      provider.dispose();
    });

    test('no cache wired is a safe no-op', () async {
      final ScriptedMessagingRepository repo = ScriptedMessagingRepository();
      final MessagingProvider provider = MessagingProvider(
        service: MessagingService(repository: repo),
      );
      await provider.clearCache();
      provider.dispose();
    });
  });
}
