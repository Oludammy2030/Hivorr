import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_storage.dart';

/// [LocalStorage] adapter that persists the Supabase session through
/// [SecureStorage] instead of the default SharedPreferences/Hive backend.
///
/// Defined here for EP-01-09 to adopt at auth bootstrap (wiring belongs to
/// EP-01-09 — this task does not call [Supabase.initialize]). The
/// implementation owns its session key and stores the raw session JSON
/// (EP-01-10 §5.6). No business logic is introduced.
class SupabaseSecureLocalStorage implements LocalStorage {
  const SupabaseSecureLocalStorage(this._storage);

  final SecureStorage _storage;

  static const String _sessionKey = 'supabase.auth.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.readString(_sessionKey)) != null;

  @override
  Future<String?> accessToken() => _storage.readString(_sessionKey);

  @override
  Future<void> removePersistedSession() => _storage.delete(_sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.writeString(_sessionKey, persistSessionString);
}
