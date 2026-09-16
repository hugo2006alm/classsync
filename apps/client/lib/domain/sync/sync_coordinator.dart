import 'package:uuid/uuid.dart';

import '../../core/database/classsync_database.dart';
import '../../core/integrations/fireflies/fireflies_client.dart';
import '../../core/integrations/gemini/gemini_client.dart';
import '../../core/integrations/integration_exception.dart';
import '../../core/integrations/notion/notion_client.dart';
import '../../core/integrations/relay/relay_client.dart';
import '../../core/security/secure_credential_store.dart';
import '../academic/academic_models.dart';
import '../academic/academic_hub_models.dart';
import 'retry_policy.dart';
import 'sync_coordinator_base.dart' as base;
import 'sync_models.dart';
import 'sync_notifier.dart';

export 'sync_coordinator_base.dart' show SyncRunResult;

/// Adds lifecycle consistency on top of the core sync pipeline.
///
/// Internal `duplicate` is kept as an idempotency/reconciliation checkpoint for
/// backwards compatibility, but the UI presents it as a completed canonical
/// summary. This layer makes reconciled jobs editable and keeps derived tasks
/// aligned with user actions.
class SyncCoordinator extends base.SyncCoordinator {
  SyncCoordinator({
    required ClassSyncDatabase database,
    required SecureCredentialStore credentials,
    required FirefliesClient fireflies,
    required GeminiClient gemini,
    required NotionClient notion,
    required RelayClient relay,
    RetryPolicy retryPolicy = const RetryPolicy(),
    Uuid uuid = const Uuid(),
    SyncNotifier notifier = const NoopSyncNotifier(),
    void Function(ModelRetryPrompt prompt)? onModelRetrySuggested,
  }) : _database = database,
       super(
         database: database,
         credentials: credentials,
         fireflies: fireflies,
         gemini: gemini,
         notion: notion,
         relay: relay,
         retryPolicy: retryPolicy,
         uuid: uuid,
         notifier: notifier,
         onModelRetrySuggested: onModelRetrySuggested,
       );

  final ClassSyncDatabase _database;

  @override
  Future<void> confirmSubject(String jobId, AcademicSubject subject) async {
    await super.confirmSubject(jobId, subject);
    final current = await _database.readJob(jobId);
    if (current?.subjectId == subject.notionId) {
      await _retagLectureTasks(jobId, subject);
    }
  }

  @override
  Future<void> discardJob(String jobId) async {
    await _database.transaction(() async {
      final job = await _database.readJob(jobId);
      if (job == null) return;
      final now = DateTime.now().toUtc();
      final busy =
          job.status.isProcessing ||
          (job.leaseOwner != null &&
              job.leaseExpiresAt?.isAfter(now) == true);
      if (busy) {
        throw const IntegrationException(
          integration: 'ClassSync',
          code: 'job_busy',
          userMessage:
              'This transcript is being processed right now. Try discarding it when the current step finishes.',
          retryable: true,
        );
      }

      await _database.setJobStatus(
        jobId,
        SyncJobStatus.ignored,
        job.notionPageId == null
            ? 'Transcript discarded by user'
            : 'Sync record discarded; published summary retained',
        terminal: true,
      );
      await _database.clearTranscriptPayload(jobId);
      await _database.saveSummaryPartials(jobId, const []);
      await _deleteLectureTasks(jobId);
    });
  }

  Future<void> _retagLectureTasks(
    String jobId,
    AcademicSubject subject,
  ) async {
    final current = await _database.readAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
    );
    var changed = false;
    final updated = current.map((record) {
      if (record.payload['sourceLectureId'] != jobId) return record;
      changed = true;
      return record.copyWith(
        subjectId: subject.notionId,
        payload: {
          ...record.payload,
          'subjectId': subject.notionId,
          'subjectName': subject.name,
        },
      );
    }).toList();
    if (!changed) return;
    await _database.replaceAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
      records: updated,
    );
  }

  Future<void> _deleteLectureTasks(String jobId) async {
    final current = await _database.readAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
    );
    final retained = current
        .where((record) => record.payload['sourceLectureId'] != jobId)
        .toList();
    if (retained.length == current.length) return;
    await _database.replaceAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
      records: retained,
    );
  }
}
