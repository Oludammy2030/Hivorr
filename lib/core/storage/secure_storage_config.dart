import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuration for [FlutterSecureStorageImpl].
///
/// Carries the storage namespace and platform-specific options. Sensible,
/// non-secret defaults are provided; environments may supply stronger
/// platform options (EP-01-10 §5.6, §6).
class SecureStorageConfig {
  const SecureStorageConfig({
    this.namespace = 'hivorr',
    this.androidOptions = const AndroidOptions(),
    this.iosOptions = const IOSOptions(),
    this.webOptions = const WebOptions(),
  });

  /// Key prefix isolating Hivorr's secure entries from other apps/data.
  final String namespace;

  /// Android keystore / encrypted-shared-preferences options.
  final AndroidOptions androidOptions;

  /// iOS Keychain options.
  final IOSOptions iosOptions;

  /// Web options (note: Web localStorage is not OS-encrypted; AES-at-rest in
  /// [AesCipher] compensates — EP-01-10 §12 R3).
  final WebOptions webOptions;

  /// Default, non-secret configuration.
  static const SecureStorageConfig defaultConfig = SecureStorageConfig();
}
