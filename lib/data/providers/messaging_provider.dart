// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';
import 'package:hivorr/data/datasources/local/messaging_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/messaging_realtime_data_source.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/mappers/messaging_mapper.dart';
import 'package:hivorr/data/models/conversation_dto.dart';
import 'package:hivorr/data/repositories/messaging_repository.dart';
import 'package:hivorr/systems/communication/services/messaging_service.dart';

/// Notification channel used for messaging events (EP-04-04).
abstract final class MessagingNotificationChannel {
  const MessagingNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Load lifecycle of the messaging provider (EP-04-04).
enum MessagingLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing conversations and thread state to the widget tree
/// (EP-04-04, Realtime + offline extensions EP-03-13).
///
/// Depends only on the [MessagingService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized conversation list, the
/// selection (conversation + chronological messages), a
/// [WidgetsBindingObserver] lifecycle gate (no background refreshes), and a
/// local "message received" hook for threads refreshed while open. Ciphertext
/// is never exposed — messages carry verified plaintext or render as
/// undecryptable placeholders downstream.
///
/// EP-03-13 additions (all optional, backward-compatible): RLS-filtered
/// Realtime subscription per open thread (single-append, deduplicated),
/// durable offline outbox (`ActionQueue`, provider-driven replay through
/// `supabase.rpc`, deduplicated by `client_message_id`), Hive thread-window
/// + draft cache (warm-then-refresh, evicted on logout), and optimistic
/// `pending` / `failed` send states. When no collaborators are supplied the
/// provider behaves exactly as before (direct send, poll-on-resume).
class MessagingProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ///
  /// [notificationProvider] enables the messaging notification hook; [logger]
  /// enables PII-safe structured logging; [clock] is injectable for
  /// deterministic tests.
  ///
  /// EP-03-13 collaborators: [realtime] for live inserts, [cache] for thread
  /// windows + drafts, [outbox] for durable offline sends, [isOnline] as the
  /// connectivity gate (defaults to online when absent, preserving legacy
  /// direct-send behavior in tests).
  MessagingProvider({
    required MessagingService service,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
    MessagingRealtimeDataSource? realtime,
    MessagingLocalDataSource? cache,
    ActionQueue? outbox,
    bool Function()? isOnline,
  }) : _service = service,
       _logger = logger,
       _notificationProvider = notificationProvider,
       _clock = clock ?? DateTime.now,
       _realtime = realtime,
       _cache = cache,
       _outbox = outbox,
       _isOnline = isOnline {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final MessagingService _service;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final DateTime Function() _clock;
  final MessagingRealtimeDataSource? _realtime;
  final MessagingLocalDataSource? _cache;
  final ActionQueue? _outbox;
  final bool Function()? _isOnline;

  List<Conversation> _conversations = const <Conversation>[];
  Conversation? _selected;
  List<ConversationMessage> _messages = const <ConversationMessage>[];
  bool _messagesHasMore = false;
  String? _messagesCursor;
  MessagingLoadState _loadState = MessagingLoadState.idle;
  ApiException? _error;
  bool _refreshing = false;
  bool _sending = false;
  bool _paused = false;
  bool _disposed = false;

  StreamSubscription<MessageDto>? _realtimeSub;
  String? _subscribedConversationId;

  /// Client message ids with an optimistic echo awaiting server ack.
  final Set<String> _pendingClientIds = <String>{};

  /// Client message ids whose queued send last failed and needs retry.
  final Set<String> _failedClientIds = <String>{};

  /// Threads for the current entity, newest first.
  List<Conversation> get conversations => _conversations;

  /// The open thread, or `null` before [select].
  Conversation? get selected => _selected;

  /// Messages of the open thread, oldest first (display order).
  List<ConversationMessage> get messages => _messages;

  /// Whether older messages exist for the open thread.
  bool get messagesHasMore => _messagesHasMore;

  /// The load lifecycle state.
  MessagingLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == MessagingLoadState.loading;

  /// Whether the latest load/refresh succeeded.
  bool get isLoaded => _loadState == MessagingLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// Whether a send is in flight.
  bool get isSending => _sending;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Number of optimistic sends awaiting server acknowledgement.
  int get pendingCount => _pendingClientIds.length;

  /// Whether any queued send needs a retry.
  bool get hasFailedSends => _failedClientIds.isNotEmpty;

  /// Whether [clientMessageId] is still awaiting server ack.
  bool isPending(String clientMessageId) =>
      _pendingClientIds.contains(clientMessageId);

  /// Loads the thread list.
  Future<void> loadConversations() async {
    if (isLoading) return;
    _loadState = MessagingLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final ConversationPage page = await _service.listConversations();
      _conversations = page.conversations;
      _loadState = MessagingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = MessagingLoadState.error;
      _logger?.warning('Conversation list load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Ensures the thread for [contractId] and opens it.
  Future<Conversation> ensureForContract(String contractId) async {
    final Conversation conversation = await _service.ensureForContract(
      contractId,
    );
    if (!_conversations.any((Conversation c) => c.id == conversation.id)) {
      _conversations = <Conversation>[conversation, ..._conversations];
    }
    await select(conversation.id);
    return conversation;
  }

  /// Opens the thread [conversationId], loading messages oldest-first.
  Future<void> select(String conversationId) async {
    if (isLoading) return;
    _loadState = MessagingLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      Conversation? conversation;
      for (final Conversation c in _conversations) {
        if (c.id == conversationId) conversation = c;
      }
      // Deep link before the list hydrated (or beyond the first page):
      // hydrate the list once so decryption has the real contract binding.
      // A truly foreign id still fails closed via message_list (PLT004).
      if (conversation == null) {
        final ConversationPage page = await _service.listConversations();
        _conversations = page.conversations;
        for (final Conversation c in _conversations) {
          if (c.id == conversationId) conversation = c;
        }
      }
      conversation ??= Conversation(
        id: conversationId,
        contractId: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      _selected = conversation;
      // Warm-then-refresh: show the cached window instantly when present;
      // the authoritative server page replaces it below.
      await _hydrateFromCache(conversation);
      final DecryptedMessagePage page = await _service.listDecryptedMessages(
        conversationId: conversationId,
        contractId: conversation.contractId,
      );
      _messages = page.messages.reversed.toList(growable: false);
      _messagesHasMore = page.hasMore;
      _messagesCursor = page.nextCursor;
      _loadState = MessagingLoadState.loaded;
      await _persistWindow(conversation);
      await _subscribeRealtime(conversation);
    } on ApiException catch (e) {
      _error = e;
      _loadState = MessagingLoadState.error;
      _logger?.warning('Thread load failed', <String, Object?>{
        'conversationId': conversationId,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the open thread (pull-to-refresh / lifecycle resume).
  ///
  /// Replays the durable outbox first so reconnects flush offline sends
  /// before the authoritative page loads.
  Future<void> refresh() async {
    final Conversation? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      await replayQueued();
      final Conversation? reread = _selected;
      if (reread == null) return;
      final int before = _messages.length;
      final DecryptedMessagePage page = await _service.listDecryptedMessages(
        conversationId: reread.id,
        contractId: reread.contractId,
      );
      _messages = page.messages.reversed.toList(growable: false);
      _messagesHasMore = page.hasMore;
      _messagesCursor = page.nextCursor;
      _loadState = MessagingLoadState.loaded;
      await _persistWindow(reread);
      if (_messages.length > before) {
        _maybeNotify(
          reread,
          preview: _messages.isEmpty
              ? null
              : _messages.last.bodyPreview ?? _messages.last.decryptedBody,
        );
      }
    } on ApiException catch (e) {
      _error = e;
      _loadState = MessagingLoadState.error;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the next (older) page of the open thread, prepending it.
  Future<void> loadEarlier() async {
    final Conversation? current = _selected;
    if (current == null ||
        _refreshing ||
        _paused ||
        !_messagesHasMore ||
        _messagesCursor == null) {
      return;
    }
    _refreshing = true;
    notifyListeners();
    try {
      final DecryptedMessagePage page = await _service.listDecryptedMessages(
        conversationId: current.id,
        contractId: current.contractId,
        cursor: _messagesCursor,
      );
      final List<ConversationMessage> older = page.messages.reversed.toList(
        growable: false,
      );
      _messages = <ConversationMessage>[...older, ..._messages];
      _messagesHasMore = page.hasMore;
      _messagesCursor = page.nextCursor;
      await _persistWindow(current);
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Encrypts and sends [text] on the open thread, appending the echo.
  ///
  /// With no outbox wired this sends directly (legacy behavior). With an
  /// outbox, offline or transiently-failing sends are persisted to the
  /// durable queue with an optimistic `pending` echo; [replayQueued]
  /// flushes them exactly-once via `client_message_id` dedup.
  Future<void> send(String text) async {
    final Conversation? current = _selected;
    if (current == null || _sending) return;
    if (!MessagingService.validateText(text)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Message must be 1 to 4000 characters.',
        code: 'PLT003',
      );
    }
    final ActionQueue? outbox = _outbox;
    if (outbox == null) {
      await _sendDirect(current, text);
      return;
    }
    final bool online = _isOnline?.call() ?? true;
    if (!online) {
      await _enqueueOffline(current, text);
      return;
    }
    try {
      await _sendDirect(current, text);
    } on ApiException catch (e) {
      if (MessagingService.isRetryable(e)) {
        await _enqueueOffline(current, text);
        return;
      }
      rethrow;
    }
  }

  /// Replays durable offline sends through `supabase.rpc('message_send')`.
  ///
  /// Provider-driven (the Dio-based `SyncEngine.drain` cannot replay
  /// Supabase RPCs): each queued action sends with its stored
  /// `client_message_id`, so server-side `ON CONFLICT DO NOTHING` makes
  /// double-replays idempotent. Best-effort — failures stay queued and
  /// surface via [hasFailedSends] without throwing.
  Future<void> replayQueued() async {
    final ActionQueue? outbox = _outbox;
    if (outbox == null) return;
    List<SyncAction> actions;
    try {
      actions = await outbox.peek();
    } on Object {
      return;
    }
    final Iterable<SyncAction> sends = actions.where(
      (SyncAction a) => a.endpoint == MessagingService.offlineEndpoint,
    );
    for (final SyncAction action in sends) {
      final Map<String, dynamic>? payload = action.payload;
      if (payload == null) continue;
      final String conversationId = payload['conversation_id'] as String? ?? '';
      final String bodyEncrypted = payload['body_encrypted'] as String? ?? '';
      final String clientMessageId =
          payload['client_message_id'] as String? ?? '';
      if (conversationId.isEmpty ||
          bodyEncrypted.isEmpty ||
          clientMessageId.isEmpty) {
        continue;
      }
      try {
        final ConversationMessage sent = await _service.sendPrepared(
          conversationId: conversationId,
          outgoing: OutgoingMessage(
            bodyEncrypted: bodyEncrypted,
            bodyPreview: payload['body_preview'] as String? ?? '',
            clientMessageId: clientMessageId,
            plainText: '',
          ),
        );
        final ConversationMessage resolved = sent.decryptedBody == null ||
                sent.decryptedBody!.isEmpty
            ? sent
            : sent;
        _replaceOptimistic(clientMessageId, resolved);
        try {
          await outbox.dequeue(action.id);
        } on Object {
          // Queue bookkeeping failure must not lose the acked message.
        }
        _pendingClientIds.remove(clientMessageId);
        _failedClientIds.remove(clientMessageId);
      } on ApiException catch (e) {
        if (MessagingService.isRetryable(e)) {
          _failedClientIds.add(clientMessageId);
        } else {
          // Authoritative rejection can never succeed on replay:
          // drop the action so it does not block the queue.
          try {
            await outbox.dequeue(action.id);
          } on Object {
            // Best-effort bookkeeping.
          }
          _pendingClientIds.remove(clientMessageId);
          _failedClientIds.add(clientMessageId);
        }
      } on Object {
        _failedClientIds.add(clientMessageId);
      }
    }
    if (!_disposed) notifyListeners();
  }

  /// Retries failed queued sends (dead-letter recovery UI hook).
  Future<void> retryFailed() => replayQueued();

  /// Reads the composer draft for [conversationId], if any.
  Future<String?> readDraft(String conversationId) async {
    final MessagingLocalDataSource? cache = _cache;
    if (cache == null) return null;
    try {
      return await cache.readDraft(conversationId);
    } on Object {
      return null;
    }
  }

  /// Persists the composer draft (blank text clears the entry).
  Future<void> saveDraft(String conversationId, String text) async {
    final MessagingLocalDataSource? cache = _cache;
    if (cache == null) return;
    try {
      await cache.writeDraft(conversationId, text);
    } on Object {
      // Draft persistence is best-effort; never fail the composer.
    }
  }

  /// Evicts cached windows + drafts (call on logout).
  Future<void> clearCache() async {
    final MessagingLocalDataSource? cache = _cache;
    if (cache == null) return;
    try {
      await cache.clearAll();
    } on Object {
      // Best-effort eviction.
    }
  }

  Future<void> _sendDirect(Conversation current, String text) async {
    _sending = true;
    _error = null;
    notifyListeners();
    try {
      final ConversationMessage sent = await _service.sendText(
        conversationId: current.id,
        contractId: current.contractId,
        text: text,
      );
      _messages = <ConversationMessage>[..._messages, sent];
      try {
        await _cache?.clearDraft(current.id);
      } on Object {
        // Best-effort draft cleanup.
      }
      await _persistWindow(current);
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Message send failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
      rethrow;
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _enqueueOffline(Conversation current, String text) async {
    final ActionQueue? outbox = _outbox;
    if (outbox == null) return;
    _sending = true;
    notifyListeners();
    try {
      final OutgoingMessage outgoing = await _service.prepareOutgoing(
        contractId: current.contractId,
        text: text,
      );
      final SyncAction action = SyncAction(
        id: '',
        type: SyncActionType.create,
        endpoint: MessagingService.offlineEndpoint,
        method: MessagingService.offlineMethod,
        payload: MessagingService.offlinePayload(
          conversationId: current.id,
          bodyEncrypted: outgoing.bodyEncrypted,
          bodyPreview: outgoing.bodyPreview,
          clientMessageId: outgoing.clientMessageId,
        ),
        priority: MessagingService.offlinePriority,
        status: SyncActionStatus.pending,
        retryCount: 0,
        maxRetries: 0,
        createdAt: DateTime.now(),
      );
      try {
        await outbox.enqueue(action);
      } on Object catch (e) {
        _error = const ApiException(
          kind: ApiExceptionKind.unknown,
          message: 'Message could not be queued. Try again.',
        );
        _logger?.warning('Message queue failed', <String, Object?>{
          'error': '$e',
        });
        return;
      }
      _pendingClientIds.add(outgoing.clientMessageId);
      _messages = <ConversationMessage>[
        ..._messages,
        ConversationMessage(
          id: 'pending-${outgoing.clientMessageId}',
          conversationId: current.id,
          senderEntityId: '',
          bodyEncrypted: outgoing.bodyEncrypted,
          bodyPreview: outgoing.bodyPreview,
          clientMessageId: outgoing.clientMessageId,
          createdAt: DateTime.now().toUtc(),
          decryptedBody: outgoing.plainText,
        ),
      ];
      _error = null;
      _logger?.info('Message queued offline', <String, Object?>{
        'conversationId': current.id,
      });
    } on ApiException {
      rethrow;
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _replaceOptimistic(String clientMessageId, ConversationMessage sent) {
    bool replaced = false;
    _messages = _messages.map((ConversationMessage m) {
      if (m.clientMessageId == clientMessageId && !replaced) {
        replaced = true;
        // Preserve the optimistic plaintext echo when the replay path
        // could not re-derive it (prepared payload carries no plaintext).
        if (sent.decryptedBody == null || sent.decryptedBody!.isEmpty) {
          return ConversationMessage(
            id: sent.id,
            conversationId: sent.conversationId,
            senderEntityId: sent.senderEntityId,
            bodyEncrypted: sent.bodyEncrypted,
            bodyPreview: sent.bodyPreview,
            clientMessageId: sent.clientMessageId,
            createdAt: sent.createdAt,
            decryptedBody: m.decryptedBody,
          );
        }
        return sent;
      }
      return m;
    }).toList(growable: false);
    if (!replaced) {
      _messages = <ConversationMessage>[..._messages, sent];
    }
  }

  Future<void> _hydrateFromCache(Conversation conversation) async {
    final MessagingLocalDataSource? cache = _cache;
    if (cache == null) return;
    try {
      final ThreadWindow? window = await cache.readThreadWindow(
        conversation.id,
      );
      if (window == null || window.messages.isEmpty) return;
      final List<ConversationMessage> cached = <ConversationMessage>[];
      for (final Map<String, dynamic> json in window.messages) {
        try {
          final MessageDto dto = MessageDto.fromJson(json);
          cached.add(
            await _service.decryptMessage(conversation.contractId, 
              MessagingMapper.messageToEntity(dto)),
          );
        } on Object {
          // Skip undecodable rows; the server page is authoritative.
        }
      }
      if (cached.isEmpty) return;
      // Cache stores newest-first (server order); display is oldest-first.
      _messages = cached.reversed.toList(growable: false);
      _messagesHasMore = window.hasMore;
      _messagesCursor = window.nextCursor;
      if (!_disposed) notifyListeners();
    } on Object {
      // Cache warm-up is best-effort; the server load follows.
    }
  }

  Future<void> _persistWindow(Conversation conversation) async {
    final MessagingLocalDataSource? cache = _cache;
    if (cache == null) return;
    try {
      // Persist newest-first (server order) transport JSON only —
      // verified plaintext is never written to disk.
      final List<Map<String, dynamic>> rows = _messages.reversed
          .map(
            (ConversationMessage m) => <String, dynamic>{
              'id': m.id.startsWith('pending-') ? '' : m.id,
              'conversation_id': m.conversationId,
              'sender_entity_id': m.senderEntityId,
              'body_encrypted': m.bodyEncrypted,
              'body_preview': m.bodyPreview,
              'client_message_id': m.clientMessageId,
              'created_at': m.createdAt.toIso8601String(),
            },
          )
          .where((Map<String, dynamic> row) => (row['id'] as String).isNotEmpty)
          .toList(growable: false);
      await cache.writeThreadWindow(
        conversationId: conversation.id,
        messages: rows,
        hasMore: _messagesHasMore,
        nextCursor: _messagesCursor,
      );
    } on Object {
      // Cache persistence is best-effort.
    }
  }

  Future<void> _subscribeRealtime(Conversation conversation) async {
    final MessagingRealtimeDataSource? realtime = _realtime;
    if (realtime == null) return;
    final String id = conversation.id;
    if (_subscribedConversationId == id && _realtimeSub != null) return;
    await _unsubscribeRealtime();
    try {
      _realtimeSub = realtime.messagesFor(id).listen(
        _onRealtimeMessage,
        onError: (Object _) {
          // Realtime errors never fail the open thread; poll-on-resume
          // remains the fallback.
        },
      );
      _subscribedConversationId = id;
    } on Object {
      _realtimeSub = null;
      _subscribedConversationId = null;
    }
  }

  Future<void> _unsubscribeRealtime() async {
    final StreamSubscription<MessageDto>? sub = _realtimeSub;
    _realtimeSub = null;
    final String? id = _subscribedConversationId;
    _subscribedConversationId = null;
    try {
      await sub?.cancel();
    } on Object {
      // Best-effort teardown.
    }
    if (id != null) {
      try {
        await _realtime?.unsubscribe(id);
      } on Object {
        // Best-effort teardown.
      }
    }
  }

  Future<void> _onRealtimeMessage(MessageDto dto) async {
    final Conversation? current = _selected;
    if (current == null || dto.conversationId != current.id || _disposed) {
      return;
    }
    final bool known = _messages.any(
      (ConversationMessage m) =>
          m.id == dto.id || m.clientMessageId == dto.clientMessageId,
    );
    if (known) return;
    final ConversationMessage decrypted = await _service.decryptMessage(
      current.contractId,
      MessagingMapper.messageToEntity(dto),
    );
    _messages = <ConversationMessage>[..._messages, decrypted];
    _pendingClientIds.remove(dto.clientMessageId);
    await _persistWindow(current);
    if (!_disposed) notifyListeners();
    _maybeNotify(
      current,
      preview: decrypted.bodyPreview ?? decrypted.decryptedBody,
    );
  }

  void _maybeNotify(Conversation conversation, {String? preview}) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    final String trimmed = (preview ?? '').trim();
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: conversation.id.hashCode & 0x7fffffff,
          title: 'New message',
          body: trimmed.isEmpty
              ? 'You have a new message in this conversation.'
              : trimmed,
          channelId: MessagingNotificationChannel.system,
          priority: NotificationPriority.normal,
          timestamp: _clock(),
          actionRoute: '/dashboard/messages/${conversation.id}',
        ),
      ),
    );
  }

  /// Pauses background refreshes (lifecycle gate).
  void pausePolling() {
    _paused = true;
  }

  /// Resumes background refreshes and flushes offline sends (lifecycle gate).
  void resumePolling() {
    _paused = false;
    unawaited(replayQueued());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause refreshes while backgrounded; no wasted RPCs (EP-04-04).
    // On foreground, flush the offline outbox best-effort (EP-03-13).
    final bool resumed = state == AppLifecycleState.resumed;
    _paused = !resumed;
    if (resumed) {
      unawaited(replayQueued());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_unsubscribeRealtime());
    try {
      WidgetsBinding.instance.removeObserver(this);
    } on Object {
      // Observer was never attached (no live binding).
    }
    super.dispose();
  }
}
