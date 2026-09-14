import 'package:classsync/app/theme/classsync_theme.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/providers.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/core/integrations/relay/account_sync_client.dart';
import 'package:classsync/core/notifications/classsync_notification_service.dart';
import 'package:drift/native.dart';
import 'package:classsync/features/setup/setup_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'recovery finishes without overwriting restored keys with empty fields',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);
      final database = ClassSyncDatabase(NativeDatabase.memory());
      await database.initialize();
      final credentials = _RecoveryCredentials();
      final client = _RecoveryClient();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          credentialStoreProvider.overrideWithValue(credentials),
          accountSyncClientProvider.overrideWithValue(client),
          notificationServiceProvider.overrideWithValue(_NoPermissions()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SetupWizard()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use recovery code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'recovery-code-fixture',
      );
      await tester.tap(find.text('Join account'));
      await tester.pumpAndSettle();
      expect(find.text('Choose how quietly it works.'), findsOneWidget);
      expect(client.joined, isTrue);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      expect((await database.readSettings()).setupComplete, isTrue);
      expect(
        await credentials.read(CredentialKey.geminiApiKey),
        'restored-gemini',
      );
      expect(
        await credentials.read(CredentialKey.notionToken),
        'restored-notion',
      );
      expect(
        (await credentials.readFirefliesConnections()).single.apiKey,
        'restored-fireflies',
      );
      expect(await credentials.read(CredentialKey.relayDeviceToken), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pumpAndSettle();
      await database.close();
    },
  );
  testWidgets('existing account reaches recovery before any API key step', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_testApp());
    await tester.tap(find.text('Use recovery code'));
    await tester.pumpAndSettle();
    expect(find.text('Restore your study desk.'), findsOneWidget);
    expect(find.text('Recovery code from your first device'), findsOneWidget);
    expect(find.text('Fireflies API key'), findsNothing);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('wide setup explains prerequisites and shows syllabus', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 820);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());

    expect(find.text('SETUP SYLLABUS'), findsOneWidget);
    expect(find.text('Have these three things ready'), findsOneWidget);
    expect(find.text('Academic'), findsOneWidget);
    expect(
      find.text(
        'The hosted ClassSync relay creates accounts without a setup token. A custom relay may require an invite or registration token.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Start setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact setup remains focused and usable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());

    expect(find.text('ClassSync'), findsOneWidget);
    expect(find.text('1 / 9'), findsOneWidget);
    expect(find.text('SETUP SYLLABUS'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Start setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp() => ProviderScope(
  child: MaterialApp(theme: ClassSyncTheme.light(), home: const SetupWizard()),
);

class _RecoveryCredentials extends SecureCredentialStore {
  final values = <CredentialKey, String>{};
  @override
  Future<String?> read(CredentialKey key) async => values[key];
  @override
  Future<void> write(CredentialKey key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(CredentialKey key) async {
    values.remove(key);
  }
}

class _NoPermissions extends ClassSyncNotificationService {
  @override
  Future<void> requestPermissions() async {}
}

class _RecoveryClient extends AccountSyncClient {
  bool joined = false;
  static const account = SyncAccount(
    id: 'local-test-account',
    authSecret: 'test-secret',
    encryptionKey: 'test-key',
    deviceId: 'test-device',
  );
  @override
  Future<SyncAccount> joinAccount({
    required String baseUrl,
    required String recoveryCode,
    required SecureCredentialStore store,
  }) async {
    expect(recoveryCode, 'recovery-code-fixture');
    joined = true;
    return account;
  }

  @override
  Future<SyncAccount?> readAccount(SecureCredentialStore store) async =>
      joined ? account : null;
  @override
  Future<EncryptedSnapshot> readSnapshot({
    required String baseUrl,
    required SyncAccount account,
    required String scope,
  }) async => scope == 'config'
      ? const EncryptedSnapshot(revision: 1, ciphertext: 'test', nonce: 'test')
      : const EncryptedSnapshot(revision: 0);
  @override
  Future<Map<String, dynamic>> decrypt(
    SyncAccount account,
    EncryptedSnapshot snapshot,
  ) async => {
    'schemaVersion': 2,
    'settings': {
      'displayName': 'Recovered',
      'notionSubjectsDataSourceId': 'subjects',
      'notionSummariesDataSourceId': 'summaries',
    },
    'credentials': {
      'fireflies': 'restored-fireflies',
      'gemini': 'restored-gemini',
      'notion': 'restored-notion',
    },
  };
  @override
  Future<int> writeSnapshot({
    required String baseUrl,
    required SyncAccount account,
    required String scope,
    required int baseRevision,
    required Map<String, dynamic> payload,
  }) async => baseRevision + 1;
}
