import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/academic/academic_models.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/sync/sync_models.dart';

part 'classsync_database.g.dart';

@DataClassName('CachedSubjectRow')
class CachedSubjects extends Table {
  TextColumn get notionId => text()();
  TextColumn get name => text()();
  TextColumn get year => text()();
  TextColumn get semester => text()();
  TextColumn get status => text()();
  TextColumn get notionUrl => text().nullable()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get professorsJson => text().withDefault(const Constant('[]'))();
  TextColumn get scheduleHintsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {notionId};
}

@DataClassName('SyncJobRow')
class SyncJobs extends Table {
  TextColumn get id => text()();
  TextColumn get firefliesId => text().unique()();
  TextColumn get meetingTitle => text()();
  DateTimeColumn get meetingDate => dateTime()();
  TextColumn get firefliesUrl => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('discovered'))();
  TextColumn get sourceType =>
      text().withDefault(const Constant('fireflies'))();
  TextColumn get subjectId => text().nullable()();
  TextColumn get subjectName => text().nullable()();
  RealColumn get classificationConfidence => real().nullable()();
  TextColumn get classificationCandidatesJson => text().nullable()();
  TextColumn get transcriptJson => text().nullable()();
  TextColumn get summaryTitle => text().nullable()();
  TextColumn get summaryJson => text().nullable()();
  TextColumn get notionPageId => text().nullable()();
  TextColumn get notionUrl => text().nullable()();
  TextColumn get reprocessMode => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastErrorType => text().nullable()();
  TextColumn get lastErrorMessage => text().nullable()();
  DateTimeColumn get discoveredAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('JobEventRow')
class JobEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobId => text().references(SyncJobs, #id)();
  TextColumn get stage => text()();
  TextColumn get message => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get source => text()();
  DateTimeColumn get cursorAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {source};
}

@DataClassName('SettingsRow')
class SettingsRecords extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get setupComplete => boolean()();
  BoolColumn get automaticSync => boolean()();
  BoolColumn get launchWithWindows => boolean()();
  BoolColumn get syncOnLaunch => boolean()();
  BoolColumn get backgroundMobileSync => boolean()();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get pollingMinutes => integer()();
  IntColumn get overlapHours => integer()();
  IntColumn get workerCount => integer()();
  BoolColumn get keepTranscripts => boolean()();
  BoolColumn get cleanCompletedPayloads => boolean()();
  IntColumn get diagnosticsRetentionDays => integer()();
  TextColumn get classificationModel => text()();
  TextColumn get summaryModel => text()();
  RealColumn get autoClassifyThreshold => real()();
  RealColumn get reviewThreshold => real()();
  TextColumn get summaryLanguage => text()();
  TextColumn get summaryDetail => text()();
  BoolColumn get notionMetadataEnabled => boolean()();
  TextColumn get notionSubjectsDataSourceId => text().nullable()();
  TextColumn get notionSummariesDataSourceId => text().nullable()();
  TextColumn get relayBaseUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ClassificationCorrectionRow')
class ClassificationCorrections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titlePattern => text().nullable()();
  TextColumn get speakerHint => text().nullable()();
  IntColumn get weekday => integer().nullable()();
  TextColumn get timeHint => text().nullable()();
  TextColumn get subjectId => text()();
  TextColumn get subjectName => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(
  tables: [
    CachedSubjects,
    SyncJobs,
    JobEvents,
    SyncCursors,
    SettingsRecords,
    ClassificationCorrections,
  ],
)
class ClassSyncDatabase extends _$ClassSyncDatabase {
  ClassSyncDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'classsync'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(syncJobs, syncJobs.reprocessMode);
      }
      if (from < 3) {
        await migrator.addColumn(
          settingsRecords,
          settingsRecords.notificationsEnabled,
        );
      }
    },
  );

  Future<void> initialize() async {
    final existing = await (select(
      settingsRecords,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    if (existing == null) await saveSettings(AppSettings.defaults);
  }

  Stream<AppSettings> watchSettings() =>
      (select(
        settingsRecords,
      )..where((row) => row.id.equals(1))).watchSingleOrNull().map(
        (row) => row == null ? AppSettings.defaults : _settingsFromRow(row),
      );

  Future<AppSettings> readSettings() async {
    final row = await (select(
      settingsRecords,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    return row == null ? AppSettings.defaults : _settingsFromRow(row);
  }

  Future<void> saveSettings(
    AppSettings settings,
  ) => into(settingsRecords).insertOnConflictUpdate(
    SettingsRecordsCompanion.insert(
      id: const Value(1),
      setupComplete: settings.setupComplete,
      automaticSync: settings.automaticSync,
      launchWithWindows: settings.launchWithWindows,
      syncOnLaunch: settings.syncOnLaunch,
      backgroundMobileSync: settings.backgroundMobileSync,
      notificationsEnabled: Value(settings.notificationsEnabled),
      pollingMinutes: settings.pollingMinutes,
      overlapHours: settings.overlapHours,
      workerCount: settings.workerCount,
      keepTranscripts: settings.keepTranscripts,
      cleanCompletedPayloads: settings.cleanCompletedPayloads,
      diagnosticsRetentionDays: settings.diagnosticsRetentionDays,
      classificationModel: settings.classificationModel,
      summaryModel: settings.summaryModel,
      autoClassifyThreshold: settings.autoClassifyThreshold,
      reviewThreshold: settings.reviewThreshold,
      summaryLanguage: settings.summaryLanguage,
      summaryDetail: settings.summaryDetail.name,
      notionMetadataEnabled: settings.notionMetadataEnabled,
      notionSubjectsDataSourceId: Value(settings.notionSubjectsDataSourceId),
      notionSummariesDataSourceId: Value(settings.notionSummariesDataSourceId),
      relayBaseUrl: Value(settings.relayBaseUrl),
    ),
  );

  Stream<List<AcademicSubject>> watchActiveSubjects() =>
      (select(cachedSubjects)
            ..where((row) => row.status.lower().equals('in progress'))
            ..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .watch()
          .map((rows) => rows.map(_subjectFromRow).toList());

  Future<List<AcademicSubject>> readActiveSubjects() async =>
      (await (select(cachedSubjects)
                ..where((row) => row.status.lower().equals('in progress'))
                ..orderBy([(row) => OrderingTerm.asc(row.name)]))
              .get())
          .map(_subjectFromRow)
          .toList();

  Future<void> replaceSubjects(List<AcademicSubject> subjects) =>
      transaction(() async {
        await delete(cachedSubjects).go();
        await batch((batch) {
          batch.insertAll(
            cachedSubjects,
            subjects
                .map(
                  (subject) => CachedSubjectsCompanion.insert(
                    notionId: subject.notionId,
                    name: subject.name,
                    year: subject.year,
                    semester: subject.semester,
                    status: subject.status,
                    notionUrl: Value(subject.notionUrl),
                    aliasesJson: Value(jsonEncode(subject.aliases)),
                    professorsJson: Value(jsonEncode(subject.professors)),
                    scheduleHintsJson: Value(jsonEncode(subject.scheduleHints)),
                    lastSyncedAt: subject.lastSyncedAt,
                  ),
                )
                .toList(),
            mode: InsertMode.insertOrReplace,
          );
        });
      });

  Stream<List<SyncJob>> watchJobs() =>
      (select(syncJobs)..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
          .watch()
          .map((rows) => rows.map(_jobFromRow).toList());

  Future<SyncJob?> readJob(String id) async => (await (select(
    syncJobs,
  )..where((row) => row.id.equals(id))).getSingleOrNull())?.let(_jobFromRow);

  Stream<SyncJob?> watchJob(String id) =>
      (select(syncJobs)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row?.let(_jobFromRow));

  Future<bool> discoverJob({
    required String id,
    required String firefliesId,
    required String title,
    required DateTime meetingDate,
    String? firefliesUrl,
    String sourceType = 'fireflies',
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await (select(
      syncJobs,
    )..where((row) => row.firefliesId.equals(firefliesId))).getSingleOrNull();
    if (existing != null) return false;
    await into(syncJobs).insert(
      SyncJobsCompanion.insert(
        id: id,
        firefliesId: firefliesId,
        meetingTitle: title,
        meetingDate: meetingDate,
        firefliesUrl: Value(firefliesUrl),
        sourceType: Value(sourceType),
        discoveredAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    final created = await (select(
      syncJobs,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (created == null) return false;
    await addJobEvent(id, SyncJobStatus.discovered, 'Transcript discovered');
    return true;
  }

  Future<List<SyncJob>> readRunnableJobs() async {
    final now = DateTime.now().toUtc();
    final statuses = [
      SyncJobStatus.discovered.wireName,
      SyncJobStatus.queued.wireName,
      SyncJobStatus.failedRetryable.wireName,
    ];
    final query = select(syncJobs)
      ..where(
        (row) =>
            row.status.isIn(statuses) &
            (row.nextRetryAt.isNull() |
                row.nextRetryAt.isSmallerOrEqualValue(now)),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.discoveredAt)]);
    return (await query.get()).map(_jobFromRow).toList();
  }

  Future<void> setJobStatus(
    String id,
    SyncJobStatus status,
    String message, {
    bool terminal = false,
  }) async {
    final now = DateTime.now().toUtc();
    await (update(syncJobs)..where((row) => row.id.equals(id))).write(
      SyncJobsCompanion(
        status: Value(status.wireName),
        startedAt: status.isProcessing ? Value(now) : const Value.absent(),
        updatedAt: Value(now),
        completedAt: terminal ? Value(now) : const Value.absent(),
      ),
    );
    await addJobEvent(id, status, message);
  }

  Future<void> saveTranscript(String id, LectureTranscript transcript) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        SyncJobsCompanion(
          meetingTitle: Value(transcript.title),
          meetingDate: Value(transcript.date),
          firefliesUrl: Value(transcript.firefliesUrl),
          transcriptJson: Value(transcript.toStoredJson()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> saveClassification(String id, ClassificationResult result) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        SyncJobsCompanion(
          subjectId: Value(result.subjectId),
          subjectName: Value(result.subjectName),
          classificationConfidence: Value(result.confidence),
          classificationCandidatesJson: Value(jsonEncode(result.toJson())),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> saveManualSubject(String id, AcademicSubject subject) async {
    await (update(syncJobs)..where((row) => row.id.equals(id))).write(
      SyncJobsCompanion(
        subjectId: Value(subject.notionId),
        subjectName: Value(subject.name),
        status: Value(SyncJobStatus.queued.wireName),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await addJobEvent(
      id,
      SyncJobStatus.queued,
      'Subject confirmed: ${subject.name}',
    );
  }

  Future<void> saveSummary(String id, LectureSummary summary) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        SyncJobsCompanion(
          summaryTitle: Value(summary.title),
          summaryJson: Value(summary.encode()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> saveNotionPage(String id, String pageId, String? url) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        SyncJobsCompanion(
          notionPageId: Value(pageId),
          notionUrl: Value(url),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> prepareReprocess(String id, String mode) async {
    final clearClassification = mode == 'reclassify';
    final clearSummary = mode == 'reclassify' || mode == 'regenerate';
    await (update(syncJobs)..where((row) => row.id.equals(id))).write(
      SyncJobsCompanion(
        status: Value(SyncJobStatus.queued.wireName),
        subjectId: clearClassification
            ? const Value(null)
            : const Value.absent(),
        subjectName: clearClassification
            ? const Value(null)
            : const Value.absent(),
        classificationConfidence: clearClassification
            ? const Value(null)
            : const Value.absent(),
        classificationCandidatesJson: clearClassification
            ? const Value(null)
            : const Value.absent(),
        summaryTitle: clearSummary ? const Value(null) : const Value.absent(),
        summaryJson: clearSummary ? const Value(null) : const Value.absent(),
        reprocessMode: const Value('replace'),
        nextRetryAt: const Value(null),
        lastErrorType: const Value(null),
        lastErrorMessage: const Value(null),
        completedAt: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await addJobEvent(id, SyncJobStatus.queued, switch (mode) {
      'reclassify' => 'Subject reclassification requested',
      'regenerate' => 'Summary regeneration requested',
      _ => 'Notion republish requested',
    });
  }

  Future<void> finishReprocess(String id) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        const SyncJobsCompanion(reprocessMode: Value(null)),
      );

  Future<void> markFailure({
    required String id,
    required String errorType,
    required String message,
    required bool retryable,
    DateTime? nextRetryAt,
  }) async {
    final current = await readJob(id);
    final status = retryable
        ? SyncJobStatus.failedRetryable
        : SyncJobStatus.failedTerminal;
    await (update(syncJobs)..where((row) => row.id.equals(id))).write(
      SyncJobsCompanion(
        status: Value(status.wireName),
        attemptCount: Value((current?.attemptCount ?? 0) + 1),
        nextRetryAt: Value(nextRetryAt),
        lastErrorType: Value(errorType),
        lastErrorMessage: Value(message),
        updatedAt: Value(DateTime.now().toUtc()),
        completedAt: retryable
            ? const Value.absent()
            : Value(DateTime.now().toUtc()),
      ),
    );
    await addJobEvent(id, status, message);
  }

  Future<void> clearTranscriptPayload(String id) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        const SyncJobsCompanion(transcriptJson: Value(null)),
      );

  Future<void> addJobEvent(
    String jobId,
    SyncJobStatus status,
    String message,
  ) => into(jobEvents).insert(
    JobEventsCompanion.insert(
      jobId: jobId,
      stage: status.wireName,
      message: message,
      createdAt: DateTime.now().toUtc(),
    ),
  );

  Stream<List<JobTimelineEvent>> watchJobEvents(String jobId) =>
      (select(jobEvents)
            ..where((row) => row.jobId.equals(jobId))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .watch()
          .map(
            (rows) => rows
                .map(
                  (row) => JobTimelineEvent(
                    id: row.id,
                    jobId: row.jobId,
                    stage: row.stage,
                    message: row.message,
                    createdAt: row.createdAt,
                  ),
                )
                .toList(),
          );

  Future<int> pruneDiagnostics(Duration retention) =>
      (delete(jobEvents)..where(
            (row) => row.createdAt.isSmallerThanValue(
              DateTime.now().toUtc().subtract(retention),
            ),
          ))
          .go();

  Future<DateTime?> readCursor(String source) async => (await (select(
    syncCursors,
  )..where((row) => row.source.equals(source))).getSingleOrNull())?.cursorAt;

  Future<void> saveCursor(String source, DateTime cursorAt) =>
      into(syncCursors).insertOnConflictUpdate(
        SyncCursorsCompanion.insert(source: source, cursorAt: cursorAt),
      );

  AcademicSubject _subjectFromRow(CachedSubjectRow row) => AcademicSubject(
    notionId: row.notionId,
    name: row.name,
    year: row.year,
    semester: row.semester,
    status: row.status,
    notionUrl: row.notionUrl,
    aliases: _decodeStringList(row.aliasesJson),
    professors: _decodeStringList(row.professorsJson),
    scheduleHints: _decodeStringList(row.scheduleHintsJson),
    lastSyncedAt: row.lastSyncedAt,
  );

  SyncJob _jobFromRow(SyncJobRow row) => SyncJob(
    id: row.id,
    firefliesId: row.firefliesId,
    title: row.meetingTitle,
    meetingDate: row.meetingDate,
    firefliesUrl: row.firefliesUrl,
    status: SyncJobStatus.fromWire(row.status),
    sourceType: row.sourceType,
    subjectId: row.subjectId,
    subjectName: row.subjectName,
    classificationConfidence: row.classificationConfidence,
    classificationCandidatesJson: row.classificationCandidatesJson,
    transcriptJson: row.transcriptJson,
    summaryTitle: row.summaryTitle,
    summaryJson: row.summaryJson,
    notionPageId: row.notionPageId,
    notionUrl: row.notionUrl,
    reprocessMode: row.reprocessMode,
    attemptCount: row.attemptCount,
    nextRetryAt: row.nextRetryAt,
    lastErrorType: row.lastErrorType,
    lastErrorMessage: row.lastErrorMessage,
    discoveredAt: row.discoveredAt,
    startedAt: row.startedAt,
    updatedAt: row.updatedAt,
    completedAt: row.completedAt,
  );

  AppSettings _settingsFromRow(SettingsRow row) => AppSettings(
    setupComplete: row.setupComplete,
    automaticSync: row.automaticSync,
    launchWithWindows: row.launchWithWindows,
    syncOnLaunch: row.syncOnLaunch,
    backgroundMobileSync: row.backgroundMobileSync,
    notificationsEnabled: row.notificationsEnabled,
    pollingMinutes: row.pollingMinutes,
    overlapHours: row.overlapHours,
    workerCount: row.workerCount,
    keepTranscripts: row.keepTranscripts,
    cleanCompletedPayloads: row.cleanCompletedPayloads,
    diagnosticsRetentionDays: row.diagnosticsRetentionDays,
    classificationModel: row.classificationModel,
    summaryModel: row.summaryModel,
    autoClassifyThreshold: row.autoClassifyThreshold,
    reviewThreshold: row.reviewThreshold,
    summaryLanguage: row.summaryLanguage,
    summaryDetail: SummaryDetail.values.firstWhere(
      (detail) => detail.name == row.summaryDetail,
      orElse: () => SummaryDetail.detailed,
    ),
    notionMetadataEnabled: row.notionMetadataEnabled,
    notionSubjectsDataSourceId: row.notionSubjectsDataSourceId,
    notionSummariesDataSourceId: row.notionSummariesDataSourceId,
    relayBaseUrl: row.relayBaseUrl,
  );
}

extension _LetExtension<T> on T {
  R let<R>(R Function(T value) callback) => callback(this);
}

List<String> _decodeStringList(String source) =>
    (jsonDecode(source) as List<dynamic>)
        .map((item) => item.toString())
        .toList();
