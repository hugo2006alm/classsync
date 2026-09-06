import 'package:classsync/core/integrations/relay/account_sync_client.dart';
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
}
