import 'package:classsync/core/integrations/relay/account_sync_client.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovery code round-trips and encrypted snapshot decrypts', () async {
    final client = AccountSyncClient();
    const source = SyncAccount(
      id: '12345678-1234-1234-1234-123456789012',
      authSecret: 'abcdefghijklmnopqrstuvwxyz1234567890ABCDEFG',
      encryptionKey: 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=',
      deviceId: 'device-original',
    );
    final restored = client.parseRecoveryCode(source.recoveryCode);
    expect(restored.id, source.id);
    expect(restored.authSecret, source.authSecret);
    expect(restored.encryptionKey, source.encryptionKey);
    expect(restored.deviceId, isNot(source.deviceId));

    final encrypted = await client.encrypt(source, {
      'credentials': {'notion': 'secret-value'},
    });
    final clear = await client.decrypt(
      source,
      EncryptedSnapshot(
        revision: 1,
        ciphertext: encrypted.ciphertext,
        nonce: encrypted.nonce,
      ),
    );
    expect(clear['credentials'], {'notion': 'secret-value'});
    expect(encrypted.ciphertext, isNot(contains('secret-value')));
  });

  test('rejects malformed account recovery codes', () {
    expect(
      () => AccountSyncClient().parseRecoveryCode('CS1.short.bad.code'),
      throwsFormatException,
    );
  });

  test(
    'joining persists every account field on a serialized secure store',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<void>(requestOptions: options, statusCode: 200),
          ),
        ),
      );
      final client = AccountSyncClient(dio: dio);
      final store = _SerializedCredentialStore();
      const source = SyncAccount(
        id: '12345678-1234-1234-1234-123456789012',
        authSecret: 'abcdefghijklmnopqrstuvwxyz1234567890ABCDEFG',
        encryptionKey: 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=',
        deviceId: 'device-original',
      );

      await client.joinAccount(
        baseUrl: 'https://relay.test',
        recoveryCode: source.recoveryCode,
        store: store,
      );

      final restored = await client.readAccount(store);
      expect(restored, isNotNull);
      expect(restored?.id, source.id);
      expect(restored?.authSecret, source.authSecret);
      expect(restored?.encryptionKey, source.encryptionKey);
    },
  );

  test('setup credential batch serializes every secure write', () async {
    final store = _SerializedCredentialStore();

    await store.writeAll(const {
      CredentialKey.firefliesApiKey: 'fireflies-key',
      CredentialKey.geminiApiKey: 'gemini-key',
      CredentialKey.notionToken: 'notion-key',
    });

    expect(await store.read(CredentialKey.firefliesApiKey), 'fireflies-key');
    expect(await store.read(CredentialKey.geminiApiKey), 'gemini-key');
    expect(await store.read(CredentialKey.notionToken), 'notion-key');
  });
}

class _SerializedCredentialStore extends SecureCredentialStore {
  final _values = <CredentialKey, String>{};
  var _writeInProgress = false;

  @override
  Future<String?> read(CredentialKey key) async => _values[key];

  @override
  Future<void> write(CredentialKey key, String value) async {
    if (_writeInProgress) return;
    _writeInProgress = true;
    await Future<void>.delayed(Duration.zero);
    _values[key] = value;
    _writeInProgress = false;
  }

  @override
  Future<void> delete(CredentialKey key) async => _values.remove(key);
}
