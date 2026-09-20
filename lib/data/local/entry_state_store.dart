// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/database/boxes/app_boxes.dart';
import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/core/database/storage_exception.dart';

/// Named box + keys for the device-local entry-state rows (entry architecture).
///
/// Mirrors the [OnboardingProgressBox] convention. Non-secret operational
/// state only — never used for authorization (auth is always Supabase-driven).
abstract final class EntryStateBox {
  const EntryStateBox._();

  /// The Hive box holding entry-state rows.
  static const String name = AppBoxes.entry;

  /// Key for the "first launch" flag persisted after the mobile intro is seen.
  static const String introSeenKey = 'intro_seen';

  /// Key for the deep-link destination preserved across registration.
  static const String pendingRedirectKey = 'pending_redirect';
}

/// Persistence seam for device-local entry state (first-launch flag + the
/// deep-link destination preserved across registration).
///
/// Both rows are best-effort: a storage failure degrades gracefully (defaults),
/// because neither value is authoritative — authentication state stays the
/// single source of truth (AGENT.md Rule 4).
abstract class EntryStateStore {
  /// Reads the persisted "intro seen" flag, or `null` when absent.
  Future<bool?> readIntroSeen();

  /// Persists the "intro seen" flag.
  Future<void> writeIntroSeen(bool value);

  /// Reads the persisted pending redirect, or `null` when absent.
  Future<String?> readPendingRedirect();

  /// Persists the pending redirect; `null` clears it.
  Future<void> writePendingRedirect(String? value);
}

/// In-memory [EntryStateStore] for tests and unsupported platforms.
class InMemoryEntryStateStore implements EntryStateStore {
  InMemoryEntryStateStore({bool? introSeen, String? pendingRedirect})
    : _introSeen = introSeen,
      _pendingRedirect = pendingRedirect;

  bool? _introSeen;
  String? _pendingRedirect;

  @override
  Future<bool?> readIntroSeen() async => _introSeen;

  @override
  Future<void> writeIntroSeen(bool value) async {
    _introSeen = value;
  }

  @override
  Future<String?> readPendingRedirect() async => _pendingRedirect;

  @override
  Future<void> writePendingRedirect(String? value) async {
    _pendingRedirect = value;
  }
}

/// Hive-backed [EntryStateStore] over the EP-01-11 [LocalStore].
///
/// Persists under box [EntryStateBox.name] at the fixed keys
/// [EntryStateBox.introSeenKey] / [EntryStateBox.pendingRedirectKey].
/// Degrades gracefully (defaults to absent) when storage is unavailable so the
/// entry flow is never blocked by local I/O.
class HiveEntryStateStore implements EntryStateStore {
  /// Creates the store over [store].
  HiveEntryStateStore({required LocalStore store}) : _store = store;

  final LocalStore _store;

  @override
  Future<bool?> readIntroSeen() async {
    try {
      return await _store.read(
        EntryStateBox.name,
        EntryStateBox.introSeenKey,
        _boolFromJson,
      );
    } on StorageException {
      return null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeIntroSeen(bool value) async {
    try {
      await _store.write(
        EntryStateBox.name,
        EntryStateBox.introSeenKey,
        value,
        _boolToJson,
      );
    } on StorageException {
      return;
    } on Object {
      return;
    }
  }

  @override
  Future<String?> readPendingRedirect() async {
    try {
      return await _store.read<String>(
        EntryStateBox.name,
        EntryStateBox.pendingRedirectKey,
        (Map<String, dynamic> json) => (json['v'] as String?) ?? '',
      );
    } on StorageException {
      return null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writePendingRedirect(String? value) async {
    try {
      if (value == null) {
        await _store.remove(
          EntryStateBox.name,
          EntryStateBox.pendingRedirectKey,
        );
        return;
      }
      await _store.write(
        EntryStateBox.name,
        EntryStateBox.pendingRedirectKey,
        value,
        (String redirect) => <String, dynamic>{'v': redirect},
      );
    } on StorageException {
      return;
    } on Object {
      return;
    }
  }
}

Map<String, dynamic> _boolToJson(bool value) => <String, dynamic>{'v': value};
bool _boolFromJson(Map<String, dynamic> json) => json['v'] as bool? ?? false;
