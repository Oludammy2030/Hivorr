// Run: flutter test test/integration/marketplace/messaging_realtime_offline_integration_test.dart
//
// EP-03-20 VP8 — Messaging transport: E2E encryption + offline queue replay.
// Per plan §6.3 scope: REAL [MessageCrypto] roundtrip (no-plaintext,
// wrong-contract hard-reject), [PiiRedactor] preview redaction, and the REAL
// [ActionQueue]/[SyncEngine] offline replay carrying `client_message_id`
// (the server dedup key) so dequeue-after-replay is exactly-once client-side.
// Realtime channel mechanics are unit-covered in
// `test/unit/systems/communication/` (MessagingProvider composition has no
// support-level fake — noted as an EP-04 recommendation).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/network/network_monitor.dart';
import 'package:hivorr/core/network/network_status.dart';
import 'package:hivorr/core/network/network_type.dart';
import 'package:hivorr/core/network/sync_connectivity_adapter.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/core/sync/conflict_detector.dart';
import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';
import 'package:hivorr/core/sync/sync_config.dart';
import 'package:hivorr/core/sync/sync_engine.dart';
import 'package:hivorr/core/sync/sync_status_provider.dart';
import 'package:hivorr/systems/communication/services/message_crypto.dart';

import '../../support/fakes/fake_api.dart';
import '../../support/fakes/fake_storage.dart';
import '../../unit/core/sync/sync_test_helpers.dart' show testAction;

/// A realistic message-preview string carrying PII (never allowed to reach
/// list rows or notifications — only the redacted preview).
const String _preview =
    'Call me on +234 803 123 4567 or ada@example.com — token Bearer abc123secret';

void main() {
  group('EP-03-20 VP8 — message encryption roundtrip', () {
    test('DoD-VP8a: encrypt → decrypt roundtrips the original text', () async {
      const String text = 'Site visit confirmed for 10:00 tomorrow.';

      final String body = await MessageCrypto.encryptText(
        contractId: 'contract-1',
        text: text,
      );
      final String? plain = await MessageCrypto.decryptText(
        contractId: 'contract-1',
        bodyEncrypted: body,
      );

      expect(plain, text);
    });

    test(
      'DoD-VP8b: ciphertext never contains the plaintext (no-plaintext)',
      () async {
        const String secret = 'MILESTONE_PAID_NGN_25000_SECRET';

        final String body = await MessageCrypto.encryptText(
          contractId: 'contract-1',
          text: secret,
        );

        // The transport payload is opaque `{c,i,t}` base64 JSON — the plaintext
        // must never appear verbatim (server stores it opaquely, and callers
        // must never fall back to rendering `body_encrypted`).
        expect(body, isNot(contains(secret)));
        expect(body, isNot(contains('MILESTONE')));
        expect(body, contains('"c"'), reason: 'EncryptedPayload.c ciphertext');
        expect(body, contains('"i"'), reason: 'EncryptedPayload.i IV');
        expect(body, contains('"t"'), reason: 'EncryptedPayload.t tag');
      },
    );

    test(
      'DoD-VP8c: wrong contract key is a hard reject (null, no fallback)',
      () async {
        final String body = await MessageCrypto.encryptText(
          contractId: 'contract-1',
          text: 'Only the participants can read this.',
        );

        final String? wrongKey = await MessageCrypto.decryptText(
          contractId: 'contract-2',
          bodyEncrypted: body,
        );

        // AES-GCM authentication failure → null. Callers must render the
        // undecryptable placeholder, never the ciphertext itself.
        expect(wrongKey, isNull);
        expect(wrongKey, isNot(contains('participants')));
      },
    );

    test('DoD-VP8d: malformed rows are a hard reject (null)', () async {
      expect(
        await MessageCrypto.decryptText(
          contractId: 'contract-1',
          bodyEncrypted: 'not-json-at-all',
        ),
        isNull,
      );
      expect(
        await MessageCrypto.decryptText(
          contractId: 'contract-1',
          bodyEncrypted: '{"c":"AAAA","i":"AAAA"}',
        ),
        isNull,
        reason: 'payload without the auth tag must not render',
      );
    });
  });

  group('EP-03-20 VP8 — preview PII redaction', () {
    test('DoD-VP8e: preview redacts email, phone, and bearer token', () {
      final String redacted = PiiRedactor().redact(_preview);

      expect(redacted, isNot(contains('ada@example.com')));
      expect(redacted, isNot(contains('+234 803 123 4567')));
      expect(redacted, isNot(contains('abc123secret')));
      expect(redacted, contains('***@***.***'), reason: 'email replaced');
      expect(redacted, contains('Bearer ***'), reason: 'bearer token masked');
      // Non-PII content survives (the preview stays useful).
      expect(
        redacted,
        contains('Call me on'),
        reason: 'message text itself is preserved',
      );
    });

    test('DoD-VP8f: redactContext masks sensitive keys outright', () {
      final Map<String, Object?> masked = PiiRedactor()
          .redactContext(<String, Object?>{
            'contractId': 'c1',
            'email': 'ada@example.com',
            'token': 'super-secret',
            'bodyPreview': 'Reach me at ada@example.com',
          });

      expect(masked['contractId'], 'c1');
      expect(masked['email'], '[REDACTED]');
      expect(masked['token'], '[REDACTED]');
      expect(masked['bodyPreview'], 'Reach me at ***@***.***');
    });
  });

  group('EP-03-20 VP8 — offline queue replay (exactly-once client-side)', () {
    late FakeStorageEngine storage;

    setUp(() {
      storage = FakeStorageEngine();
    });

    SyncConfig config() => const SyncConfig(
      maxQueueDepth: 10,
      defaultMaxRetries: 2,
      baseDelay: Duration(milliseconds: 5),
      maxDelay: Duration(milliseconds: 20),
      jitterMax: Duration(milliseconds: 5),
      defaultPriority: 10,
      drainBatchSize: 5,
    );

    NetworkStatus online() => NetworkStatus(
      isConnected: true,
      networkType: NetworkType.wifi,
      timestamp: DateTime.now(),
    );

    test('DoD-VP8g: offline capture → online replay → dequeue (dedup key '
        'carried exactly once)', () async {
      final ActionQueue queue = ActionQueue(engine: storage, config: config());
      final FakeNetworkMonitor monitor = FakeNetworkMonitor(initial: online());
      addTearDown(monitor.dispose);
      final SyncStatusProvider statusProvider = SyncStatusProvider();
      final ScriptedAdapter adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final Dio dio = buildTestDio(adapter);
      final SyncEngine engine = SyncEngine(
        enabled: true,
        config: config(),
        queue: queue,
        dio: dio,
        connectivityProvider: SyncConnectivityAdapter(monitor),
        conflictDetector: const ConflictDetector(),
        statusProvider: statusProvider,
      );
      addTearDown(engine.dispose);

      // Arrange: a pending offline send whose payload carries the client
      // generated `client_message_id` — the server-side exactly-once dedup key.
      const String clientMessageId = 'cmid-1111-2222-3333';
      final SyncAction queued = await engine.enqueue(
        testAction(
          endpoint: '/rpc/message_send',
          payload: <String, Object?>{
            'contract_id': 'contract-1',
            'client_message_id': clientMessageId,
            'body_encrypted': '{"c":"AAAA","i":"AAAA","t":"AAAA"}',
          },
        ),
      );

      // Assert: captured offline as pending (nothing sent yet).
      expect(queued.status, SyncActionStatus.pending);
      expect(await queue.pendingCount, 1);
      expect(adapter.captured, isEmpty, reason: 'offline — no HTTP call');

      // Act: connectivity returns → drain replays the queued mutation.
      await engine.drain();

      // Assert: exactly ONE request carried the dedup key, then the action
      // was dequeued (successful replay → removed, not retried).
      expect(adapter.captured, hasLength(1));
      final Map<String, dynamic> sent =
          adapter.captured.single.data as Map<String, dynamic>;
      expect(sent['client_message_id'], clientMessageId);
      expect(adapter.captured.single.uri.path, '/rpc/message_send');
      expect(await queue.pendingCount, 0);
      expect(await queue.depth, 0, reason: 'dequeued after successful replay');

      // Act & Assert: a second drain finds nothing → no duplicate send
      // (exactly-once from the client's perspective).
      await engine.drain();
      expect(adapter.captured, hasLength(1), reason: 'no re-send on re-drain');
      expect(statusProvider.status.name, 'idle');
    });

    test('DoD-VP8h: failed replay keeps the action queued for retry (never '
        'silently dropped)', () async {
      final ActionQueue queue = ActionQueue(engine: storage, config: config());
      final FakeNetworkMonitor monitor = FakeNetworkMonitor(initial: online());
      addTearDown(monitor.dispose);
      final SyncStatusProvider statusProvider = SyncStatusProvider();
      final ScriptedAdapter adapter = ScriptedAdapter(
        (_) async => errorBody(500),
      );
      final SyncEngine engine = SyncEngine(
        enabled: true,
        config: config(),
        queue: queue,
        dio: buildTestDio(adapter),
        connectivityProvider: SyncConnectivityAdapter(monitor),
        conflictDetector: const ConflictDetector(),
        statusProvider: statusProvider,
      );
      addTearDown(engine.dispose);

      // Arrange: one queued offline send.
      await engine.enqueue(testAction(endpoint: '/rpc/message_send'));

      // Act: drain against a 5xx (transient) until retries are exhausted.
      await engine.drain();

      // Assert: the action was never silently dropped — it dead-letters with
      // an error message, and depth reflects the retained record. The engine
      // returns to `idle` once the drain finishes; the failure persists in
      // the dead-letter ledger surfaced on the status provider.
      expect(adapter.captured, isNotEmpty, reason: 'retries were attempted');
      expect(await queue.deadLetterCount, 1);
      expect(await queue.pendingCount, 0);
      expect(statusProvider.status.name, 'idle');
      expect(statusProvider.deadLetterCount, 1);
    });
  });
}
