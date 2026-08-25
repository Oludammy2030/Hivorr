import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_config.dart';

/// Platform-agnostic secure storage contract.
///
/// Typed accessors (string/bool/int/json) with namespacing prevent key
/// collisions and serialization bugs across features. Implementations must
/// back this with an OS-protected store (EP-01-10 §5.6).
abstract class SecureStorage {
  const SecureStorage();

  /// Reads a raw string value, or `null` if absent.
  Future<String?> readString(String key);

  /// Writes a raw string value.
  Future<void> writeString(String key, String value);

  /// Reads a JSON map, or `null` if absent.
  Future<Map<String, dynamic>?> readJson(String key);

  /// Writes a JSON-serializable map.
  Future<void> writeJson(String key, Map<String, dynamic> value);

  /// Reads a boolean, or `null` if absent.
  Future<bool?> readBool(String key);

  /// Writes a boolean (stored as `true`/`false`).
  Future<void> writeBool(String key, bool value);

  /// Reads an integer, or `null` if absent.
  Future<int?> readInt(String key);

  /// Writes an integer (stored as its decimal string).
  Future<void> writeInt(String key, int value);

  /// Deletes a single key.
  Future<void> delete(String key);

  /// Deletes all entries written through this store.
  Future<void> clear();
}

/// [SecureStorage] backed by `flutter_secure_storage` (Keychain / encrypted
/// shared preferences / Web localStorage), namespaced per [SecureStorageConfig].
class FlutterSecureStorageImpl implements SecureStorage {
  FlutterSecureStorageImpl({
    required this.config,
    FlutterSecureStorage? backend,
  }) : _backend =
           backend ??
           FlutterSecureStorage(
             webOptions: config.webOptions,
             aOptions: config.androidOptions,
             iOptions: config.iosOptions,
           );

  final SecureStorageConfig config;
  final FlutterSecureStorage _backend;

  String _key(String key) => '${config.namespace}.$key';

  @override
  Future<String?> readString(String key) => _backend.read(key: _key(key));

  @override
  Future<void> writeString(String key, String value) =>
      _backend.write(key: _key(key), value: value);

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final String? raw = await readString(key);
    if (raw == null) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      writeString(key, jsonEncode(value));

  @override
  Future<bool?> readBool(String key) async {
    final String? raw = await readString(key);
    if (raw == null) {
      return null;
    }
    return raw == 'true';
  }

  @override
  Future<void> writeBool(String key, bool value) =>
      writeString(key, value ? 'true' : 'false');

  @override
  Future<int?> readInt(String key) async {
    final String? raw = await readString(key);
    if (raw == null) {
      return null;
    }
    return int.tryParse(raw);
  }

  @override
  Future<void> writeInt(String key, int value) =>
      writeString(key, value.toString());

  @override
  Future<void> delete(String key) => _backend.delete(key: _key(key));

  @override
  Future<void> clear() => _backend.deleteAll();
}
