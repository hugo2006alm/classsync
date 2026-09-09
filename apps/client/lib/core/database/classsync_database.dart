import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/academic/academic_models.dart';
import '../../domain/academic/academic_hub_models.dart';
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
  TextColumn get summaryPartialsJson => text().nullable()();
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
  TextColumn get leaseOwner => text().nullable()();
  DateTimeColumn get leaseExpiresAt => dateTime().nullable()();

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
  TextColumn get displayName => text().withDefault(const Constant(''))();
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

@DataClassName('AcademicCacheRow')
class AcademicCacheRecords extends Table {
  TextColumn get recordKey => text()();
  TextColumn get source => text()();
  TextColumn get kind => text()();
  TextColumn get externalId => text()();
  TextColumn get subjectId => text().nullable()();
  TextColumn get title => text()();
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  TextColumn get payloadJson => text()();
  TextColumn get fingerprint => text()();
  TextColumn get changedFieldsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get lastChangedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {recordKey};
}

@DataClassName('AcademicChangeRow')
class AcademicChangeRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordKey => text()();
  TextColumn get kind => text()();
  TextColumn get previousPayloadJson => text()();
  TextColumn get changedFieldsJson => text()();
  DateTimeColumn get changedAt => dateTime()();
}

@DriftDatabase(
  tables: [
    CachedSubjects,
    SyncJobs,
    JobEvents,
    SyncCursors,
    SettingsRecords,
    ClassificationCorrections,
    AcademicCacheRecords,
    AcademicChangeRecords,
  ],
)
class ClassSyncDatabase extends _$ClassSyncDatabase {
  ClassSyncDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'classsync'));

  @override
  int get schemaVersion => 6;

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
      if (from < 4) {
        await migrator.addColumn(syncJobs, syncJobs.summaryPartialsJson);
        await migrator.addColumn(syncJobs, syncJobs.leaseOwner);
        await migrator.addColumn(syncJobs, syncJobs.leaseExpiresAt);
      }
      if (from < 5) {
        await migrator.createTable(academicCacheRecords);
        await migrator.createTable(academicChangeRecords);
      }
      if (from < 6) {
        await migrator.addColumn(settingsRecords, settingsRecords.displayName);
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

  Future<void> saveSettings(AppSettings settings) {
    settings.validate();
    return into(settingsRecords).insertOnConflictUpdate(
      SettingsRecordsCompanion.insert(
        id: const Value(1),
        displayName: Value(settings.displayName),
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
        notionSummariesDataSourceId: Value(
          settings.notionSummariesDataSourceId,
        ),
        relayBaseUrl: Value(settings.relayBaseUrl),
      ),
    );
  }

  Stream<List<AcademicSubject>> watchActiveSubjects() =>
      (select(cachedSubjects)
            ..where((row) => row.status.lower().equals('in progress'))
            ..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .watch()
          .map((rows) => rows.map(_subjectFromRow).toList());

  Stream<List<AcademicSubject>> watchSubjects() =>
      (select(cachedSubjects)..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .watch()
          .map((rows) => rows.map(_subjectFromRow).toList());

  Future<List<AcademicSubject>> readSubjects() async =>
      (await (select(
            cachedSubjects,
          )..orderBy([(row) => OrderingTerm.asc(row.name)])).get())
          .map(_subjectFromRow)
          .toList();

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

  Stream<List<AcademicRecord>> watchAcademicRecords({
    Set<AcademicRecordKind>? kinds,
  }) {
    final query = select(academicCacheRecords)
      ..orderBy([
        (row) => OrderingTerm.asc(row.startsAt),
        (row) => OrderingTerm.asc(row.title),
      ]);
    if (kinds != null && kinds.isNotEmpty) {
      query.where((row) => row.kind.isIn(kinds.map((item) => item.name)));
    }
    return query.watch().map(
      (rows) => rows.map(_academicRecordFromRow).toList(),
    );
  }

  Future<List<AcademicRecord>> readAcademicRecords({
    AcademicSource? source,
    AcademicRecordKind? kind,
  }) async {
    final query = select(academicCacheRecords);
    if (source != null) query.where((row) => row.source.equals(source.name));
    if (kind != null) query.where((row) => row.kind.equals(kind.name));
    return (await query.get()).map(_academicRecordFromRow).toList();
  }

  Future<AcademicRecord?> readAcademicRecord(String key) async =>
      (await (select(
        academicCacheRecords,
      )..where((row) => row.recordKey.equals(key))).getSingleOrNull())?.let(
        _academicRecordFromRow,
      );

  Future<void> replaceAcademicRecords({
    required AcademicSource source,
    required AcademicRecordKind kind,
    required List<AcademicRecord> records,
  }) => transaction(() async {
    final existingRows =
        await (select(academicCacheRecords)..where(
              (row) =>
                  row.source.equals(source.name) & row.kind.equals(kind.name),
            ))
            .get();
    final existing = {for (final row in existingRows) row.recordKey: row};
    final incomingKeys = records.map((item) => item.key).toSet();
    for (final record in records) {
      final old = existing[record.key];
      final payload = _preserveLocalAcademicFields(
        old == null
            ? null
            : jsonDecode(old.payloadJson) as Map<String, dynamic>,
        record.payload,
      );
      final fingerprint = jsonEncode(_canonicalJson(payload));
      final changedFields = old == null || old.fingerprint == fingerprint
          ? const <String>[]
          : _changedAcademicFields(
              jsonDecode(old.payloadJson) as Map<String, dynamic>,
              payload,
            );
      final changedAt = changedFields.isEmpty
          ? old?.lastChangedAt
          : DateTime.now().toUtc();
      if (old != null && changedFields.isNotEmpty) {
        await into(academicChangeRecords).insert(
          AcademicChangeRecordsCompanion.insert(
            recordKey: record.key,
            kind: kind.name,
            previousPayloadJson: old.payloadJson,
            changedFieldsJson: jsonEncode(changedFields),
            changedAt: changedAt!,
          ),
        );
      }
      await into(academicCacheRecords).insertOnConflictUpdate(
        AcademicCacheRecordsCompanion.insert(
          recordKey: record.key,
          source: source.name,
          kind: kind.name,
          externalId: record.externalId,
          subjectId: Value(record.subjectId),
          title: record.title,
          startsAt: Value(record.startsAt),
          endsAt: Value(record.endsAt),
          payloadJson: jsonEncode(payload),
          fingerprint: fingerprint,
          changedFieldsJson: Value(jsonEncode(changedFields)),
          lastChangedAt: Value(changedAt),
          syncedAt: record.syncedAt,
        ),
      );
    }
    for (final old in existingRows) {
      if (!incomingKeys.contains(old.recordKey)) {
        await (delete(
          academicCacheRecords,
        )..where((row) => row.recordKey.equals(old.recordKey))).go();
      }
    }
  });

  Future<void> upsertAcademicRecord(AcademicRecord record) async {
    final old = await readAcademicRecord(record.key);
    final payload = record.payload;
    final changedFields = old == null
        ? const <String>[]
        : _changedAcademicFields(old.payload, payload);
    final changedAt = changedFields.isEmpty
        ? old?.lastChangedAt
        : DateTime.now().toUtc();
    if (old != null && changedFields.isNotEmpty) {
      await into(academicChangeRecords).insert(
        AcademicChangeRecordsCompanion.insert(
          recordKey: record.key,
          kind: record.kind.name,
          previousPayloadJson: jsonEncode(old.payload),
          changedFieldsJson: jsonEncode(changedFields),
          changedAt: changedAt!,
        ),
      );
    }
    await into(academicCacheRecords).insertOnConflictUpdate(
      AcademicCacheRecordsCompanion.insert(
        recordKey: record.key,
        source: record.source.name,
        kind: record.kind.name,
        externalId: record.externalId,
        subjectId: Value(record.subjectId),
        title: record.title,
        startsAt: Value(record.startsAt),
        endsAt: Value(record.endsAt),
        payloadJson: jsonEncode(payload),
        fingerprint: jsonEncode(_canonicalJson(payload)),
        changedFieldsJson: Value(jsonEncode(changedFields)),
        lastChangedAt: Value(changedAt),
        syncedAt: record.syncedAt,
      ),
    );
  }

  Future<void> deleteAcademicRecord(String key) => (delete(
    academicCacheRecords,
  )..where((row) => row.recordKey.equals(key))).go();

  Stream<List<AcademicChangeRow>> watchAcademicChanges({int limit = 100}) =>
      (select(academicChangeRecords)
            ..orderBy([(row) => OrderingTerm.desc(row.changedAt)])
            ..limit(limit))
          .watch();

  Stream<List<SyncJob>> watchJobs() =>
      (select(syncJobs)..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
          .watch()
          .map((rows) => rows.map(_jobFromRow).toList());

  Future<List<SyncJob>> readJobs() async =>
      (await (select(
            syncJobs,
          )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get())
          .map(_jobFromRow)
          .toList();

  Future<SyncJob?> readJobByFirefliesId(String firefliesId) async =>
      (await (select(syncJobs)
                ..where((row) => row.firefliesId.equals(firefliesId)))
              .getSingleOrNull())
          ?.let(_jobFromRow);

  Future<SyncJob?> readJob(String id) async => (await (select(
    syncJobs,
  )..where((row) => row.id.equals(id))).getSingleOrNull())?.let(_jobFromRow);

  Future<void> setJobSourceType(String id, String sourceType) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        SyncJobsCompanion(
          sourceType: Value(sourceType),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

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

  Future<void> mergeSyncedJob(SyncJob remote) => transaction(() async {
    var local = await readJobByFirefliesId(remote.firefliesId);
    final isNew = local == null;
    if (local == null) {
      await discoverJob(
        id: remote.id,
        firefliesId: remote.firefliesId,
        title: remote.title,
        meetingDate: remote.meetingDate,
        firefliesUrl: remote.firefliesUrl,
        sourceType: remote.sourceType,
      );
      local = await readJobByFirefliesId(remote.firefliesId);
    }
    if (local == null) return;
    if (local.leaseOwner != null &&
        local.leaseExpiresAt?.isAfter(DateTime.now().toUtc()) == true) {
      return;
    }
    if (!isNew && !remote.updatedAt.isAfter(local.updatedAt)) return;
    await (update(syncJobs)..where((row) => row.id.equals(local!.id))).write(
      SyncJobsCompanion(
        meetingTitle: Value(remote.title),
        meetingDate: Value(remote.meetingDate),
        firefliesUrl: Value(remote.firefliesUrl),
        status: Value(remote.status.wireName),
        sourceType: Value(remote.sourceType),
        subjectId: Value(remote.subjectId),
        subjectName: Value(remote.subjectName),
        classificationConfidence: Value(remote.classificationConfidence),
        summaryTitle: Value(remote.summaryTitle),
        notionPageId: Value(remote.notionPageId),
        notionUrl: Value(remote.notionUrl),
        attemptCount: Value(remote.attemptCount),
        nextRetryAt: Value(remote.nextRetryAt),
        lastErrorType: Value(remote.lastErrorType),
        lastErrorMessage: Value(remote.lastErrorMessage),
        startedAt: Value(remote.startedAt),
        updatedAt: Value(remote.updatedAt),
        completedAt: Value(remote.completedAt),
        leaseOwner: const Value(null),
        leaseExpiresAt: const Value(null),
      ),
    );
  });

  Future<List<SyncJob>> claimRunnableJobs({
    required String owner,
    int limit = 50,
    Duration leaseDuration = const Duration(minutes: 30),
  }) => transaction(() async {
    final now = DateTime.now().toUtc();
    final statuses = [
      SyncJobStatus.discovered.wireName,
      SyncJobStatus.queued.wireName,
      SyncJobStatus.failedRetryable.wireName,
    ];
    final processing = SyncJobStatus.values
        .where((status) => status.isProcessing)
        .map((status) => status.wireName)
        .toList();
    final query = select(syncJobs)
      ..where(
        (row) =>
            ((row.status.isIn(statuses) &
                    (row.nextRetryAt.isNull() |
                        row.nextRetryAt.isSmallerOrEqualValue(now))) |
                (row.status.isIn(processing) &
                    (row.leaseExpiresAt.isNull() |
                        row.leaseExpiresAt.isSmallerOrEqualValue(now)))) &
            (row.leaseOwner.isNull() |
                row.leaseExpiresAt.isNull() |
                row.leaseExpiresAt.isSmallerOrEqualValue(now)),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.discoveredAt)])
      ..limit(limit.clamp(1, 100));
    final candidates = await query.get();
    final claimed = <SyncJob>[];
    for (final candidate in candidates) {
      final changed =
          await (update(syncJobs)..where(
                (row) =>
                    row.id.equals(candidate.id) &
                    (row.leaseOwner.isNull() |
                        row.leaseExpiresAt.isNull() |
                        row.leaseExpiresAt.isSmallerOrEqualValue(now)),
              ))
              .write(
                SyncJobsCompanion(
                  leaseOwner: Value(owner),
                  leaseExpiresAt: Value(now.add(leaseDuration)),
                  updatedAt: Value(now),
                ),
              );
      if (changed == 1) {
        final row = await (select(
          syncJobs,
        )..where((item) => item.id.equals(candidate.id))).getSingle();
        claimed.add(_jobFromRow(row));
      }
    }
    return claimed;
  });

  Future<bool> claimJob({
    required String id,
    required String owner,
    Duration leaseDuration = const Duration(minutes: 30),
  }) => transaction(() async {
    final now = DateTime.now().toUtc();
    final row = await (select(
      syncJobs,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    if (row == null) return false;
    final status = SyncJobStatus.fromWire(row.status);
    final runnable =
        status == SyncJobStatus.discovered ||
        status == SyncJobStatus.queued ||
        (status == SyncJobStatus.failedRetryable &&
            (row.nextRetryAt == null || !row.nextRetryAt!.isAfter(now))) ||
        (status.isProcessing &&
            (row.leaseExpiresAt == null || !row.leaseExpiresAt!.isAfter(now)));
    if (!runnable ||
        (row.leaseOwner != null &&
            row.leaseExpiresAt != null &&
            row.leaseExpiresAt!.isAfter(now))) {
      return false;
    }
    final changed =
        await (update(syncJobs)..where(
              (item) =>
                  item.id.equals(id) &
                  (item.leaseOwner.isNull() |
                      item.leaseExpiresAt.isNull() |
                      item.leaseExpiresAt.isSmallerOrEqualValue(now)),
            ))
            .write(
              SyncJobsCompanion(
                leaseOwner: Value(owner),
                leaseExpiresAt: Value(now.add(leaseDuration)),
                updatedAt: Value(now),
              ),
            );
    return changed == 1;
  });

  Future<bool> renewLease(
    String id,
    String owner, {
    Duration duration = const Duration(minutes: 30),
  }) async {
    final now = DateTime.now().toUtc();
    final changed =
        await (update(
              syncJobs,
            )..where((row) => row.id.equals(id) & row.leaseOwner.equals(owner)))
            .write(
              SyncJobsCompanion(
                leaseExpiresAt: Value(now.add(duration)),
                updatedAt: Value(now),
              ),
            );
    return changed == 1;
  }

  Future<void> releaseLease(String id, String owner) =>
      (update(syncJobs)
            ..where((row) => row.id.equals(id) & row.leaseOwner.equals(owner)))
          .write(
            const SyncJobsCompanion(
              leaseOwner: Value(null),
              leaseExpiresAt: Value(null),
            ),
          );

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
        leaseOwner: status.isProcessing || status == SyncJobStatus.queued
            ? const Value.absent()
            : const Value(null),
        leaseExpiresAt: status.isProcessing || status == SyncJobStatus.queued
            ? const Value.absent()
            : const Value(null),
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

  Future<void> learnClassificationCorrection(
    String jobId,
    AcademicSubject subject,
  ) async {
    final job = await readJob(jobId);
    if (job == null) return;
    final pattern = job.title.trim().toLowerCase();
    if (pattern.isEmpty) return;
    await transaction(() async {
      await (delete(
        classificationCorrections,
      )..where((row) => row.titlePattern.equals(pattern))).go();
      await into(classificationCorrections).insert(
        ClassificationCorrectionsCompanion.insert(
          titlePattern: Value(
            pattern.length <= 120
                ? pattern
                : String.fromCharCodes(pattern.runes.take(120)),
          ),
          subjectId: subject.notionId,
          subjectName: subject.name,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    });
  }

  Future<ClassificationCorrectionRow?> matchingCorrection(String title) =>
      (select(classificationCorrections)
            ..where(
              (row) => row.titlePattern.equals(title.trim().toLowerCase()),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<List<ClassificationCorrectionRow>> watchCorrections() => (select(
    classificationCorrections,
  )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch();

  Future<void> deleteCorrection(int id) => (delete(
    classificationCorrections,
  )..where((row) => row.id.equals(id))).go();

  Future<void> saveSummary(String id, LectureSummary summary) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        SyncJobsCompanion(
          summaryTitle: Value(summary.title),
          summaryJson: Value(summary.encode()),
          summaryPartialsJson: const Value(null),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<List<Map<String, dynamic>>> readSummaryPartials(String id) async {
    final row = await (select(
      syncJobs,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    final encoded = row?.summaryPartialsJson;
    if (encoded == null) return const [];
    return (jsonDecode(encoded) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> saveSummaryPartials(
    String id,
    List<Map<String, dynamic>> partials,
  ) => (update(syncJobs)..where((row) => row.id.equals(id))).write(
    SyncJobsCompanion(
      summaryPartialsJson: Value(jsonEncode(partials)),
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
        summaryPartialsJson: clearSummary
            ? const Value(null)
            : const Value.absent(),
        reprocessMode: const Value('replace'),
        nextRetryAt: const Value(null),
        lastErrorType: const Value(null),
        lastErrorMessage: const Value(null),
        completedAt: const Value(null),
        leaseOwner: const Value(null),
        leaseExpiresAt: const Value(null),
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
        leaseOwner: const Value(null),
        leaseExpiresAt: const Value(null),
      ),
    );
    await addJobEvent(id, status, message);
  }

  Future<void> clearTranscriptPayload(String id) =>
      (update(syncJobs)..where((row) => row.id.equals(id))).write(
        const SyncJobsCompanion(transcriptJson: Value(null)),
      );

  Future<int> pruneAbandonedPayloads(Duration retention) =>
      (update(syncJobs)..where(
            (row) =>
                row.updatedAt.isSmallerThanValue(
                  DateTime.now().toUtc().subtract(retention),
                ) &
                row.status.isIn([
                  SyncJobStatus.needsReview.wireName,
                  SyncJobStatus.failedTerminal.wireName,
                  SyncJobStatus.corrupt.wireName,
                ]),
          ))
          .write(
            const SyncJobsCompanion(
              transcriptJson: Value(null),
              summaryPartialsJson: Value(null),
            ),
          );

  Future<int> purgeStoredContent() => update(syncJobs).write(
    const SyncJobsCompanion(
      transcriptJson: Value(null),
      summaryJson: Value(null),
      summaryPartialsJson: Value(null),
    ),
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
    leaseOwner: row.leaseOwner,
    leaseExpiresAt: row.leaseExpiresAt,
    summaryPartialsJson: row.summaryPartialsJson,
  );

  AcademicRecord _academicRecordFromRow(AcademicCacheRow row) => AcademicRecord(
    key: row.recordKey,
    source: AcademicSource.values.firstWhere(
      (item) => item.name == row.source,
      orElse: () => AcademicSource.manual,
    ),
    kind: AcademicRecordKind.values.firstWhere(
      (item) => item.name == row.kind,
      orElse: () => AcademicRecordKind.evaluation,
    ),
    externalId: row.externalId,
    title: row.title,
    subjectId: row.subjectId,
    startsAt: row.startsAt,
    endsAt: row.endsAt,
    payload: jsonDecode(row.payloadJson) as Map<String, dynamic>,
    changedFields: _decodeStringList(row.changedFieldsJson),
    lastChangedAt: row.lastChangedAt,
    syncedAt: row.syncedAt,
  );

  AppSettings _settingsFromRow(SettingsRow row) => AppSettings(
    displayName: row.displayName,
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

Map<String, dynamic> _preserveLocalAcademicFields(
  Map<String, dynamic>? old,
  Map<String, dynamic> incoming,
) {
  final result = <String, dynamic>{...incoming};
  if (old?['reminderMinutes'] != null && result['reminderMinutes'] == null) {
    result['reminderMinutes'] = old!['reminderMinutes'];
  }
  if (old?['overdueReminderConfigured'] == true) {
    result['overdueReminder'] = old!['overdueReminder'];
    result['overdueReminderConfigured'] = true;
  }
  if (old?['status'] != null && incoming.containsKey('sourceLectureId')) {
    result['status'] = old!['status'];
  }
  if (old?['userEdited'] == true && incoming.containsKey('sourceLectureId')) {
    for (final key in const ['title', 'description', 'dueAt']) {
      result[key] = old![key];
    }
    result['userEdited'] = true;
  }
  if (old?['read'] == true && incoming.containsKey('read')) {
    result['read'] = true;
  }
  return result;
}

List<String> _changedAcademicFields(
  Map<String, dynamic> old,
  Map<String, dynamic> current,
) {
  const ignored = {
    'reminderMinutes',
    'overdueReminder',
    'overdueReminderConfigured',
    'provenance',
    'status',
    'userEdited',
    'read',
  };
  final keys = {...old.keys, ...current.keys}..removeAll(ignored);
  return keys
      .where(
        (key) =>
            jsonEncode(_canonicalJson(old[key])) !=
            jsonEncode(_canonicalJson(current[key])),
      )
      .toList()
    ..sort();
}

dynamic _canonicalJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalJson(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalJson).toList();
  return value;
}
