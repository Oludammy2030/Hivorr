import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/database/boxes/app_boxes.dart';

/// Immutable local storage configuration for the Hivorr client.
///
/// Carries only non-secret, deployment-sourced storage metadata: the selected
/// driver, the at-rest encryption toggle, and the base directory name. All
/// values are sourced exclusively from [EnvironmentConfig] (EP-01-03); nothing
/// here is a hardcoded secret or path.
///
/// The actual filesystem path is resolved at initialization time via
/// `path_provider` (using [baseDirectoryName]) so the configuration remains
/// platform-agnostic and never reads `String.fromEnvironment` directly.
class DatabaseConfig {
  const DatabaseConfig({
    required this.driverType,
    required this.encryptAtRest,
    required this.baseDirectoryName,
    required this.boxes,
  });

  /// The selected storage driver.
  final StorageDriverType driverType;

  /// Whether persisted local data is encrypted at rest.
  ///
  /// When `true`, [LocalStore] wraps values through an injected
  /// [StorageCipher] (the EP-01-10 `AesCipher` adapter). Default is `false`;
  /// the persistent store holds only non-secret operational data, so the
  /// default posture is acceptable (see plan §12 R1).
  final bool encryptAtRest;

  /// Base directory name (relative to the app documents directory).
  final String baseDirectoryName;

  /// Pre-registered box (collection) names.
  final List<String> boxes;

  /// Builds [DatabaseConfig] from an [EnvironmentValueSource].
  ///
  /// Missing values fall back to safe defaults so the loader stays fail-closed
  /// on the core Supabase/schema contract while local storage remains opt-in
  /// per environment.
  static DatabaseConfig fromSource(EnvironmentValueSource source) {
    final String driverName =
        source.read(AppConstants.envStorageDriver) ?? 'hive';
    final bool encrypt = _parseBool(
      source,
      AppConstants.envStorageEncryptAtRest,
    );
    final String baseDir =
        source.read(AppConstants.envStorageBaseDir) ??
        AppConstants.defaultStorageBaseDir;

    return DatabaseConfig(
      driverType: _parseDriver(driverName),
      encryptAtRest: encrypt,
      baseDirectoryName: baseDir,
      boxes: AppBoxes.all,
    );
  }

  /// Resolves a driver name to the typed enum, defaulting to Hive.
  static StorageDriverType _parseDriver(String name) {
    return switch (name.toLowerCase()) {
      'hive' => StorageDriverType.hive,
      'sqlite' => StorageDriverType.sqlite,
      'isar' => StorageDriverType.isar,
      _ => StorageDriverType.hive,
    };
  }

  /// Strict boolean parse; absent → `false`, malformed → throws.
  static bool _parseBool(EnvironmentValueSource source, String key) {
    final String? raw = source.read(key);
    if (raw == null) {
      return false;
    }
    return switch (raw) {
      'true' => true,
      'false' => false,
      _ => throw EnvironmentConfigException(
        variableName: key,
        reason: 'Malformed storage flag. Accepted values: true, false.',
      ),
    };
  }

  @override
  String toString() {
    return 'DatabaseConfig('
        'driverType: $driverType, '
        'encryptAtRest: $encryptAtRest, '
        'baseDirectoryName: $baseDirectoryName, '
        'boxes: ${boxes.length})';
  }
}

/// Supported local storage driver implementations.
enum StorageDriverType {
  /// Hive — pure-Dart, small footprint, Web/IndexedDB support (EP-01-11 D1).
  hive,

  /// SQLite/drift — relational, mirrors server schema (alternative).
  sqlite,

  /// Isar — excluded for Web; retained only for completeness.
  isar,
}
