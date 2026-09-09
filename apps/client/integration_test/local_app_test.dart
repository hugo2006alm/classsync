import 'package:classsync/app/classsync_app.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/providers.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/domain/settings/app_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _EmptyCredentials extends SecureCredentialStore {
  @override
  Future<String?> read(CredentialKey key) async => null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native offline navigation, empty states and import cancellation',
    (tester) async {
      final database = ClassSyncDatabase(NativeDatabase.memory());
      await database.initialize();
      await database.saveSettings(
        AppSettings.defaults.copyWith(
          setupComplete: true,
          automaticSync: false,
          notificationsEnabled: false,
          notionSubjectsDataSourceId: 'offline-subjects',
          notionSummariesDataSourceId: 'offline-summaries',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          credentialStoreProvider.overrideWithValue(_EmptyCredentials()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ClassSyncApp(),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Classes',
        'Library',
        'Academic',
        'Sync',
        'Settings',
        'Overview',
      ]) {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.tap(find.text('Sync').first);
      await tester.pumpAndSettle();
      expect(find.text('No transcripts discovered yet'), findsOneWidget);
      await tester.tap(find.text('Import transcript'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await database.readJobs(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await database.close();
    },
  );
}
