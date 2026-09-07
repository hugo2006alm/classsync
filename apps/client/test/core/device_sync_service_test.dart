import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/integrations/relay/account_sync_client.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/core/sync/device_sync_service.dart';
import 'package:classsync/domain/settings/app_settings.dart';
import 'package:classsync/domain/settings/fireflies_connection.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClassSyncDatabase database;
  late _MemoryCredentialStore credentials;

  setUp(() async {
    database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
    credentials = _MemoryCredentialStore();
  });

  tearDown(() => database.close());

  test(
    'restores account name and named Fireflies keys from snapshot',
    () async {
      final client = _SnapshotAccountClient(
        remoteConfiguration: {
          'schemaVersion': 2,
          'settings': {'displayName': 'Hugo'},
          'credentials': {
            'firefliesConnections': const [
              {'id': 'mine', 'name': 'Hugo', 'apiKey': 'key-mine'},
              {'id': 'ana', 'name': 'Ana', 'apiKey': 'key-ana'},
            ],
            'gemini': 'gemini-key',
            'notion': 'notion-key',
          },
        },
      );
      final service = DeviceSyncService(
        database: database,
        credentials: credentials,
        client: client,
      );

      final result = await service.synchronize();

      expect(result.connected, isTrue);
      expect((await database.readSettings()).displayName, 'Hugo');
      final fireflies = await credentials.readFirefliesConnections();
      expect(fireflies.map((item) => item.name), ['Hugo', 'Ana']);
      expect(await credentials.read(CredentialKey.geminiApiKey), 'gemini-key');
      expect(await credentials.read(CredentialKey.notionToken), 'notion-key');
    },
  );

  test(
    'pushes profile and all named Fireflies keys in encrypted config',
    () async {
      await database.saveSettings(
        AppSettings.defaults.copyWith(displayName: 'Hugo'),
      );
      await credentials.writeFirefliesConnections(const [
        FirefliesConnection(id: 'mine', name: 'Hugo', apiKey: 'key-mine'),
        FirefliesConnection(id: 'ana', name: 'Ana', apiKey: 'key-ana'),
      ]);
      final client = _SnapshotAccountClient();
      final service = DeviceSyncService(
        database: database,
        credentials: credentials,
        client: client,
      );

      await service.pushConfiguration();

      final config = client.writes['config']!;
      expect(config['schemaVersion'], 2);
      expect((config['settings'] as Map)['displayName'], 'Hugo');
      expect(
        (config['credentials'] as Map)['firefliesConnections'],
        hasLength(2),
      );
    },
  );
}

class _MemoryCredentialStore extends SecureCredentialStore {
  final _values = <CredentialKey, String>{};

  @override
  Future<String?> read(CredentialKey key) async => _values[key];

  @override
  Future<void> write(CredentialKey key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(CredentialKey key) async => _values.remove(key);
}

class _SnapshotAccountClient extends AccountSyncClient {
  _SnapshotAccountClient({this.remoteConfiguration});

  final Map<String, dynamic>? remoteConfiguration;
  final writes = <String, Map<String, dynamic>>{};
  static const account = SyncAccount(
    id: '12345678-1234-1234-1234-123456789012',
    authSecret: 'abcdefghijklmnopqrstuvwxyz1234567890ABCDEFG',
    encryptionKey: 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=',
    deviceId: 'device-test',
  );

  @override
  Future<SyncAccount?> readAccount(SecureCredentialStore store) async =>
      account;

  @override
  Future<EncryptedSnapshot> readSnapshot({
    required String baseUrl,
    required SyncAccount account,
    required String scope,
  }) async => scope == 'config' && remoteConfiguration != null
      ? const EncryptedSnapshot(revision: 1, ciphertext: 'data', nonce: 'nonce')
      : const EncryptedSnapshot(revision: 0);

  @override
  Future<Map<String, dynamic>> decrypt(
    SyncAccount account,
    EncryptedSnapshot snapshot,
  ) async => remoteConfiguration!;

  @override
  Future<int> writeSnapshot({
    required String baseUrl,
    required SyncAccount account,
    required String scope,
    required int baseRevision,
    required Map<String, dynamic> payload,
  }) async {
    writes[scope] = payload;
    return baseRevision + 1;
  }
}
