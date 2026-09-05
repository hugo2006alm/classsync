import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/academic/academic_models.dart';
import '../domain/settings/app_settings.dart';
import '../domain/sync/sync_coordinator.dart';
import '../domain/sync/sync_models.dart';
import 'database/classsync_database.dart';
import 'integrations/fireflies/fireflies_client.dart';
import 'integrations/gemini/gemini_client.dart';
import 'integrations/notion/notion_client.dart';
import 'integrations/relay/relay_client.dart';
import 'notifications/classsync_notification_service.dart';
import 'security/secure_credential_store.dart';

final databaseProvider = Provider<ClassSyncDatabase>(
  (ref) => throw StateError('databaseProvider must be overridden at bootstrap'),
);

final credentialStoreProvider = Provider((ref) => SecureCredentialStore());
final firefliesClientProvider = Provider((ref) => FirefliesClient());
final geminiClientProvider = Provider((ref) => GeminiClient());
final notionClientProvider = Provider((ref) => NotionClient());
final relayClientProvider = Provider((ref) => RelayClient());
final notificationServiceProvider = Provider(
  (ref) => ClassSyncNotificationService(),
);

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(databaseProvider).watchSettings(),
);

final activeSubjectsProvider = StreamProvider<List<AcademicSubject>>(
  (ref) => ref.watch(databaseProvider).watchActiveSubjects(),
);

final syncJobsProvider = StreamProvider<List<SyncJob>>(
  (ref) => ref.watch(databaseProvider).watchJobs(),
);

final classificationCorrectionsProvider =
    StreamProvider<List<ClassificationCorrectionRow>>(
      (ref) => ref.watch(databaseProvider).watchCorrections(),
    );

final syncJobProvider = StreamProvider.family<SyncJob?, String>(
  (ref, id) => ref.watch(databaseProvider).watchJob(id),
);

final jobTimelineProvider =
    StreamProvider.family<List<JobTimelineEvent>, String>(
      (ref, id) => ref.watch(databaseProvider).watchJobEvents(id),
    );

final syncCoordinatorProvider = Provider(
  (ref) => SyncCoordinator(
    database: ref.watch(databaseProvider),
    credentials: ref.watch(credentialStoreProvider),
    fireflies: ref.watch(firefliesClientProvider),
    gemini: ref.watch(geminiClientProvider),
    notion: ref.watch(notionClientProvider),
    relay: ref.watch(relayClientProvider),
    notifier: ref.watch(notificationServiceProvider),
  ),
);

class SyncController extends StateNotifier<AsyncValue<SyncRunResult?>> {
  SyncController(this._coordinator) : super(const AsyncData(null));
  final SyncCoordinator _coordinator;

  Future<void> run(SyncReason reason) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _coordinator.run(reason));
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncController, AsyncValue<SyncRunResult?>>(
      (ref) => SyncController(ref.watch(syncCoordinatorProvider)),
    );

class SettingsController {
  const SettingsController(this._database);
  final ClassSyncDatabase _database;

  Future<void> save(AppSettings settings) => _database.saveSettings(settings);
}

final settingsControllerProvider = Provider(
  (ref) => SettingsController(ref.watch(databaseProvider)),
);
