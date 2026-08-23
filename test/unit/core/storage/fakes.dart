import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hivorr/core/storage/secure_storage.dart';

/// In-memory [SecureStorage] for fast, dependency-free unit tests.
class InMemorySecureStorage implements SecureStorage {
  InMemorySecureStorage([Map<String, String>? seed]) : _data = seed ?? {};

  final Map<String, String> _data;

  /// Test-only view of the raw stored entries.
  Map<String, String> get entries => Map<String, String>.from(_data);

  @override
  Future<String?> readString(String key) async => _data[key];

  @override
  Future<void> writeString(String key, String value) async => _data[key] = value;

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final String? raw = _data[key];
    if (raw == null) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async =>
      _data[key] = jsonEncode(value);

  @override
  Future<bool?> readBool(String key) async {
    final String? raw = _data[key];
    if (raw == null) {
      return null;
    }
    return raw == 'true';
  }

  @override
  Future<void> writeBool(String key, bool value) async =>
      _data[key] = value ? 'true' : 'false';

  @override
  Future<int?> readInt(String key) async {
    final String? raw = _data[key];
    if (raw == null) {
      return null;
    }
    return int.tryParse(raw);
  }

  @override
  Future<void> writeInt(String key, int value) async =>
      _data[key] = value.toString();

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();
}

/// [FlutterSecureStorage] fake that stores in a [Map], suitable for asserting
/// the [FlutterSecureStorageImpl] namespacing behavior.
class FakeFlutterSecureStorage extends FlutterSecureStorage {
  FakeFlutterSecureStorage([Map<String, String>? store])
      : store = store ?? <String, String>{};

  final Map<String, String> store;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      store.remove(key);

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      store.clear();
}
