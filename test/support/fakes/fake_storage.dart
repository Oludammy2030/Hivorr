import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hivorr/core/database/storage_engine.dart';
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

/// In-memory [StorageEngine] for bootstrap and locale-provider tests.
///
/// Stores values as nested maps keyed by `box` then `key`, matching the
/// [StorageEngine] contract without touching the filesystem.
class FakeStorageEngine implements StorageEngine {
  final Map<String, Map<String, dynamic>> _data =
      <String, Map<String, dynamic>>{};

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) async {
    _data.putIfAbsent(box, () => <String, dynamic>{});
    _data[box]![key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) async {
    final Map<String, dynamic>? boxData = _data[box];
    if (boxData == null) {
      return null;
    }
    final dynamic value = boxData[key];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  @override
  Future<void> delete(String box, String key) async {
    _data[box]?.remove(key);
  }

  @override
  Future<void> clearBox(String box) async {
    _data.remove(box);
  }

  @override
  Future<List<String>> keys(String box) async =>
      (_data[box]?.keys ?? <String>[]).toList();

  @override
  Future<void> writeBatch(String box, List<WriteOp> ops) async {
    for (final WriteOp op in ops) {
      if (op is PutOp) {
        await put(box, op.key, op.value);
      } else if (op is DeleteOp) {
        await delete(box, op.key);
      }
    }
  }
}
