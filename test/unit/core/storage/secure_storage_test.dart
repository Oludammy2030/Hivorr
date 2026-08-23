import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/environments/security_config.dart';
import 'package:hivorr/core/security/crypto/aes_cipher.dart';
import 'package:hivorr/core/security/crypto/key_derivation.dart';
import 'package:hivorr/core/security/security_config.dart';
import 'package:hivorr/core/storage/secure_storage.dart';
import 'package:hivorr/core/storage/secure_storage_config.dart';
import 'package:hivorr/core/storage/secure_token_store.dart';
import 'package:hivorr/core/storage/supabase_secure_local_storage.dart';

import 'fakes.dart';

void main() {
  group('FlutterSecureStorageImpl', () {
    late FakeFlutterSecureStorage backend;
    late FlutterSecureStorageImpl storage;

    setUp(() {
      backend = FakeFlutterSecureStorage();
      storage = FlutterSecureStorageImpl(
        config: const SecureStorageConfig(
          namespace: 'test',
          androidOptions: AndroidOptions(),
          iosOptions: IOSOptions(),
          webOptions: WebOptions(),
        ),
        backend: backend,
      );
    });

    test('namespaces written keys', () async {
      await storage.writeString('token', 'abc');
      expect(backend.store.containsKey('test.token'), isTrue);
      expect(await storage.readString('token'), 'abc');
    });

    test('round-trips boolean, int and json typed accessors', () async {
      await storage.writeBool('flag', true);
      await storage.writeInt('count', 42);
      await storage.writeJson('map', <String, dynamic>{'a': 1});

      expect(await storage.readBool('flag'), isTrue);
      expect(await storage.readInt('count'), 42);
      expect(await storage.readJson('map'), <String, dynamic>{'a': 1});
    });

    test('readBool/Int return null when absent', () async {
      expect(await storage.readBool('missing'), isNull);
      expect(await storage.readInt('missing'), isNull);
      expect(await storage.readJson('missing'), isNull);
    });

    test('delete removes a single namespaced key', () async {
      await storage.writeString('a', '1');
      await storage.writeString('b', '2');
      await storage.delete('a');
      expect(await storage.readString('a'), isNull);
      expect(await storage.readString('b'), '2');
    });

    test('clear removes all namespaced entries', () async {
      await storage.writeString('a', '1');
      await storage.writeString('b', '2');
      await storage.clear();
      expect(backend.store.isEmpty, isTrue);
    });
  });

  group('SecureTokenStore', () {
    late InMemorySecureStorage storage;
    late SecureTokenStore tokenStore;

    setUp(() {
      storage = InMemorySecureStorage();
      tokenStore = SecureTokenStore(storage);
    });

    test('persists and reads auth tokens, session id and device secret',
        () async {
      await tokenStore.writeAccessToken('at');
      await tokenStore.writeRefreshToken('rt');
      await tokenStore.writeSessionId('sid');
      await tokenStore.writeDeviceSecret('ds');

      expect(await tokenStore.readAccessToken(), 'at');
      expect(await tokenStore.readRefreshToken(), 'rt');
      expect(await tokenStore.readSessionId(), 'sid');
      expect(await tokenStore.readDeviceSecret(), 'ds');
    });

    test('clearTokens removes auth material but keeps device secret', () async {
      await tokenStore.writeAccessToken('at');
      await tokenStore.writeRefreshToken('rt');
      await tokenStore.writeSessionId('sid');
      await tokenStore.writeDeviceSecret('ds');

      await tokenStore.clearTokens();

      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
      expect(await tokenStore.readSessionId(), isNull);
      expect(await tokenStore.readDeviceSecret(), 'ds');
    });
  });

  group('SupabaseSecureLocalStorage', () {
    late InMemorySecureStorage storage;
    late SupabaseSecureLocalStorage local;

    setUp(() {
      storage = InMemorySecureStorage();
      local = SupabaseSecureLocalStorage(storage);
    });

    test('persists and exposes the session string', () async {
      expect(await local.hasAccessToken(), isFalse);

      await local.persistSession('{"session":1}');
      expect(await local.hasAccessToken(), isTrue);
      expect(await local.accessToken(), '{"session":1}');

      await local.removePersistedSession();
      expect(await local.hasAccessToken(), isFalse);
      expect(await local.accessToken(), isNull);
    });
  });

  group('SecureTokenStore (encrypted at rest)', () {
    late InMemorySecureStorage storage;
    late SecureTokenStore tokenStore;

    // Key derived from a device secret held in the same store (EP-01-10 §5.6).
    Future<SecretKey> deriveKey() => KeyDerivation.fromConfiguration(
      SecurityConfiguration(
        const SecurityConfig(
          pinningEnabled: false,
          pinnedSpkiSha256Hashes: <String>[],
          kdfSalt: 'salt',
          kdfIterations: 1000,
          kdfKeyLength: 32,
        ),
      ),
    ).deriveKey('device-secret');

    setUp(() {
      storage = InMemorySecureStorage();
      tokenStore = SecureTokenStore(
        storage,
        cipher: AesCipher.defaultInstance,
        deriveKey: deriveKey,
      );
    });

    test('encrypts token material; stored blob is not plaintext', () async {
      await tokenStore.writeAccessToken('at');
      await tokenStore.writeRefreshToken('rt');
      await tokenStore.writeSessionId('sid');

      // Backing store must contain ciphertext, never the raw token.
      expect(storage.entries['auth.access_token'], isNot(contains('at')));
      expect(storage.entries['auth.refresh_token'], isNot(contains('rt')));
      expect(storage.entries['auth.session_id'], isNot(contains('sid')));
    });

    test('round-trips encrypted token material', () async {
      await tokenStore.writeAccessToken('at');
      await tokenStore.writeRefreshToken('rt');
      await tokenStore.writeSessionId('sid');

      expect(await tokenStore.readAccessToken(), 'at');
      expect(await tokenStore.readRefreshToken(), 'rt');
      expect(await tokenStore.readSessionId(), 'sid');
    });

    test('uses a unique nonce per encryption (non-deterministic blob)',
        () async {
      await tokenStore.writeAccessToken('same');
      final String first = storage.entries['auth.access_token']!;
      await tokenStore.writeAccessToken('same');
      final String second = storage.entries['auth.access_token']!;

      expect(first, isNot(equals(second)));
    });

    test('clearTokens only removes encrypted token material', () async {
      await tokenStore.writeAccessToken('at');
      await tokenStore.writeRefreshToken('rt');
      await tokenStore.writeSessionId('sid');
      await tokenStore.writeDeviceSecret('ds');

      await tokenStore.clearTokens();

      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
      expect(await tokenStore.readSessionId(), isNull);
      expect(await tokenStore.readDeviceSecret(), 'ds');
    });

    test('without a cipher the store persists plaintext (backward compatible)',
        () async {
      final SecureTokenStore plaintextStore = SecureTokenStore(storage);
      await plaintextStore.writeAccessToken('at');
      expect(storage.entries['auth.access_token'], 'at');
      expect(await plaintextStore.readAccessToken(), 'at');
    });
  });
}
