import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/integrations/relay/account_sync_client.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/core/sync/device_sync_service.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:classsync/domain/academic/academic_models.dart';
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
    'recovery never uploads empty configuration when no snapshot exists',
    () async {
      final client = _SnapshotAccountClient();
      final service = DeviceSyncService(
        database: database,
        credentials: credentials,
        client: client,
      );
      await expectLater(
        service.restoreConfiguration(baseUrl: 'https://relay.test'),
        throwsFormatException,
      );
      expect(client.writes, isEmpty);
      expect((await database.readSettings()).setupComplete, isFalse);
    },
  );

  test(
    'recovery restores keys and mapping without requiring bootstrap token',
    () async {
      final client = _SnapshotAccountClient(
        remoteConfiguration: {
          'schemaVersion': 2,
          'settings': {
            'displayName': 'Restored user',
            'notionSubjectsDataSourceId': 'subjects',
            'notionSummariesDataSourceId': 'summaries',
          },
          'credentials': {
            'fireflies': 'restored-fireflies',
            'gemini': 'restored-gemini',
            'notion': 'restored-notion',
          },
        },
      );
      final service = DeviceSyncService(
        database: database,
        credentials: credentials,
        client: client,
      );
      await service.restoreConfiguration(baseUrl: 'https://relay.test');
      expect(
        await credentials.read(CredentialKey.geminiApiKey),
        'restored-gemini',
      );
      expect(
        await credentials.read(CredentialKey.notionToken),
        'restored-notion',
      );
      expect(await credentials.read(CredentialKey.relayDeviceToken), isNull);
      expect(
        (await database.readSettings()).notionSubjectsDataSourceId,
        'subjects',
      );
      expect((await database.readSettings()).setupComplete, isFalse);
      expect(client.writes, isEmpty);
    },
  );

  test(
    'recovery rejects malformed Fireflies list before changing settings',
    () async {
      final client = _SnapshotAccountClient(
        remoteConfiguration: {
          'settings': {
            'displayName': 'Should not apply',
            'notionSubjectsDataSourceId': 'subjects',
            'notionSummariesDataSourceId': 'summaries',
          },
          'credentials': {
            'gemini': 'key',
            'notion': 'key',
            'firefliesConnections': ['invalid'],
          },
        },
      );
      final before = await database.readSettings();
      final service = DeviceSyncService(
        database: database,
        credentials: credentials,
        client: client,
      );
      await expectLater(
        service.restoreConfiguration(baseUrl: 'https://relay.test'),
        throwsFormatException,
      );
      expect((await database.readSettings()).displayName, before.displayName);
      expect(client.writes, isEmpty);
    },
  );

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

  test('pushes all account-scoped credentials in schema v4 config', () async {
    await database.saveSettings(
      AppSettings.defaults.copyWith(displayName: 'Hugo'),
    );
    await credentials.writeFirefliesConnections(const [
      FirefliesConnection(
        id: 'mine',
        name: 'Hugo',
        apiKey: 'key-mine',
        firefliesUserId: 'fireflies-user-hugo',
        accountEmail: 'hugo@example.com',
      ),
      FirefliesConnection(id: 'ana', name: 'Ana', apiKey: 'key-ana'),
    ]);
    await credentials.write(CredentialKey.moodleToken, 'moodle-token');
    await credentials.write(CredentialKey.portalUsername, 'portal-user');
    await credentials.write(CredentialKey.portalPassword, ' portal pass ');
    await credentials.write(CredentialKey.syncDeviceId, 'device-local');
    await credentials.write(CredentialKey.relayDeviceToken, 'bootstrap-local');
    final client = _SnapshotAccountClient();
    final service = DeviceSyncService(
      database: database,
      credentials: credentials,
      client: client,
    );

    await service.pushConfiguration();

    final config = client.writes['config']!;
    expect(config['schemaVersion'], 4);
    expect((config['settings'] as Map)['useAiClassification'], isTrue);
    expect((config['settings'] as Map)['displayName'], 'Hugo');
    final savedCredentials = config['credentials'] as Map;
    expect(savedCredentials['firefliesConnections'], hasLength(2));
    expect(savedCredentials['moodleToken'], 'moodle-token');
    expect(savedCredentials['portalUsername'], 'portal-user');
    expect(savedCredentials['portalPassword'], ' portal pass ');
    expect(savedCredentials.containsKey('syncDeviceId'), isFalse);
    expect(savedCredentials.containsKey('relayDeviceToken'), isFalse);
  });

  test(
    'recovery restores Moodle and Portal without copying device state',
    () async {
      await credentials.write(CredentialKey.syncDeviceId, 'new-device');
      final client = _SnapshotAccountClient(
        remoteConfiguration: {
          'schemaVersion': 4,
          'settings': {
            'displayName': 'Restored',
            'useAiClassification': false,
            'notionSubjectsDataSourceId': 'subjects',
            'notionSummariesDataSourceId': 'summaries',
          },
          'credentials': {
            'firefliesConnections': const [
              {
                'id': 'source-stable',
                'name': 'My Fireflies',
                'apiKey': 'fireflies-key',
                'firefliesUserId': 'ff-user',
              },
            ],
            'gemini': 'gemini-key',
            'notion': 'notion-key',
            'moodleToken': 'moodle-token',
            'portalUsername': 'portal-user',
            'portalPassword': ' portal pass ',
          },
        },
      );
      final service = DeviceSyncService(
        database: database,
        credentials: credentials,
        client: client,
      );

      await service.restoreConfiguration(baseUrl: 'https://relay.test');

      expect(
        (await credentials.readFirefliesConnections()).single.id,
        'source-stable',
      );
      expect(await credentials.read(CredentialKey.moodleToken), 'moodle-token');
      expect(
        await credentials.read(CredentialKey.portalUsername),
        'portal-user',
      );
      expect(
        await credentials.read(CredentialKey.portalPassword),
        ' portal pass ',
      );
      expect(await credentials.read(CredentialKey.syncDeviceId), 'new-device');
      expect(await credentials.read(CredentialKey.relayDeviceToken), isNull);
      expect((await database.readSettings()).useAiClassification, isFalse);
    },
  );

  test(
    'schema v2 without academic credentials preserves valid local values',
    () async {
      await credentials.write(CredentialKey.moodleToken, 'local-moodle');
      final client = _SnapshotAccountClient(
        remoteConfiguration: {
          'schemaVersion': 2,
          'settings': {
            'notionSubjectsDataSourceId': 'subjects',
            'notionSummariesDataSourceId': 'summaries',
          },
          'credentials': {
            'fireflies': 'fireflies-key',
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

      await service.restoreConfiguration(baseUrl: 'https://relay.test');

      expect(await credentials.read(CredentialKey.moodleToken), 'local-moodle');
    },
  );

  test('lecture tasks merge through the encrypted account snapshot', () async {
    final localTask = LectureTask(
      id: 'task-local',
      title: 'Prepare local lab',
      description: 'Finish the local exercise.',
      sourceLectureId: 'job-local',
      sourceLectureTitle: 'Local lecture',
      confidence: LectureActionConfidence.certain,
      supportingSegment: 'private transcript evidence',
      status: LectureTaskStatus.pending,
    );
    await database.upsertAcademicRecord(
      AcademicRecord(
        key: AcademicRecord.keyFor(
          AcademicSource.manual,
          AcademicRecordKind.lectureTask,
          localTask.id,
        ),
        source: AcademicSource.manual,
        kind: AcademicRecordKind.lectureTask,
        externalId: localTask.id,
        title: localTask.title,
        payload: localTask.toJson(),
        syncedAt: DateTime.utc(2026, 9, 20),
      ),
    );
    final client = _SnapshotAccountClient(
      remoteJobs: {
        'schemaVersion': 2,
        'jobs': const [],
        'tasks': [
          {
            'key': 'manual:lectureTask:task-remote',
            'externalId': 'task-remote',
            'title': 'Prepare remote presentation',
            'syncedAt': '2026-09-21T10:00:00.000Z',
            'task': {
              'id': 'task-remote',
              'title': 'Prepare remote presentation',
              'description': 'Create the slides.',
              'sourceLectureId': 'job-remote',
              'sourceLectureTitle': 'Remote lecture',
              'confidence': 'certain',
              'supportingSegment': '',
              'status': 'completed',
              'userEdited': true,
            },
          },
        ],
      },
    );
    final service = DeviceSyncService(
      database: database,
      credentials: credentials,
      client: client,
    );

    final result = await service.synchronize();

    final tasks = await database.readAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
    );
    expect(tasks, hasLength(2));
    expect(
      LectureTask.fromJson(
        tasks.singleWhere((item) => item.externalId == 'task-remote').payload,
      ).status,
      LectureTaskStatus.completed,
    );
    final uploaded = client.writes['jobs']!['tasks'] as List<dynamic>;
    expect(uploaded, hasLength(2));
    final encodedLocal = uploaded.whereType<Map<String, dynamic>>().singleWhere(
      (item) => item['externalId'] == 'task-local',
    );
    expect(
      (encodedLocal['task'] as Map<String, dynamic>)['supportingSegment'],
      isEmpty,
    );
    expect(result.jobsChanged, isTrue);
  });
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
  _SnapshotAccountClient({this.remoteConfiguration, this.remoteJobs});

  final Map<String, dynamic>? remoteConfiguration;
  final Map<String, dynamic>? remoteJobs;
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
  }) async {
    if (scope == 'config' && remoteConfiguration != null) {
      return const EncryptedSnapshot(
        revision: 1,
        ciphertext: 'config',
        nonce: 'nonce',
      );
    }
    if (scope == 'jobs' && remoteJobs != null) {
      return const EncryptedSnapshot(
        revision: 1,
        ciphertext: 'jobs',
        nonce: 'nonce',
      );
    }
    return const EncryptedSnapshot(revision: 0);
  }

  @override
  Future<Map<String, dynamic>> decrypt(
    SyncAccount account,
    EncryptedSnapshot snapshot,
  ) async => snapshot.ciphertext == 'jobs' ? remoteJobs! : remoteConfiguration!;

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
