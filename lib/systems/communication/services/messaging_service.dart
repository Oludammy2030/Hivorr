// ignore_for_file: prefer_initializing_formals

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
    final String trimmed = text.trim();
    final String bodyEncrypted = await MessageCrypto.encryptText(
      contractId: contractId,
      text: trimmed,
    );
    final ConversationMessage sent = await _repository.sendMessage(
      conversationId: conversationId,
      bodyEncrypted: bodyEncrypted,
      bodyPreview: MessageCrypto.previewOf(trimmed),
      clientMessageId: _uuid.v4(),
    );
    _logger?.info('Message sent', <String, Object?>{
      'conversationId': _redactor.redact(conversationId),
      'messageId': _redactor.redact(sent.id),
    });
    return sent.decrypted(trimmed);
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
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
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
