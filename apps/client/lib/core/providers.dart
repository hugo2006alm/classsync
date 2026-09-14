import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/academic/academic_models.dart';
import '../domain/academic/academic_hub_models.dart';
import '../domain/academic/portal_record_validation.dart';
import '../domain/academic/academic_hub_actions.dart';
import '../domain/settings/app_settings.dart';
import '../domain/settings/fireflies_connection.dart';
import '../domain/sync/sync_coordinator.dart';
import '../domain/sync/sync_models.dart';
import 'database/classsync_database.dart';
import 'academic/academic_sync_service.dart';
import 'academic/academic_research_service.dart';
import 'integrations/fireflies/fireflies_client.dart';
import 'integrations/gemini/gemini_client.dart';
import 'integrations/notion/notion_client.dart';
import 'integrations/moodle/moodle_client.dart';
import 'integrations/portal/isep_portal_client.dart';
import 'integrations/portal/strict_isep_portal_parser.dart';
import 'integrations/relay/relay_client.dart';
import 'integrations/relay/account_sync_client.dart';
import 'notifications/classsync_notification_service.dart';
import 'security/secure_credential_store.dart';
import 'sync/device_sync_service.dart';

extension AsyncValueCompatibility<T> on AsyncValue<T> {
  T? get valueOrNull => switch (this) {
    AsyncData<T>(:final value) => value,
    _ => null,
  };
}

final databaseProvider = Provider<ClassSyncDatabase>(
  (ref) => throw StateError('databaseProvider must be overridden at bootstrap'),
);

final credentialStoreProvider = Provider((ref) => SecureCredentialStore());
final credentialConfiguredProvider = FutureProvider.family<bool, CredentialKey>(
  (ref, key) => ref.watch(credentialStoreProvider).isConfigured(key),
);
final firefliesConnectionsProvider =
    FutureProvider<List<FirefliesConnectionSummary>>((ref) async {
      final connections = await ref
          .watch(credentialStoreProvider)
          .readFirefliesConnections();
      return connections.map((item) => item.summary).toList();
    });
final firefliesClientProvider = Provider((ref) => FirefliesClient());
final geminiClientProvider = Provider((ref) => GeminiClient());
final notionClientProvider = Provider((ref) => NotionClient());
final portalClientProvider = Provider<PortalAdapter>(
  (ref) => IsepPortalClient(parser: const StrictIsepPortalParser()),
);
final moodleClientProvider = Provider((ref) => MoodleClient());
final relayClientProvider = Provider((ref) => RelayClient());
final accountSyncClientProvider = Provider((ref) => AccountSyncClient());
final notificationServiceProvider = Provider(
  (ref) => ClassSyncNotificationService(),
);

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(databaseProvider).watchSettings(),
);

final syncAccountProvider = FutureProvider<SyncAccount?>((ref) {
  return ref
      .watch(accountSyncClientProvider)
      .readAccount(ref.watch(credentialStoreProvider));
});

final deviceSyncServiceProvider = Provider(
  (ref) => DeviceSyncService(
    database: ref.watch(databaseProvider),
    credentials: ref.watch(credentialStoreProvider),
    client: ref.watch(accountSyncClientProvider),
  ),
);

final activeSubjectsProvider = StreamProvider<List<AcademicSubject>>(
  (ref) => ref.watch(databaseProvider).watchActiveSubjects(),
);

final subjectsProvider = StreamProvider<List<AcademicSubject>>(
  (ref) => ref.watch(databaseProvider).watchSubjects(),
);

final academicRecordsProvider = StreamProvider<List<AcademicRecord>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchAcademicRecords()
      .map(
        (records) =>
            records.where((record) => !isInvalidPortalRecord(record)).toList(),
      ),
);

final academicChangesProvider = StreamProvider<List<AcademicChangeRow>>(
  (ref) => ref.watch(databaseProvider).watchAcademicChanges(),
);

final academicSyncServiceProvider = Provider((ref) {
  final service = AcademicSyncService(
    database: ref.watch(databaseProvider),
    credentials: ref.watch(credentialStoreProvider),
    portal: ref.watch(portalClientProvider),
    moodle: ref.watch(moodleClientProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final academicHubActionsProvider = Provider<AcademicHubActions>(
  (ref) => ref.watch(academicSyncServiceProvider),
);

final academicRefreshProvider = StreamProvider<AcademicRefreshState>((
  ref,
) async* {
  final service = ref.watch(academicSyncServiceProvider);
  yield service.refreshState;
  yield* service.refreshUpdates;
});

final academicFreshnessProvider = FutureProvider.family<DateTime?, String>((
  ref,
  stage,
) {
  ref.watch(academicRefreshProvider);
  return ref.watch(databaseProvider).readCursor('academic_success_$stage');
});

class AcademicConnectionState {
  const AcademicConnectionState({
    required this.portalConfigured,
    required this.moodleConfigured,
  });
  final bool portalConfigured;
  final bool moodleConfigured;
  bool get anyConfigured => portalConfigured || moodleConfigured;
}

final academicConnectionStateProvider = FutureProvider((ref) async {
  final store = ref.watch(credentialStoreProvider);
  final values = await Future.wait([
    store.isConfigured(CredentialKey.portalUsername),
    store.isConfigured(CredentialKey.portalPassword),
    store.isConfigured(CredentialKey.moodleToken),
  ]);
  return AcademicConnectionState(
    portalConfigured: values[0] && values[1],
    moodleConfigured: values[2],
  );
});

final academicResearchServiceProvider = Provider(
  (ref) => AcademicResearchService(
    database: ref.watch(databaseProvider),
    credentials: ref.watch(credentialStoreProvider),
    gemini: ref.watch(geminiClientProvider),
  ),
);

class NotionLibraryData {
  const NotionLibraryData({required this.summaries, required this.subjects});
  final List<NotionSummaryRecord> summaries;
  final Map<String, AcademicSubject> subjects;
}

final notionLibraryProvider = FutureProvider<NotionLibraryData>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  final token = await ref
      .watch(credentialStoreProvider)
      .read(CredentialKey.notionToken);
  final subjectsId = settings.notionSubjectsDataSourceId;
  final summariesId = settings.notionSummariesDataSourceId;
  if (token == null || subjectsId == null || summariesId == null) {
    throw StateError('Connect Notion and select both databases first.');
  }
  final notion = ref.watch(notionClientProvider);
  final values = await Future.wait([
    notion.querySubjects(token: token, dataSourceId: subjectsId),
    notion.querySummaries(token: token, dataSourceId: summariesId),
  ]);
  final subjects = values[0] as List<AcademicSubject>;
  return NotionLibraryData(
    subjects: {for (final subject in subjects) subject.notionId: subject},
    summaries: values[1] as List<NotionSummaryRecord>,
  );
});

final notionPageContentProvider =
    FutureProvider.family<List<NotionContentBlock>, String>((
      ref,
      pageId,
    ) async {
      final token = await ref
          .watch(credentialStoreProvider)
          .read(CredentialKey.notionToken);
      if (token == null) throw StateError('Connect Notion first.');
      return ref
          .watch(notionClientProvider)
          .readPageContent(token: token, pageId: pageId);
    });

final notionSubjectSummariesProvider =
    FutureProvider.family<List<NotionSummaryRecord>, String>((
      ref,
      subjectId,
    ) async {
      final settings = await ref.watch(settingsProvider.future);
      final token = await ref
          .watch(credentialStoreProvider)
          .read(CredentialKey.notionToken);
      final summariesId = settings.notionSummariesDataSourceId;
      if (token == null ||
          token.isEmpty ||
          summariesId == null ||
          summariesId.isEmpty) {
        return const [];
      }
      return ref
          .watch(notionClientProvider)
          .queryRecentSummariesForSubject(
            token: token,
            dataSourceId: summariesId,
            subjectId: subjectId,
          );
    });

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

final modelRetryPromptProvider = StateProvider<ModelRetryPrompt?>(
  (ref) => null,
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
    onModelRetrySuggested: (prompt) {
      ref.read(modelRetryPromptProvider.notifier).state = prompt;
    },
  ),
);

class SyncController extends StateNotifier<AsyncValue<SyncRunResult?>> {
  SyncController(this._coordinator, this._deviceSync, this._academicSync)
    : super(const AsyncData(null));
  final SyncCoordinator _coordinator;
  final DeviceSyncService _deviceSync;
  final AcademicSyncService _academicSync;

  Future<void> run(SyncReason reason) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final academic = _academicSync
          .synchronize(force: reason == SyncReason.manual)
          .then<void>((_) {}, onError: (Object _, StackTrace _) {});
      try {
        await _deviceSync.synchronize();
      } catch (_) {
        // Cloud state is an optional accelerator; lecture processing remains local-first.
      }
      final result = await _coordinator.run(reason);
      await academic;
      try {
        await _deviceSync.synchronize();
      } catch (_) {
        // The next foreground/manual run retries device synchronization.
      }
      return result;
    });
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncController, AsyncValue<SyncRunResult?>>(
      (ref) => SyncController(
        ref.watch(syncCoordinatorProvider),
        ref.watch(deviceSyncServiceProvider),
        ref.watch(academicSyncServiceProvider),
      ),
    );

class SettingsController {
  const SettingsController(this._database, this._deviceSync);
  final ClassSyncDatabase _database;
  final DeviceSyncService _deviceSync;

  Future<void> save(AppSettings settings) async {
    await _database.saveSettings(settings);
    try {
      await _deviceSync.pushConfiguration();
    } catch (_) {
      // Settings remain saved locally and are retried by the next sync.
    }
  }
}

final settingsControllerProvider = Provider(
  (ref) => SettingsController(
    ref.watch(databaseProvider),
    ref.watch(deviceSyncServiceProvider),
  ),
);
