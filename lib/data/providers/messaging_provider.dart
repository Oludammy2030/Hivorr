// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/conversation.dart';
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
/// (EP-04-04).
///
/// Depends only on the [MessagingService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized conversation list, the
/// selection (conversation + chronological messages), a
/// [WidgetsBindingObserver] lifecycle gate (no background refreshes), and a
/// local "message received" hook for threads refreshed while open. Ciphertext
/// is never exposed — messages carry verified plaintext or render as
/// undecryptable placeholders downstream.
class MessagingProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ///
  /// [notificationProvider] enables the messaging notification hook; [logger]
  /// enables PII-safe structured logging; [clock] is injectable for
  /// deterministic tests.
  MessagingProvider({
    required MessagingService service,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
  }) : _service = service,
       _logger = logger,
       _notificationProvider = notificationProvider,
       _clock = clock ?? DateTime.now {
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
      final DecryptedMessagePage page = await _service.listDecryptedMessages(
        conversationId: conversationId,
        contractId: conversation.contractId,
      );
      _messages = page.messages.reversed.toList(growable: false);
      _messagesHasMore = page.hasMore;
      _messagesCursor = page.nextCursor;
      _loadState = MessagingLoadState.loaded;
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
  Future<void> refresh() async {
    final Conversation? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      final int before = _messages.length;
      final DecryptedMessagePage page = await _service.listDecryptedMessages(
        conversationId: current.id,
        contractId: current.contractId,
      );
      _messages = page.messages.reversed.toList(growable: false);
      _messagesHasMore = page.hasMore;
      _messagesCursor = page.nextCursor;
      _loadState = MessagingLoadState.loaded;
      if (_messages.length > before) {
        _maybeNotify(current);
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
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Encrypts and sends [text] on the open thread, appending the echo.
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

  void _maybeNotify(Conversation conversation) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: conversation.id.hashCode & 0x7fffffff,
          title: 'New message',
          body: 'You have a new message in this conversation.',
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

  /// Resumes background refreshes (lifecycle gate).
  void resumePolling() {
    _paused = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause refreshes while backgrounded; no wasted RPCs (EP-04-04).
    _paused = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } on Object {
      // Observer was never attached (no live binding).
    }
    super.dispose();
  }
}
