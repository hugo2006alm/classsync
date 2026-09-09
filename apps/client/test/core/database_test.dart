import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:classsync/domain/settings/app_settings.dart';
import 'package:classsync/domain/sync/sync_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClassSyncDatabase database;

  setUp(() async {
    database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
  });

  tearDown(() => database.close());

  test(
    'remote snapshot imports a new terminal job instead of queueing it',
    () async {
      final date = DateTime.utc(2026);
      await database.mergeSyncedJob(
        SyncJob(
          id: 'remote',
          firefliesId: 'remote-fireflies',
          title: 'Published',
          meetingDate: date,
          status: SyncJobStatus.success,
          sourceType: 'fireflies',
          attemptCount: 1,
          discoveredAt: date,
          updatedAt: date,
          notionPageId: 'published-page',
        ),
      );
      final job = (await database.readJob('remote'))!;
      expect(job.status, SyncJobStatus.success);
      expect(job.notionPageId, 'published-page');
      expect(await database.claimRunnableJobs(owner: 'local'), isEmpty);
    },
  );

  test('remote snapshot cannot erase an active local lease', () async {
    await database.discoverJob(
      id: 'local',
      firefliesId: 'meeting',
      title: 'Local',
      meetingDate: DateTime.utc(2026),
    );
    await database.claimJob(id: 'local', owner: 'worker');
    final date = DateTime.now().toUtc().add(const Duration(minutes: 1));
    await database.mergeSyncedJob(
      SyncJob(
        id: 'remote-id',
        firefliesId: 'meeting',
        title: 'Remote',
        meetingDate: date,
        status: SyncJobStatus.queued,
        sourceType: 'fireflies',
        attemptCount: 0,
        discoveredAt: date,
        updatedAt: date,
      ),
    );
    expect((await database.readJob('local'))!.leaseOwner, 'worker');
  });

  test('active cache filters Done subjects', () async {
    await database.replaceSubjects([
      _subject('active', 'In progress'),
      _subject('done', 'Done'),
    ]);

    final active = await database.readActiveSubjects();

    expect(active.map((subject) => subject.name), ['active']);
    expect((await database.readSubjects()).map((subject) => subject.name), [
      'active',
      'done',
    ]);
  });

  test('initialization preserves completed setup settings', () async {
    final configured = AppSettings.defaults.copyWith(
      setupComplete: true,
      notionSubjectsDataSourceId: 'subjects-source',
      notionSummariesDataSourceId: 'summaries-source',
    );
    await database.saveSettings(configured);

    await database.initialize();
    final restored = await database.readSettings();

    expect(restored.setupComplete, isTrue);
    expect(restored.notionSubjectsDataSourceId, 'subjects-source');
    expect(restored.notionSummariesDataSourceId, 'summaries-source');
  });

  test('deduplicates jobs by Fireflies ID', () async {
    final first = await database.discoverJob(
      id: 'one',
      firefliesId: 'meeting-1',
      title: 'Lecture',
      meetingDate: DateTime.utc(2026),
    );
    final duplicate = await database.discoverJob(
      id: 'two',
      firefliesId: 'meeting-1',
      title: 'Lecture duplicate',
      meetingDate: DateTime.utc(2026),
    );

    expect(first, isTrue);
    expect(duplicate, isFalse);
    expect(await database.watchJobs().first, hasLength(1));
  });

  test('persists queue state and timeline before side effects', () async {
    await database.discoverJob(
      id: 'job',
      firefliesId: 'meeting',
      title: 'Lecture',
      meetingDate: DateTime.utc(2026),
    );
    await database.setJobStatus(
      'job',
      SyncJobStatus.fetchingTranscript,
      'Fetching',
    );

    expect(
      (await database.readJob('job'))?.status,
      SyncJobStatus.fetchingTranscript,
    );
    expect(await database.watchJobEvents('job').first, hasLength(2));
  });

  test(
    'active lease excludes another worker and expired lease recovers',
    () async {
      await database.discoverJob(
        id: 'leased',
        firefliesId: 'meeting-leased',
        title: 'Lecture',
        meetingDate: DateTime.utc(2026),
      );
      expect(
        await database.claimJob(
          id: 'leased',
          owner: 'worker-a',
          leaseDuration: const Duration(minutes: 1),
        ),
        isTrue,
      );
      expect(await database.claimJob(id: 'leased', owner: 'worker-b'), isFalse);
      await database.setJobStatus(
        'leased',
        SyncJobStatus.summarizing,
        'Summarizing',
      );
      await database.renewLease(
        'leased',
        'worker-a',
        duration: const Duration(seconds: -1),
      );
      expect(await database.claimJob(id: 'leased', owner: 'worker-b'), isTrue);
      expect((await database.readJob('leased'))?.leaseOwner, 'worker-b');
    },
  );

  test('unknown persisted status fails closed', () async {
    await database.discoverJob(
      id: 'corrupt',
      firefliesId: 'meeting-corrupt',
      title: 'Lecture',
      meetingDate: DateTime.utc(2026),
    );
    await database.customStatement(
      "UPDATE sync_jobs SET status = 'future_unknown' WHERE id = 'corrupt'",
    );
    expect((await database.readJob('corrupt'))?.status, SyncJobStatus.corrupt);
    expect(await database.claimJob(id: 'corrupt', owner: 'worker'), isFalse);
  });
}

AcademicSubject _subject(String name, String status) => AcademicSubject(
  notionId: name,
  name: name,
  year: '3º Ano',
  semester: '1º Semestre',
  status: status,
  lastSyncedAt: DateTime.utc(2026),
);
