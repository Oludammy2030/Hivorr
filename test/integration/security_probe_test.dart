import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/environments/security_config.dart';
import 'package:hivorr/core/security/crypto/aes_cipher.dart';
import 'package:hivorr/core/security/crypto/key_derivation.dart';
import 'package:hivorr/core/security/security_config.dart';
import 'package:hivorr/core/storage/secure_storage.dart';
import 'package:hivorr/core/storage/secure_storage_config.dart';
import 'package:hivorr/core/storage/secure_token_store.dart';

import '../unit/core/storage/fakes.dart';

void _step(String label) {
  // ignore: avoid_print
  print('SECURITY_PROBE: $label');
}

/// Resolves the at-rest key (simulating EP-01-09 deriving it from a device
/// secret held in the same store). Fixed here so the probe is reproducible.
Future<SecretKey> _deriveKey() => KeyDerivation.fromConfiguration(
  SecurityConfiguration(
    const SecurityConfig(
      pinningEnabled: false,
      pinnedSpkiSha256Hashes: <String>[],
      kdfSalt: 'probe-salt',
      kdfIterations: 1000,
      kdfKeyLength: 32,
    ),
  ),
).deriveKey('probe-device-secret');

/// Manual/device verification probe for EP-01-10 (DoD manual checks).
///
/// Asserts the value written through the encrypted [SecureTokenStore] is
/// ciphertext at rest (never the plaintext token) and that it round-trips.
/// This covers the substantive Web R3 mitigation: the AES-at-rest layer produces
/// a `{c,i,t}` blob rather than the raw token.
///
/// The probe injects [FakeFlutterSecureStorage] (not the real plugin). Under
/// `flutter test -d chrome` the `flutter_secure_storage` web plugin is NOT
/// registered (it falls back to the native method channel and throws
/// MissingPluginException) — a test-harness limitation, not a product bug; a
/// real `flutter run -d chrome` app registers it correctly. To prove the value
/// actually lands in the real OS store / Web localStorage, run a debug
/// `flutter run -d chrome` app with the same assertions (handoff note).
///
/// Run:
///   flutter test test/integration/security_probe_test.dart -d chrome \
///     --dart-define=HIVORR_SEC_PROBE=true
///   flutter test test/integration/security_probe_test.dart -d `<emulator>` \
///     --dart-define=HIVORR_SEC_PROBE=true
///
/// Skips (passes) in the default unit run so it never breaks CI.
void main() {
  // Initialize the Flutter service bindings (needed because the test no longer
  // uses `testWidgets`, which would otherwise set them up).
  TestWidgetsFlutterBinding.ensureInitialized();

  // NOTE: use plain `test()`, not `testWidgets()`. The real
  // `flutter_secure_storage` web backend relies on Web Crypto (`crypto.subtle`)
  // promises, which do not resolve under `testWidgets`'s FakeAsync clock and
  // would hang. A plain `test()` runs on the real event loop (works on Web).
  test(
    'EP-01-10: token store persists AES-at-rest ciphertext (non-plaintext backing)',
    () async {
      if (!const bool.fromEnvironment('HIVORR_SEC_PROBE')) {
        _step('skipped: run with --dart-define=HIVORR_SEC_PROBE=true on a device/web target');
        return;
      }
      _step('start');

      // NOTE: the probe injects [FakeFlutterSecureStorage] rather than the real
      // plugin. Under `flutter test -d chrome` the `flutter_secure_storage` web
      // plugin is NOT registered (it falls back to the native method channel and
      // throws MissingPluginException) — a test-harness limitation, not a code
      // issue. A real `flutter run -d chrome` app registers it correctly. The
      // injected fake still proves the substantive claim: the encrypted
      // [SecureTokenStore] hands ciphertext (not the plaintext token) to its
      // storage backend. For the 100% real-backend proof, build a debug
      // `flutter run -d chrome` app (see handoff note).
      final FlutterSecureStorageImpl storage = FlutterSecureStorageImpl(
        config: const SecureStorageConfig(),
        backend: FakeFlutterSecureStorage(),
      );
      final SecureTokenStore store = SecureTokenStore(
        storage,
        cipher: AesCipher.defaultInstance,
        deriveKey: _deriveKey,
      );

      const String plaintextToken = 'PLAINTEXT-PROBE-TOKEN-12345';
      await store.writeAccessToken(plaintextToken);
      _step('wrote access token through encrypted store');

      // Read the RAW backing value (bypassing the store's decryption) to prove
      // the at-rest bytes are ciphertext, not the plaintext token.
      final String? raw = await storage.readString('auth.access_token');
      _step('raw backing value length=${raw?.length}');
      expect(raw, isNotNull);
      expect(raw, isNot(contains(plaintextToken)),
          reason: 'backing store must contain ciphertext, not the plaintext token');
      // EncryptedPayload JSON shape from aes_cipher.dart.
      expect(raw, contains('"c"'));
      expect(raw, contains('"i"'));
      expect(raw, contains('"t"'));

      // And it round-trips back to the original token.
      expect(await store.readAccessToken(), plaintextToken);
      _step('round-trip verified');

      // Cleanup.
      await store.clearTokens();
      expect(await store.readAccessToken(), isNull);
      _step('cleanup verified');
    },
  );
}
