// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/systems/communication/services/message_crypto.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;
import 'package:uuid/uuid.dart';

/// Thin facade over [MessagingRepository] consumed by [MessagingProvider]
/// (EP-04-04).
///
/// Owns the plaintext boundary: [sendText] encrypts via [MessageCrypto]
/// before transport, [decryptMessage]/[decryptMessages] verify after
/// transport (failures surface as `null` → UI placeholder, never plaintext).
/// Adds PII-safe structured [HivorrLogger] output (ids and counts only —
/// never bodies or previews) and `communication.*` [PerformanceTracer] spans.
class MessagingService {
  MessagingService({
    required MessagingRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
    Uuid? uuid,
  }) : _repository = repository,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor(),
       _uuid = uuid ?? const Uuid();

  final MessagingRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;
  final Uuid _uuid;

  /// `true` when [text] is 1–4000 chars after trim (client send bound).
  static bool validateText(String text) {
    final int length = text.trim().length;
    return length >= 1 && length <= MessageCrypto.maxPlaintextLength;
  }

  /// Durable outbox endpoint for offline `message_send` replay (EP-03-13).
  ///
  /// The generic `ActionQueue` persists the payload; replay is provider-driven
  /// through `supabase.rpc('message_send')` (deduplicated by
  /// `client_message_id`), not through the Dio-based `SyncEngine.drain`.
  static const String offlineEndpoint = '/rpc/message_send';

  /// HTTP method recorded on offline `message_send` actions.
  static const String offlineMethod = 'POST';

  /// Queue priority for offline messages (2 = interactive, above background).
  static const int offlinePriority = 2;

  /// Builds the durable payload for an offline send (no transport here).
  static Map<String, dynamic> offlinePayload({
    required String conversationId,
    required String bodyEncrypted,
    String? bodyPreview,
    required String clientMessageId,
  }) => <String, dynamic>{
    'conversation_id': conversationId,
    'body_encrypted': bodyEncrypted,
    'body_preview': bodyPreview,
    'client_message_id': clientMessageId,
  };

  /// Whether a failed send is worth queueing for replay (EP-03-13).
  ///
  /// Transient transport failures (`network`, `timeout`, `server`, `unknown`)
  /// are queued; authoritative rejections (`validation`, `notFound`,
  /// `forbidden`, `conflict`, `auth`) are surfaced immediately and never
  /// queued — replaying them cannot succeed.
  static bool isRetryable(ApiException error) => switch (error.kind) {
    ApiExceptionKind.network ||
    ApiExceptionKind.timeout ||
    ApiExceptionKind.server ||
    ApiExceptionKind.unknown => true,
    ApiExceptionKind.auth ||
    ApiExceptionKind.forbidden ||
    ApiExceptionKind.validation ||
    ApiExceptionKind.notFound ||
    ApiExceptionKind.conflict => false,
  };

  /// Encrypts [text] for the [contractId] thread without sending it.
  ///
  /// Used by the offline path: the ciphertext + preview are persisted to the
  /// durable outbox first, then sent when connectivity returns. Throws
  /// [ArgumentError] when [text] is blank or exceeds
  /// [MessageCrypto.maxPlaintextLength].
  Future<OutgoingMessage> prepareOutgoing({
    required String contractId,
    required String text,
  }) async {
    final String trimmed = text.trim();
    final String bodyEncrypted = await MessageCrypto.encryptText(
      contractId: contractId,
      text: trimmed,
    );
    return OutgoingMessage(
      bodyEncrypted: bodyEncrypted,
      bodyPreview: MessageCrypto.previewOf(trimmed),
      clientMessageId: _uuid.v4(),
      plainText: trimmed,
    );
  }

  /// Ensures (idempotently) the thread for [contractId].
  Future<Conversation> ensureForContract(String contractId) =>
      _tracedAndLogged('communication.ensure', () async {
        final Conversation conversation = await _repository.ensureForContract(
          contractId,
        );
        _logger?.info('Conversation ensured', <String, Object?>{
          'conversationId': _redactor.redact(conversation.id),
        });
        return conversation;
      });

  /// Lists threads for the current entity.
  Future<ConversationPage> listConversations({int limit = 20}) =>
      _tracedAndLogged('communication.list', () async {
        return _repository.listConversations(limit: limit);
      });

  /// Lists messages with verified plaintext applied where possible.
  ///
  /// Returns newest-first (server order) plus whether older pages exist;
  /// callers reverse for display.
  Future<DecryptedMessagePage> listDecryptedMessages({
    required String conversationId,
    required String contractId,
    int limit = 30,
    String? cursor,
  }) => _tracedAndLogged('communication.messages', () async {
    final MessagePage page = await _repository.listMessages(
      conversationId,
      limit: limit,
      cursor: cursor,
    );
    final List<ConversationMessage> decrypted = <ConversationMessage>[];
    for (final ConversationMessage message in page.messages) {
      decrypted.add(await decryptMessage(contractId, message));
    }
    _logger?.info('Messages fetched', <String, Object?>{
      'conversationId': _redactor.redact(conversationId),
      'messageCount': decrypted.length,
    });
    return DecryptedMessagePage(
      messages: decrypted,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  });

  /// Verifies one message, applying plaintext or leaving it undecrypted.
  Future<ConversationMessage> decryptMessage(
    String contractId,
    ConversationMessage message,
  ) async {
    final String? plaintext = await MessageCrypto.decryptText(
      contractId: contractId,
      bodyEncrypted: message.bodyEncrypted,
    );
    if (plaintext == null) {
      _logger?.warning('Message failed authentication', <String, Object?>{
        'messageId': _redactor.redact(message.id),
      });
      return message;
    }
    return message.decrypted(plaintext);
  }

  /// Encrypts [text] and sends it, returning the decrypted echo.
  Future<ConversationMessage> sendText({
    required String conversationId,
    required String contractId,
    required String text,
  }) => _tracedAndLogged('communication.send', () async {
    final OutgoingMessage outgoing = await prepareOutgoing(
      contractId: contractId,
      text: text,
    );
    return sendPrepared(
      conversationId: conversationId,
      outgoing: outgoing,
    );
  });

  /// Sends a pre-encrypted [outgoing] payload (EP-03-13 replay path).
  ///
  /// Used when the ciphertext was prepared before connectivity returned
  /// (offline queue): encrypt-once, send-once, with the same
  /// `client_message_id` deduplicating double-taps server-side
  /// (`ON CONFLICT DO NOTHING`).
  Future<ConversationMessage> sendPrepared({
    required String conversationId,
    required OutgoingMessage outgoing,
  }) => _tracedAndLogged('communication.send', () async {
    final ConversationMessage sent = await _repository.sendMessage(
      conversationId: conversationId,
      bodyEncrypted: outgoing.bodyEncrypted,
      bodyPreview: outgoing.bodyPreview,
      clientMessageId: outgoing.clientMessageId,
    );
    _logger?.info('Message sent', <String, Object?>{
      'conversationId': _redactor.redact(conversationId),
      'messageId': _redactor.redact(sent.id),
    });
    return sent.decrypted(outgoing.plainText);
  });

  /// Wraps [action] in a `communication.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'communication');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: const SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'span': name},
      );
      rethrow;
    }
  }
}

/// An encrypted-but-unsent message (EP-03-13 offline path).
///
/// Ciphertext is opaque AES-GCM output; [plainText] lives only in memory
/// for the optimistic echo and is never persisted by the outbox (the queue
/// stores [bodyEncrypted] + preview + `client_message_id` only).
class OutgoingMessage {
  const OutgoingMessage({
    required this.bodyEncrypted,
    required this.bodyPreview,
    required this.clientMessageId,
    required this.plainText,
  });

  final String bodyEncrypted;
  final String bodyPreview;
  final String clientMessageId;
  final String plainText;
}
