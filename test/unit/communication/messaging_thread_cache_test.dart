import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/data/datasources/local/messaging_local_data_source.dart';

import '../../support/fakes/fake_storage.dart';

void main() {
  group('MessagingLocalDataSource (EP-03-13 thread cache)', () {
    late MessagingLocalDataSource cache;

    setUp(() {
      cache = MessagingLocalDataSource(
        store: LocalStore(FakeStorageEngine()),
      );
    });

    Map<String, dynamic> row(String id) => <String, dynamic>{
      'id': id,
      'conversation_id': 'conv-1',
      'sender_entity_id': 'u1',
      'body_encrypted': '{"c":"eQ==","i":"aQ==","t":"bQ=="}',
      'body_preview': 'Hello',
      'client_message_id': 'cm-$id',
      'created_at': '2026-09-05T10:00:00Z',
    };

    test('thread window round-trips transport JSON only', () async {
      await cache.writeThreadWindow(
        conversationId: 'conv-1',
        messages: <Map<String, dynamic>>[row('m-1'), row('m-2')],
        hasMore: true,
        nextCursor: 'm-2',
      );
      final ThreadWindow? window = await cache.readThreadWindow('conv-1');
      expect(window, isNotNull);
      expect(window!.messages, hasLength(2));
      expect(window.hasMore, isTrue);
      expect(window.nextCursor, 'm-2');
      // No verified plaintext is ever persisted — only transport fields.
      expect(window.messages.first.containsKey('decryptedBody'), isFalse);
    });

    test('missing window reads null', () async {
      expect(await cache.readThreadWindow('conv-unknown'), isNull);
    });

    test('draft write/read/clear round-trips', () async {
      await cache.writeDraft('conv-1', 'half-typed reply');
      expect(await cache.readDraft('conv-1'), 'half-typed reply');
      await cache.clearDraft('conv-1');
      expect(await cache.readDraft('conv-1'), isNull);
    });

    test('blank draft clears the entry', () async {
      await cache.writeDraft('conv-1', 'something');
      await cache.writeDraft('conv-1', '   ');
      expect(await cache.readDraft('conv-1'), isNull);
    });

    test('clearAll evicts windows and drafts (logout)', () async {
      await cache.writeThreadWindow(
        conversationId: 'conv-1',
        messages: <Map<String, dynamic>>[row('m-1')],
        hasMore: false,
      );
      await cache.writeDraft('conv-1', 'draft');
      await cache.clearAll();
      expect(await cache.readThreadWindow('conv-1'), isNull);
      expect(await cache.readDraft('conv-1'), isNull);
    });

    test('ThreadWindow.fromJson tolerates malformed payloads', () {
      final ThreadWindow window = ThreadWindow.fromJson(
        const <String, dynamic>{},
      );
      expect(window.messages, isEmpty);
      expect(window.hasMore, isFalse);
      expect(window.nextCursor, isNull);
    });
  });
}
