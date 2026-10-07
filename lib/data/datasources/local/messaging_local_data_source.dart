// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/database/boxes/app_boxes.dart';
import 'package:hivorr/core/database/local_store.dart';

/// Hive-backed thread window + composer draft cache (EP-03-13).
///
/// Cache-only and warm-then-refresh: the server (`message_list` keyset)
/// remains authoritative. Only transport DTO JSON is persisted
/// (`body_encrypted` opaque + redacted `body_preview` + ids) — verified
/// plaintext (`decryptedBody`) is never written here. Composer drafts are
/// device-local input text keyed by conversation; evict via [clearAll] on
/// logout. Reusable shape for EP-04 order chat threads.
class MessagingLocalDataSource {
  MessagingLocalDataSource({required LocalStore store}) : _store = store;

  final LocalStore _store;

  static String _windowKey(String conversationId) => 'window:$conversationId';
  static String _draftKey(String conversationId) => 'draft:$conversationId';

  /// Reads the cached window for [conversationId], or `null` when absent.
  Future<ThreadWindow?> readThreadWindow(String conversationId) =>
      _store.read<ThreadWindow>(
        AppBoxes.messages,
        _windowKey(conversationId),
        ThreadWindow.fromJson,
      );

  /// Persists the latest loaded window for [conversationId].
  Future<void> writeThreadWindow({
    required String conversationId,
    required List<Map<String, dynamic>> messages,
    required bool hasMore,
    String? nextCursor,
  }) => _store.write<ThreadWindow>(
    AppBoxes.messages,
    _windowKey(conversationId),
    ThreadWindow(
      messages: messages,
      hasMore: hasMore,
      nextCursor: nextCursor,
      savedAt: DateTime.now().toUtc(),
    ),
    (ThreadWindow window) => window.toJson(),
  );

  /// Reads the unsent composer draft for [conversationId], if any.
  Future<String?> readDraft(String conversationId) => _store.read<String>(
    AppBoxes.messages,
    _draftKey(conversationId),
    (Map<String, dynamic> json) => (json['text'] as String?) ?? '',
  );

  /// Persists the composer draft; blank text clears the entry.
  Future<void> writeDraft(String conversationId, String text) {
    if (text.trim().isEmpty) {
      return _store.remove(AppBoxes.messages, _draftKey(conversationId));
    }
    return _store.write<String>(
      AppBoxes.messages,
      _draftKey(conversationId),
      text,
      (String value) => <String, dynamic>{'text': value},
    );
  }

  /// Removes the draft for [conversationId] (e.g. after successful send).
  Future<void> clearDraft(String conversationId) =>
      _store.remove(AppBoxes.messages, _draftKey(conversationId));

  /// Evicts every cached thread window and draft (call on logout).
  Future<void> clearAll() => _store.clearBox(AppBoxes.messages);
}

/// A cached newest-first message window for one conversation.
class ThreadWindow {
  const ThreadWindow({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
    required this.savedAt,
  });

  /// Transport DTO JSON maps (never decrypted plaintext).
  final List<Map<String, dynamic>> messages;

  final bool hasMore;
  final String? nextCursor;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'messages': messages,
    'has_more': hasMore,
    'next_cursor': nextCursor,
    'saved_at': savedAt.toIso8601String(),
  };

  factory ThreadWindow.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['messages'];
    final List<Map<String, dynamic>> messages = raw is List
        ? raw
              .whereType<Map<dynamic, dynamic>>()
              .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    DateTime savedAt;
    try {
      savedAt =
          DateTime.tryParse(json['saved_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    } on Object {
      savedAt = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return ThreadWindow(
      messages: messages,
      hasMore: (json['has_more'] as bool?) ?? false,
      nextCursor: json['next_cursor'] as String?,
      savedAt: savedAt,
    );
  }
}
