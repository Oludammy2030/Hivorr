import 'dart:io';

import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/core/database/adapters/hive_storage_engine.dart';
import 'package:hivorr/core/database/database_config.dart';
import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/core/database/storage_cipher.dart';
import 'package:hivorr/core/database/storage_engine.dart';
import 'package:hivorr/core/database/storage_exception.dart';
import 'package:path_provider/path_provider.dart';

export 'package:hivorr/core/database/adapters/hive_storage_engine.dart';
export 'package:hivorr/core/database/boxes/app_boxes.dart';
export 'package:hivorr/core/database/database_config.dart';
export 'package:hivorr/core/database/local_store.dart';
export 'package:hivorr/core/database/storage_cipher.dart';
export 'package:hivorr/core/database/storage_engine.dart';
export 'package:hivorr/core/database/storage_exception.dart';

/// Process-wide handle to the initialized local storage subsystem.
///
/// Holds the singleton [StorageEngine] plus a convenience [LocalStore] wrapper,
/// ready for EP-01-08 (entity cache) and EP-01-12 (sync queue) to consume
/// through the abstraction only (plan §5.5).
class Database {
  Database._(this.engine, this.config);

  /// The active storage engine.
  final StorageEngine engine;

  /// The storage configuration used at initialization.
  final DatabaseConfig config;

  static Database? _instance;

  /// The singleton instance, or throws if [initialize] was not called.
  static Database get instance {
    final Database? i = _instance;
    if (i == null) {
      throw const StorageException(
        'Database not initialized. Call initializeDatabase().',
      );
    }
    return i;
  }

  /// Whether the subsystem has been initialized.
  static bool get isInitialized => _instance != null;

  /// Initializes the storage engine for [config].
  ///
  /// Idempotent: returns the existing instance if already initialized.
  static Future<Database> initialize(EnvironmentConfig config) async {
    final Database? existing = _instance;
    if (existing != null) {
      return existing;
    }

    final Directory documents = await getApplicationDocumentsDirectory();
    final String basePath =
        '${documents.path}/${config.databaseConfig.baseDirectoryName}';

    final HiveStorageEngine hive = HiveStorageEngine();
    await hive.initialize(basePath: basePath);
    final StorageEngine engine = hive;

    _instance = Database._(engine, config.databaseConfig);
    return _instance!;
  }

  /// Convenience accessor for the typed [LocalStore].
  ///
  /// Pass a [cipher] only when [DatabaseConfig.encryptAtRest] is enabled; the
  /// default constructor uses no cipher.
  LocalStore localStore({StorageCipher? cipher}) =>
      LocalStore(engine, cipher: cipher);

  /// Resets the singleton (test helper / re-init boundary).
  static void dispose() => _instance = null;
}

/// Bootstraps the local storage subsystem from the validated [config].
///
/// Exported for EP-01-15 to call during app startup. Does not modify
/// `main.dart` or bootstrap; it only initializes the engine and returns it.
Future<StorageEngine> initializeDatabase(EnvironmentConfig config) async {
  final Database db = await Database.initialize(config);
  return db.engine;
}
