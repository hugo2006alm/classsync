import 'dart:convert';

import '../../domain/settings/app_settings.dart';
import '../../domain/settings/fireflies_connection.dart';
import '../../domain/sync/sync_models.dart';
import '../database/classsync_database.dart';
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
    final settings = payload['settings'];
    final credentials = payload['credentials'];
    var hasFireflies = false;
    if (credentials is Map) {
      final connections = credentials['firefliesConnections'];
      if (connections is List) {
        hasFireflies =
            connections.isNotEmpty &&
            connections.length <= FirefliesConnection.maxConnections &&
            connections.every((value) => value is Map<String, dynamic>);
        if (hasFireflies) {
          for (final value in connections) {
            FirefliesConnection.fromJson(value as Map<String, dynamic>);
          }
        }
      } else {
        hasFireflies =
            credentials['fireflies'] is String &&
            (credentials['fireflies'] as String).trim().isNotEmpty;
      }
    }
    if (settings is! Map ||
        credentials is! Map ||
        settings['notionSubjectsDataSourceId'] is! String ||
        settings['notionSummariesDataSourceId'] is! String ||
        (settings['notionSubjectsDataSourceId'] as String).isEmpty ||
        (settings['notionSummariesDataSourceId'] as String).isEmpty ||
        credentials['gemini'] is! String ||
        (credentials['gemini'] as String).isEmpty ||
        credentials['notion'] is! String ||
        (credentials['notion'] as String).isEmpty ||
        !hasFireflies) {
      throw const FormatException(
        'Saved setup is incomplete. Finish setup and sync your first device, then retry recovery.',
      );
    }
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
    for (final job in remoteJobs) {
      await _database.mergeSyncedJob(job);
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
      'schemaVersion': 1,
      'jobs':
          (merged.values.toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
              .take(500)
              .map(_jobToJson)
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
    return remoteJobs.isNotEmpty;
  }

  Future<Map<String, dynamic>> _configurationPayload() async {
    final settings = await _database.readSettings();
    final fireflies = await _credentials.readFirefliesConnections();
    final values = await Future.wait([
      _credentials.read(CredentialKey.geminiApiKey),
      _credentials.read(CredentialKey.notionToken),
    ]);
    return {
      'schemaVersion': 2,
      'settings': {
        'displayName': settings.displayName,
        'automaticSync': settings.automaticSync,
        'pollingMinutes': settings.pollingMinutes,
        'overlapHours': settings.overlapHours,
        'workerCount': settings.workerCount,
        'keepTranscripts': settings.keepTranscripts,
        'cleanCompletedPayloads': settings.cleanCompletedPayloads,
        'diagnosticsRetentionDays': settings.diagnosticsRetentionDays,
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
      },
    };
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

  DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  String _canonical(Map<String, dynamic> value) => jsonEncode(value);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
