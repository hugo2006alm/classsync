import 'dart:convert';

import '../../domain/academic/academic_hub_models.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/settings/fireflies_connection.dart';
import '../../domain/sync/sync_models.dart';
import '../database/classsync_database.dart';
import '../integrations/integration_exception.dart';
import '../integrations/relay/account_sync_client.dart';
import '../security/secure_credential_store.dart';

class DeviceSyncResult {
  const DeviceSyncResult({
    required this.connected,
    required this.configurationChanged,
    required this.jobsChanged,
  });
  final bool connected;
  final bool configurationChanged;
  final bool jobsChanged;
}

class DeviceSyncService {
  DeviceSyncService({
    required ClassSyncDatabase database,
    required SecureCredentialStore credentials,
    required AccountSyncClient client,
  }) : _database = database,
       _credentials = credentials,
       _client = client;

  final ClassSyncDatabase _database;
  final SecureCredentialStore _credentials;
  final AccountSyncClient _client;

  Future<DeviceSyncResult> synchronize({bool pushConfiguration = false}) async {
    final account = await _client.readAccount(_credentials);
    if (account == null) {
      return const DeviceSyncResult(
        connected: false,
        configurationChanged: false,
        jobsChanged: false,
      );
    }
    final settings = await _database.readSettings();
    final baseUrl = settings.relayBaseUrl ?? AppSettings.productionRelayBaseUrl;
    final configurationChanged = await _syncConfiguration(
      account: account,
      baseUrl: baseUrl,
      forcePush: pushConfiguration,
    );
    final jobsChanged = await _syncJobs(account: account, baseUrl: baseUrl);
    return DeviceSyncResult(
      connected: true,
      configurationChanged: configurationChanged,
      jobsChanged: jobsChanged,
    );
  }

  Future<void> pushConfiguration() async {
    await synchronize(pushConfiguration: true);
  }

  Future<void> restoreConfiguration({required String baseUrl}) async {
    final account = await _client.readAccount(_credentials);
    if (account == null) {
      throw const FormatException('Join your ClassSync account first.');
    }
    final snapshot = await _client.readSnapshot(
      baseUrl: baseUrl,
      account: account,
      scope: 'config',
    );
    if (!snapshot.exists) {
      throw const FormatException(
        'No saved configuration yet. Sync your first device, then retry recovery.',
      );
    }
    final payload = await _client.decrypt(account, snapshot);
    _validateConfiguration(payload, requireCompleteSetup: true);
    await _applyConfiguration(payload);
    await _credentials.write(
      CredentialKey.syncConfigRevision,
      snapshot.revision.toString(),
    );
  }

  Future<bool> _syncConfiguration({
    required SyncAccount account,
    required String baseUrl,
    required bool forcePush,
  }) async {
    final snapshot = await _client.readSnapshot(
      baseUrl: baseUrl,
      account: account,
      scope: 'config',
    );
    final lastRevision =
        int.tryParse(
          await _credentials.read(CredentialKey.syncConfigRevision) ?? '0',
        ) ??
        0;
    if (snapshot.exists && snapshot.revision > lastRevision && !forcePush) {
      final payload = await _client.decrypt(account, snapshot);
      _validateConfiguration(payload);
      await _applyConfiguration(payload);
      await _credentials.write(
        CredentialKey.syncConfigRevision,
        snapshot.revision.toString(),
      );
      return true;
    }
    final local = await _configurationPayload();
    if (snapshot.exists && !forcePush) {
      final remote = await _client.decrypt(account, snapshot);
      _validateConfiguration(remote);
      if (_canonical(remote) == _canonical(local)) {
        await _credentials.write(
          CredentialKey.syncConfigRevision,
          snapshot.revision.toString(),
        );
        return false;
      }
    }
    final revision = await _client.writeSnapshot(
      baseUrl: baseUrl,
      account: account,
      scope: 'config',
      baseRevision: snapshot.revision,
      payload: local,
    );
    await _credentials.write(
      CredentialKey.syncConfigRevision,
      revision.toString(),
    );
    return false;
  }

  Future<bool> _syncJobs({
    required SyncAccount account,
    required String baseUrl,
  }) async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await _syncJobsOnce(account: account, baseUrl: baseUrl);
      } on IntegrationException catch (error) {
        if (error.statusCode != 409 || attempt == 2) rethrow;
      }
    }
    throw StateError('Unreachable device sync retry state.');
  }

  Future<bool> _syncJobsOnce({
    required SyncAccount account,
    required String baseUrl,
  }) async {
    final snapshot = await _client.readSnapshot(
      baseUrl: baseUrl,
      account: account,
      scope: 'jobs',
    );
    final remotePayload = snapshot.exists
        ? await _client.decrypt(account, snapshot)
        : const <String, dynamic>{};
    final remoteJobs = (remotePayload['jobs'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_jobFromJson)
        .toList();
    final remoteTasks = (remotePayload['tasks'] as List<dynamic>? ?? const [])
        .take(500)
        .whereType<Map<String, dynamic>>()
        .map(_taskRecordFromJson)
        .whereType<AcademicRecord>()
        .toList();
    for (final job in remoteJobs) {
      await _database.mergeSyncedJob(job);
    }
    final localTasks = await _database.readAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
    );
    final mergedTasks = <String, AcademicRecord>{};
    for (final task in [...remoteTasks, ...localTasks]) {
      final current = mergedTasks[task.key];
      mergedTasks[task.key] = current == null
          ? task
          : _mergeTaskRecords(current, task);
    }
    var tasksChanged = false;
    final localTasksByKey = {for (final task in localTasks) task.key: task};
    for (final task in mergedTasks.values) {
      final local = localTasksByKey[task.key];
      final resolved = _mergeTaskEvidence(local, task);
      if (local == null ||
          _canonical(_taskRecordToJson(local)) !=
              _canonical(_taskRecordToJson(resolved))) {
        await _database.upsertAcademicRecord(resolved);
        tasksChanged = true;
      }
    }
    final localJobs = await _database.readJobs();
    final merged = <String, SyncJob>{};
    for (final job in [...remoteJobs, ...localJobs]) {
      final current = merged[job.firefliesId];
      if (current == null || job.updatedAt.isAfter(current.updatedAt)) {
        merged[job.firefliesId] = job;
      }
    }
    final payload = {
      'schemaVersion': 2,
      'jobs':
          (merged.values.toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
              .take(500)
              .map(_jobToJson)
              .toList(),
      'tasks':
          (mergedTasks.values.toList()
                ..sort((a, b) => b.syncedAt.compareTo(a.syncedAt)))
              .take(500)
              .map(_taskRecordToJson)
              .toList(),
    };
    final changed = _canonical(payload) != _canonical(remotePayload);
    if (changed) {
      final revision = await _client.writeSnapshot(
        baseUrl: baseUrl,
        account: account,
        scope: 'jobs',
        baseRevision: snapshot.revision,
        payload: payload,
      );
      await _credentials.write(
        CredentialKey.syncJobsRevision,
        revision.toString(),
      );
    } else {
      await _credentials.write(
        CredentialKey.syncJobsRevision,
        snapshot.revision.toString(),
      );
    }
    return remoteJobs.isNotEmpty || tasksChanged;
  }

  Future<Map<String, dynamic>> _configurationPayload() async {
    final settings = await _database.readSettings();
    final fireflies = await _credentials.readFirefliesConnections();
    final values = await Future.wait([
      _credentials.read(CredentialKey.geminiApiKey),
      _credentials.read(CredentialKey.notionToken),
      _credentials.read(CredentialKey.moodleToken),
      _credentials.read(CredentialKey.portalUsername),
      _credentials.read(CredentialKey.portalPassword),
    ]);
    return {
      'schemaVersion': 4,
      'settings': {
        'displayName': settings.displayName,
        'automaticSync': settings.automaticSync,
        'pollingMinutes': settings.pollingMinutes,
        'overlapHours': settings.overlapHours,
        'workerCount': settings.workerCount,
        'keepTranscripts': settings.keepTranscripts,
        'cleanCompletedPayloads': settings.cleanCompletedPayloads,
        'diagnosticsRetentionDays': settings.diagnosticsRetentionDays,
        'useAiClassification': settings.useAiClassification,
        'academicIntegrationsEnabled': settings.academicIntegrationsEnabled,
        'classificationModel': settings.classificationModel,
        'summaryModel': settings.summaryModel,
        'autoClassifyThreshold': settings.autoClassifyThreshold,
        'reviewThreshold': settings.reviewThreshold,
        'summaryLanguage': settings.summaryLanguage,
        'summaryDetail': settings.summaryDetail.name,
        'notionMetadataEnabled': settings.notionMetadataEnabled,
        'notionSubjectsDataSourceId': settings.notionSubjectsDataSourceId,
        'notionSummariesDataSourceId': settings.notionSummariesDataSourceId,
      },
      'credentials': {
        'fireflies': fireflies.firstOrNull?.apiKey,
        'firefliesConnections': fireflies.map((item) => item.toJson()).toList(),
        'gemini': values[0],
        'notion': values[1],
        'moodleToken': values[2],
        'portalUsername': values[3],
        'portalPassword': values[4],
      },
    };
  }

  void _validateConfiguration(
    Map<String, dynamic> payload, {
    bool requireCompleteSetup = false,
  }) {
    final rawVersion = payload['schemaVersion'];
    if (rawVersion != null && rawVersion is! num) {
      throw const FormatException('Saved configuration is malformed.');
    }
    final version = (rawVersion as num?)?.toInt() ?? 1;
    if (version < 1 || version > 4) {
      throw const FormatException(
        'Saved configuration uses an unsupported schema version.',
      );
    }
    final settings = payload['settings'];
    final credentials = payload['credentials'];
    if (settings is! Map<String, dynamic> ||
        credentials is! Map<String, dynamic>) {
      throw const FormatException('Saved configuration is malformed.');
    }
    for (final key in const [
      'displayName',
      'classificationModel',
      'summaryModel',
      'summaryLanguage',
      'summaryDetail',
      'notionSubjectsDataSourceId',
      'notionSummariesDataSourceId',
    ]) {
      final value = settings[key];
      if (value != null && value is! String) {
        throw const FormatException('Saved settings are malformed.');
      }
    }
    for (final key in const [
      'automaticSync',
      'keepTranscripts',
      'cleanCompletedPayloads',
      'useAiClassification',
      'academicIntegrationsEnabled',
      'notionMetadataEnabled',
    ]) {
      final value = settings[key];
      if (value != null && value is! bool) {
        throw const FormatException('Saved settings are malformed.');
      }
    }
    for (final key in const [
      'pollingMinutes',
      'overlapHours',
      'workerCount',
      'diagnosticsRetentionDays',
      'autoClassifyThreshold',
      'reviewThreshold',
    ]) {
      final value = settings[key];
      if (value != null && value is! num) {
        throw const FormatException('Saved settings are malformed.');
      }
    }
    final encodedConnections = credentials['firefliesConnections'];
    if (encodedConnections != null) {
      if (encodedConnections is! List ||
          encodedConnections.length > FirefliesConnection.maxConnections ||
          encodedConnections.any((value) => value is! Map<String, dynamic>)) {
        throw const FormatException('Saved Fireflies sources are malformed.');
      }
      final connections = encodedConnections
          .cast<Map<String, dynamic>>()
          .map(FirefliesConnection.fromJson)
          .toList();
      if (connections.map((item) => item.id).toSet().length !=
          connections.length) {
        throw const FormatException(
          'Saved Fireflies source IDs are not unique.',
        );
      }
      final accountIds = connections
          .map((item) => item.firefliesUserId)
          .whereType<String>()
          .toList();
      if (accountIds.toSet().length != accountIds.length) {
        throw const FormatException(
          'Saved Fireflies account identities are not unique.',
        );
      }
    }
    for (final key in const [
      'fireflies',
      'gemini',
      'notion',
      'moodleToken',
      'portalUsername',
      'portalPassword',
    ]) {
      final value = credentials[key];
      if (value != null && value is! String) {
        throw const FormatException('Saved credentials are malformed.');
      }
    }
    if (requireCompleteSetup) {
      final hasSources = encodedConnections is List
          ? encodedConnections.isNotEmpty
          : (credentials['fireflies'] as String?)?.isNotEmpty == true;
      if (!hasSources ||
          (credentials['gemini'] as String?)?.isNotEmpty != true ||
          (credentials['notion'] as String?)?.isNotEmpty != true ||
          (settings['notionSubjectsDataSourceId'] as String?)?.isNotEmpty !=
              true ||
          (settings['notionSummariesDataSourceId'] as String?)?.isNotEmpty !=
              true) {
        throw const FormatException(
          'Saved setup is incomplete. Finish setup and sync your first device, then retry recovery.',
        );
      }
    }
  }

  Future<void> _applyConfiguration(Map<String, dynamic> payload) async {
    final local = await _database.readSettings();
    final values = payload['settings'] as Map<String, dynamic>? ?? const {};
    final detail = SummaryDetail.values.where(
      (item) => item.name == values['summaryDetail'],
    );
    final merged = local.copyWith(
      displayName: values['displayName'] as String? ?? local.displayName,
      automaticSync: values['automaticSync'] as bool? ?? local.automaticSync,
      pollingMinutes: (values['pollingMinutes'] as num?)?.toInt(),
      overlapHours: (values['overlapHours'] as num?)?.toInt(),
      workerCount: (values['workerCount'] as num?)?.toInt(),
      keepTranscripts: values['keepTranscripts'] as bool?,
      cleanCompletedPayloads: values['cleanCompletedPayloads'] as bool?,
      diagnosticsRetentionDays: (values['diagnosticsRetentionDays'] as num?)
          ?.toInt(),
      useAiClassification: values['useAiClassification'] as bool?,
      academicIntegrationsEnabled:
          values['academicIntegrationsEnabled'] as bool?,
      classificationModel: values['classificationModel'] as String?,
      summaryModel: values['summaryModel'] as String?,
      autoClassifyThreshold: (values['autoClassifyThreshold'] as num?)
          ?.toDouble(),
      reviewThreshold: (values['reviewThreshold'] as num?)?.toDouble(),
      summaryLanguage: values['summaryLanguage'] as String?,
      summaryDetail: detail.isEmpty ? null : detail.first,
      notionMetadataEnabled: values['notionMetadataEnabled'] as bool?,
      notionSubjectsDataSourceId:
          values.containsKey('notionSubjectsDataSourceId')
          ? values['notionSubjectsDataSourceId'] as String?
          : local.notionSubjectsDataSourceId,
      notionSummariesDataSourceId:
          values.containsKey('notionSummariesDataSourceId')
          ? values['notionSummariesDataSourceId'] as String?
          : local.notionSummariesDataSourceId,
    );
    await _database.saveSettings(merged);
    final credentials =
        payload['credentials'] as Map<String, dynamic>? ?? const {};
    final encodedConnections = credentials['firefliesConnections'];
    if (encodedConnections is List) {
      final connections = encodedConnections
          .whereType<Map<String, dynamic>>()
          .map(FirefliesConnection.fromJson)
          .toList();
      await _credentials.writeFirefliesConnections(connections);
    } else if (credentials['fireflies'] case final String legacy
        when legacy.isNotEmpty) {
      await _credentials.writeFirefliesConnections([
        FirefliesConnection(
          id: FirefliesConnection.legacyId,
          name: 'Primary',
          apiKey: legacy,
        ),
      ]);
    }
    final valuesToWrite = <CredentialKey, String>{};
    for (final entry in <CredentialKey, String?>{
      CredentialKey.geminiApiKey: credentials['gemini'] as String?,
      CredentialKey.notionToken: credentials['notion'] as String?,
      CredentialKey.moodleToken: credentials['moodleToken'] as String?,
      CredentialKey.portalUsername: credentials['portalUsername'] as String?,
      CredentialKey.portalPassword: credentials['portalPassword'] as String?,
    }.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        valuesToWrite[entry.key] = entry.value!;
      }
    }
    await _credentials.writeAll(valuesToWrite);
  }

  Map<String, dynamic> _jobToJson(SyncJob job) => {
    'id': job.id,
    'firefliesId': job.firefliesId,
    'title': job.title,
    'meetingDate': job.meetingDate.toUtc().toIso8601String(),
    'firefliesUrl': job.firefliesUrl,
    'status': job.status.wireName,
    'sourceType': job.sourceType,
    'subjectId': job.subjectId,
    'subjectName': job.subjectName,
    'classificationConfidence': job.classificationConfidence,
    'summaryTitle': job.summaryTitle,
    'notionPageId': job.notionPageId,
    'notionUrl': job.notionUrl,
    'attemptCount': job.attemptCount,
    'nextRetryAt': job.nextRetryAt?.toUtc().toIso8601String(),
    'lastErrorType': job.lastErrorType,
    'lastErrorMessage': job.lastErrorMessage,
    'discoveredAt': job.discoveredAt.toUtc().toIso8601String(),
    'startedAt': job.startedAt?.toUtc().toIso8601String(),
    'updatedAt': job.updatedAt.toUtc().toIso8601String(),
    'completedAt': job.completedAt?.toUtc().toIso8601String(),
  };

  SyncJob _jobFromJson(Map<String, dynamic> value) => SyncJob(
    id: value['id'] as String,
    firefliesId: value['firefliesId'] as String,
    title: value['title'] as String? ?? 'Lecture',
    meetingDate: DateTime.parse(value['meetingDate'] as String).toUtc(),
    firefliesUrl: value['firefliesUrl'] as String?,
    status: SyncJobStatus.fromWire(value['status'] as String? ?? 'discovered'),
    sourceType: value['sourceType'] as String? ?? 'fireflies',
    subjectId: value['subjectId'] as String?,
    subjectName: value['subjectName'] as String?,
    classificationConfidence: (value['classificationConfidence'] as num?)
        ?.toDouble(),
    summaryTitle: value['summaryTitle'] as String?,
    notionPageId: value['notionPageId'] as String?,
    notionUrl: value['notionUrl'] as String?,
    attemptCount: (value['attemptCount'] as num? ?? 0).toInt(),
    nextRetryAt: _date(value['nextRetryAt']),
    lastErrorType: value['lastErrorType'] as String?,
    lastErrorMessage: value['lastErrorMessage'] as String?,
    discoveredAt: DateTime.parse(value['discoveredAt'] as String).toUtc(),
    startedAt: _date(value['startedAt']),
    updatedAt: DateTime.parse(value['updatedAt'] as String).toUtc(),
    completedAt: _date(value['completedAt']),
  );

  Map<String, dynamic> _taskRecordToJson(AcademicRecord record) {
    final task = LectureTask.fromJson(record.payload);
    return {
      'key': record.key,
      'externalId': record.externalId,
      'title': record.title,
      'subjectId': record.subjectId,
      'startsAt': record.startsAt?.toUtc().toIso8601String(),
      'syncedAt': record.syncedAt.toUtc().toIso8601String(),
      'task': {
        ...task.toJson(),
        // Transcript evidence remains device-local. The bounded task itself is
        // useful account state and travels only inside the encrypted snapshot.
        'supportingSegment': '',
        'userEdited': record.payload['userEdited'] == true,
        if (record.payload['statusUpdatedAt'] case final String updatedAt)
          'statusUpdatedAt': updatedAt,
      },
    };
  }

  AcademicRecord? _taskRecordFromJson(Map<String, dynamic> value) {
    try {
      final payload = value['task'];
      if (payload is! Map<String, dynamic>) return null;
      final task = LectureTask.fromJson(payload);
      final statusUpdatedAt = payload['statusUpdatedAt'];
      final key = value['key'] as String;
      final externalId = value['externalId'] as String;
      final syncedAt = DateTime.parse(value['syncedAt'] as String).toUtc();
      if (key !=
              AcademicRecord.keyFor(
                AcademicSource.manual,
                AcademicRecordKind.lectureTask,
                externalId,
              ) ||
          task.id != externalId ||
          task.title.trim().isEmpty ||
          task.title.length > 300 ||
          task.description.length > 4000 ||
          task.sourceLectureId.length > 500 ||
          task.sourceLectureTitle.length > 500 ||
          (task.subjectId?.length ?? 0) > 500 ||
          (task.subjectName?.length ?? 0) > 500 ||
          (statusUpdatedAt != null &&
              (statusUpdatedAt is! String ||
                  DateTime.tryParse(statusUpdatedAt) == null))) {
        return null;
      }
      return AcademicRecord(
        key: key,
        source: AcademicSource.manual,
        kind: AcademicRecordKind.lectureTask,
        externalId: externalId,
        title: task.title,
        subjectId: task.subjectId,
        startsAt: task.dueAt,
        payload: {
          ...task.toJson(),
          'userEdited': payload['userEdited'] == true,
          if (statusUpdatedAt is String)
            'statusUpdatedAt': DateTime.parse(
              statusUpdatedAt,
            ).toUtc().toIso8601String(),
        },
        syncedAt: syncedAt,
      );
    } on Object {
      return null;
    }
  }

  AcademicRecord _mergeTaskEvidence(
    AcademicRecord? local,
    AcademicRecord incoming,
  ) {
    final evidence = incoming.payload['supportingSegment'] as String? ?? '';
    if (evidence.isNotEmpty || local == null) return incoming;
    return incoming.copyWith(
      payload: {
        ...incoming.payload,
        'supportingSegment':
            local.payload['supportingSegment'] as String? ?? '',
      },
    );
  }

  AcademicRecord _mergeTaskRecords(
    AcademicRecord first,
    AcademicRecord second,
  ) {
    final newest = second.syncedAt.isBefore(first.syncedAt) ? first : second;
    final firstStatusAt = _taskStatusUpdatedAt(first);
    final secondStatusAt = _taskStatusUpdatedAt(second);
    final statusSource = switch ((firstStatusAt, secondStatusAt)) {
      (final DateTime left, final DateTime right) =>
        right.isBefore(left) ? first : second,
      (DateTime(), null) => first,
      (null, DateTime()) => second,
      (null, null) => newest,
    };
    final statusUpdatedAt = _taskStatusUpdatedAt(statusSource);
    return AcademicRecord(
      key: newest.key,
      source: newest.source,
      kind: newest.kind,
      externalId: newest.externalId,
      title: newest.title,
      subjectId: newest.subjectId,
      startsAt: newest.startsAt,
      endsAt: newest.endsAt,
      payload: {
        ...newest.payload,
        'status': statusSource.payload['status'],
        if (statusUpdatedAt != null)
          'statusUpdatedAt': statusUpdatedAt.toIso8601String(),
      },
      syncedAt: newest.syncedAt,
      changedFields: newest.changedFields,
      lastChangedAt: newest.lastChangedAt,
    );
  }

  DateTime? _taskStatusUpdatedAt(AcademicRecord record) =>
      _date(record.payload['statusUpdatedAt']);

  DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  String _canonical(Map<String, dynamic> value) => jsonEncode(value);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
