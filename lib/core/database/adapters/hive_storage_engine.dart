import 'package:hive/hive.dart';

import 'package:hivorr/core/database/storage_engine.dart';
import 'package:hivorr/core/database/storage_exception.dart';

/// Hive-backed implementation of [StorageEngine] (EP-01-11 D1).
///
/// Hive is selected for its pure-Dart implementation, small footprint, and
/// Web/IndexedDB support, satisfying the 15–20 MB installer and cross-platform
/// readiness constraints. All boxes are opened lazily and cached per engine
/// instance.
///
/// Values are stored as Hive-native `Map` (JSON-compatible). This adapter
/// never interprets business meaning — it only persists and retrieves bytes.
class HiveStorageEngine implements StorageEngine {
  HiveStorageEngine();

  final Map<String, Box<dynamic>> _openBoxCache = <String, Box<dynamic>>{};
  bool _initialized = false;

  // Hive is process-global: re-initializing with a different path throws
  // "already initialized". Guarded so repeated [initialize] calls (e.g. across
  // bootstrap/test steps) are idempotent.
  static bool _hiveInitialized = false;

  /// Initializes Hive against [basePath] (resolved by the initializer via
  /// `path_provider`). Safe to call once before any read/write.
  Future<void> initialize({required String basePath}) async {
    if (!_hiveInitialized) {
      Hive.init(basePath);
      _hiveInitialized = true;
    }
    _initialized = true;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw const StorageException(
        'Storage engine not initialized. Call initialize().',
      );
    }
  }

  Future<Box<dynamic>> _openBox(String name) async {
    _ensureInitialized();
    final Box<dynamic>? cached = _openBoxCache[name];
    if (cached != null && cached.isOpen) {
      return cached;
    }
    final Box<dynamic> box = await Hive.openBox<dynamic>(name);
    _openBoxCache[name] = box;
    return box;
  }

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) async {
    try {
      final Box<dynamic> b = await _openBox(box);
      await b.put(key, value);
    } catch (e) {
      throw StorageException('put failed for box "$box" key "$key": $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) async {
    try {
      final Box<dynamic> b = await _openBox(box);
      final dynamic raw = b.get(key);
      if (raw == null) {
        return null;
      }
      return Map<String, dynamic>.from(raw as Map);
    } catch (e) {
      throw StorageException('get failed for box "$box" key "$key": $e');
    }
  }

  @override
  Future<void> delete(String box, String key) async {
    try {
      final Box<dynamic> b = await _openBox(box);
      await b.delete(key);
    } catch (e) {
      throw StorageException('delete failed for box "$box" key "$key": $e');
    }
  }

  @override
  Future<void> clearBox(String box) async {
    try {
      final Box<dynamic> b = await _openBox(box);
      await b.clear();
    } catch (e) {
      throw StorageException('clearBox failed for box "$box": $e');
    }
  }

  @override
  Future<List<String>> keys(String box) async {
    try {
      final Box<dynamic> b = await _openBox(box);
      return b.keys.map((dynamic k) => k.toString()).toList();
    } catch (e) {
      throw StorageException('keys failed for box "$box": $e');
    }
  }

  @override
  Future<void> writeBatch(String box, List<WriteOp> ops) async {
    if (ops.isEmpty) {
      return;
    }
    final Box<dynamic> b = await _openBox(box);

    // Snapshot affected keys so a mid-batch failure can be rolled back.
    final Map<String, dynamic> snapshot = <String, dynamic>{};
    for (final WriteOp op in ops) {
      snapshot[op.key] = b.get(op.key);
    }

    try {
      for (final WriteOp op in ops) {
        if (op is PutOp) {
          await b.put(op.key, op.value);
        } else if (op is DeleteOp) {
          await b.delete(op.key);
        }
      }
    } catch (e) {
      // Roll back to the pre-batch snapshot for every affected key.
      for (final MapEntry<String, dynamic> entry in snapshot.entries) {
        if (entry.value == null) {
          await b.delete(entry.key);
        } else {
          await b.put(entry.key, entry.value);
        }
      }
      throw StorageException('writeBatch failed and was rolled back: $e');
    }
  }
}
