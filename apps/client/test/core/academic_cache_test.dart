import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClassSyncDatabase database;

  setUp(() async {
    database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
  });

  tearDown(() => database.close());

  test('refresh deduplicates stable academic record key', () async {
    final record = _evaluation(room: 'B301');
    await database.replaceAcademicRecords(
      source: AcademicSource.portal,
      kind: AcademicRecordKind.evaluation,
      records: [record, record],
    );
    expect(
      await database.readAcademicRecords(kind: AcademicRecordKind.evaluation),
      hasLength(1),
    );
  });

  test(
    'official date/location change is highlighted and retained in history',
    () async {
      await database.replaceAcademicRecords(
        source: AcademicSource.portal,
        kind: AcademicRecordKind.evaluation,
        records: [_evaluation(room: 'B301')],
      );
      await database.replaceAcademicRecords(
        source: AcademicSource.portal,
        kind: AcademicRecordKind.evaluation,
        records: [_evaluation(room: 'E101')],
      );
      final value = (await database.readAcademicRecords()).single;
      expect(value.changedFields, contains('location'));
      expect(await database.watchAcademicChanges().first, hasLength(1));
    },
  );

  test('external refresh preserves user-controlled reminder', () async {
    final initial = _evaluation(room: 'B301');
    await database.upsertAcademicRecord(
      initial.copyWith(payload: {...initial.payload, 'reminderMinutes': 1440}),
    );
    await database.replaceAcademicRecords(
      source: AcademicSource.portal,
      kind: AcademicRecordKind.evaluation,
      records: [_evaluation(room: 'B301')],
    );
    final value = (await database.readAcademicRecords()).single;
    expect(value.payload['reminderMinutes'], 1440);
  });

  test('official grade changes retain previous value', () async {
    await database.upsertAcademicRecord(_grade(12));
    await database.upsertAcademicRecord(_grade(14));
    final changes = await database.watchAcademicChanges().first;
    expect(changes, hasLength(1));
    expect(changes.single.previousPayloadJson, contains('12.0'));
  });

  test('task refresh preserves completion and user edits', () async {
    final original = AcademicRecord(
      key: AcademicRecord.keyFor(
        AcademicSource.manual,
        AcademicRecordKind.lectureTask,
        'task-1',
      ),
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
      externalId: 'task-1',
      title: 'Read chapter',
      payload: {
        'id': 'task-1',
        'sourceLectureId': 'lecture-1',
        'title': 'Read chapter 4',
        'description': 'Edited detail',
        'dueAt': '2026-09-10T00:00:00.000Z',
        'status': 'completed',
        'statusUpdatedAt': '2026-09-07T12:00:00.000Z',
        'userEdited': true,
      },
      syncedAt: DateTime.utc(2026, 9, 7),
    );
    await database.upsertAcademicRecord(original);
    await database.replaceAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
      records: [
        AcademicRecord(
          key: original.key,
          source: original.source,
          kind: original.kind,
          externalId: original.externalId,
          title: 'Read chapter',
          payload: {
            'id': 'task-1',
            'sourceLectureId': 'lecture-1',
            'title': 'Read chapter',
            'description': 'Generated again',
            'dueAt': '2026-09-10T00:00:00.000Z',
            'status': 'pending',
          },
          syncedAt: DateTime.utc(2026, 9, 8),
        ),
      ],
    );
    final task = (await database.readAcademicRecords()).single;
    expect(task.payload['status'], 'completed');
    expect(task.payload['statusUpdatedAt'], '2026-09-07T12:00:00.000Z');
    expect(task.payload['title'], 'Read chapter 4');
    expect(task.payload['description'], 'Edited detail');
  });

  test('Portal refresh preserves local notice read state', () async {
    AcademicRecord notice(bool read) => AcademicRecord(
      key: 'portal:notice:n-1',
      source: AcademicSource.portal,
      kind: AcademicRecordKind.portalNotification,
      externalId: 'n-1',
      title: 'Official notice',
      payload: {'message': 'Read me', 'read': read},
      syncedAt: DateTime.utc(2026, 9, 7),
    );
    await database.upsertAcademicRecord(notice(true));
    await database.replaceAcademicRecords(
      source: AcademicSource.portal,
      kind: AcademicRecordKind.portalNotification,
      records: [notice(false)],
    );
    expect(
      (await database.readAcademicRecords()).single.payload['read'],
      isTrue,
    );
  });

  test(
    'schema v4 upgrades add academic cache and account name safely',
    () async {
      final legacy = ClassSyncDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('PRAGMA user_version = 4');
            raw.execute('''
CREATE TABLE settings_records (
  id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
  setup_complete INTEGER NOT NULL,
  automatic_sync INTEGER NOT NULL,
  launch_with_windows INTEGER NOT NULL,
  sync_on_launch INTEGER NOT NULL,
  background_mobile_sync INTEGER NOT NULL,
  notifications_enabled INTEGER NOT NULL DEFAULT 1,
  polling_minutes INTEGER NOT NULL,
  overlap_hours INTEGER NOT NULL,
  worker_count INTEGER NOT NULL,
  keep_transcripts INTEGER NOT NULL,
  clean_completed_payloads INTEGER NOT NULL,
  diagnostics_retention_days INTEGER NOT NULL,
  classification_model TEXT NOT NULL,
  summary_model TEXT NOT NULL,
  auto_classify_threshold REAL NOT NULL,
  review_threshold REAL NOT NULL,
  summary_language TEXT NOT NULL,
  summary_detail TEXT NOT NULL,
  notion_metadata_enabled INTEGER NOT NULL,
  notion_subjects_data_source_id TEXT,
  notion_summaries_data_source_id TEXT,
  relay_base_url TEXT
)
''');
          },
        ),
      );
      await legacy.initialize();
      expect(await legacy.readAcademicRecords(), isEmpty);
      expect((await legacy.readSettings()).pollingMinutes, greaterThan(0));
      expect((await legacy.readSettings()).displayName, isEmpty);
      await legacy.close();
    },
  );

  test(
    'schema v6 retains settings and adds AI classification preference',
    () async {
      final legacy = ClassSyncDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('PRAGMA user_version = 6');
            raw.execute('''
CREATE TABLE settings_records (
  id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
  display_name TEXT NOT NULL DEFAULT '',
  setup_complete INTEGER NOT NULL,
  automatic_sync INTEGER NOT NULL,
  launch_with_windows INTEGER NOT NULL,
  sync_on_launch INTEGER NOT NULL,
  background_mobile_sync INTEGER NOT NULL,
  notifications_enabled INTEGER NOT NULL DEFAULT 1,
  polling_minutes INTEGER NOT NULL,
  overlap_hours INTEGER NOT NULL,
  worker_count INTEGER NOT NULL,
  keep_transcripts INTEGER NOT NULL,
  clean_completed_payloads INTEGER NOT NULL,
  diagnostics_retention_days INTEGER NOT NULL,
  classification_model TEXT NOT NULL,
  summary_model TEXT NOT NULL,
  auto_classify_threshold REAL NOT NULL,
  review_threshold REAL NOT NULL,
  summary_language TEXT NOT NULL,
  summary_detail TEXT NOT NULL,
  notion_metadata_enabled INTEGER NOT NULL,
  notion_subjects_data_source_id TEXT,
  notion_summaries_data_source_id TEXT,
  relay_base_url TEXT
)
''');
            raw.execute('''
INSERT INTO settings_records (
  id, display_name, setup_complete, automatic_sync, launch_with_windows,
  sync_on_launch, background_mobile_sync, notifications_enabled,
  polling_minutes, overlap_hours, worker_count, keep_transcripts,
  clean_completed_payloads, diagnostics_retention_days, classification_model,
  summary_model, auto_classify_threshold, review_threshold, summary_language,
  summary_detail, notion_metadata_enabled, notion_subjects_data_source_id,
  notion_summaries_data_source_id, relay_base_url
) VALUES (
  1, 'Hugo', 1, 1, 1, 1, 1, 1, 45, 72, 1, 0, 1, 21,
  'gemini-3.8-flash', 'gemini-3.8-flash', 0.85, 0.60,
  'Português (Portugal)', 'detailed', 1, 'subjects', 'summaries',
  'https://relay.test'
)
''');
          },
        ),
      );

      await legacy.initialize();
      final settings = await legacy.readSettings();
      expect(settings.displayName, 'Hugo');
      expect(settings.pollingMinutes, 45);
      expect(settings.useAiClassification, isTrue);
      expect(settings.classificationModel, 'gemini-3.1-flash-lite');
      expect(settings.summaryModel, 'gemini-3.8-flash');
      await legacy.close();
    },
  );
}

AcademicRecord _evaluation({required String room}) {
  final event = EvaluationEvent(
    externalId: 'exam-1',
    title: 'Database exam',
    type: 'Exam',
    subjectId: 'db',
    start: DateTime.utc(2027, 1, 18, 14, 30),
    location: room,
    provenance: const [
      AcademicProvenance(source: AcademicSource.portal, externalId: 'exam-1'),
    ],
  );
  return AcademicRecord(
    key: AcademicRecord.keyFor(
      AcademicSource.portal,
      AcademicRecordKind.evaluation,
      event.externalId,
    ),
    source: AcademicSource.portal,
    kind: AcademicRecordKind.evaluation,
    externalId: event.externalId,
    title: event.title,
    subjectId: event.subjectId,
    startsAt: event.start,
    payload: event.toJson(),
    syncedAt: DateTime.utc(2026),
  );
}

AcademicRecord _grade(double value) {
  final grade = GradeComponent(
    externalId: 'grade-1',
    subjectName: 'Bases de Dados',
    subjectId: 'db',
    name: 'Test 1',
    value: value,
    weight: 0.4,
    source: GradeValueSource.officialPortal,
  );
  return AcademicRecord(
    key: AcademicRecord.keyFor(
      AcademicSource.portal,
      AcademicRecordKind.grade,
      grade.externalId,
    ),
    source: AcademicSource.portal,
    kind: AcademicRecordKind.grade,
    externalId: grade.externalId,
    title: grade.name,
    subjectId: grade.subjectId,
    payload: grade.toJson(),
    syncedAt: DateTime.utc(2026),
  );
}
