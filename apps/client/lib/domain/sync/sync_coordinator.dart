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
import '../settings/app_settings.dart';
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
  // Explicit forwarding is intentional because Gemini is wrapped before being
  // passed to the base coordinator and this layer keeps its own database handle.
  // ignore: use_super_parameters
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
         gemini: _AuthoritativeSummaryGeminiClient(gemini),
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
    final before = await _database.readJob(jobId);
    final reconfirmingPublishedSubject =
        before?.subjectId == subject.notionId &&
        (before?.summaryJson != null || before?.notionPageId != null);

    if (reconfirmingPublishedSubject) {
      await _database.learnClassificationCorrection(jobId, subject);
      await super.regenerateSummary(jobId);
    } else {
      await super.confirmSubject(jobId, subject);
    }

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
          (job.leaseOwner != null && job.leaseExpiresAt?.isAfter(now) == true);
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

  Future<void> _retagLectureTasks(String jobId, AcademicSubject subject) async {
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

/// The subject selected by ClassSync is authoritative for note generation.
///
/// This matters after a user fixes a classification: the transcript itself can
/// still contain a misleading course label, and a summarizer that faithfully
/// repeats it can leave the regenerated summary attached to the right Notion
/// relation while describing the wrong course in prose. The wrapper keeps the
/// original classifier untouched and strengthens only the summarization input.
class _AuthoritativeSummaryGeminiClient extends GeminiClient {
  _AuthoritativeSummaryGeminiClient(this._delegate);

  static const _identityHint =
      ' [ClassSync authoritative course selection: keep this exact course '
      'identity for the lecture; if the transcript or meeting metadata names '
      'another course, do not present that conflicting name as the course this '
      'lecture belongs to]';

  final GeminiClient _delegate;

  @override
  Future<ClassificationResult> classify({
    required String apiKey,
    required String model,
    required LectureTranscript transcript,
    required List<AcademicSubject> subjects,
    TimetableContext? timetableContext,
  }) => _delegate.classify(
    apiKey: apiKey,
    model: model,
    transcript: transcript,
    subjects: subjects,
    timetableContext: timetableContext,
  );

  @override
  Future<LectureSummary> summarizeResumable({
    required String apiKey,
    required String model,
    required LectureTranscript transcript,
    required AcademicSubject subject,
    required AppSettings settings,
    List<Map<String, dynamic>> completedPartials = const [],
    Future<void> Function(List<Map<String, dynamic>> partials)? onCheckpoint,
    List<AcademicRecord> courseContext = const [],
  }) async {
    final authoritativeSubject = AcademicSubject(
      notionId: subject.notionId,
      name: '${subject.name}$_identityHint',
      year: subject.year,
      semester: subject.semester,
      status: subject.status,
      lastSyncedAt: subject.lastSyncedAt,
      notionUrl: subject.notionUrl,
      aliases: subject.aliases,
      professors: subject.professors,
      scheduleHints: subject.scheduleHints,
      summaryCount: subject.summaryCount,
      latestSummaryTitle: subject.latestSummaryTitle,
    );
    final summary = await _delegate.summarizeResumable(
      apiKey: apiKey,
      model: model,
      transcript: transcript,
      subject: authoritativeSubject,
      settings: settings,
      completedPartials: completedPartials,
      onCheckpoint: onCheckpoint,
      courseContext: courseContext,
    );
    return _cleanSummaryIdentity(summary, subject.name);
  }

  LectureSummary _cleanSummaryIdentity(
    LectureSummary summary,
    String subjectName,
  ) {
    String clean(String value) => value
        .replaceAll('$subjectName$_identityHint', subjectName)
        .replaceAll(_identityHint, '');
    List<String> cleanList(List<String> values) =>
        values.map(clean).toList(growable: false);

    return LectureSummary(
      title: clean(summary.title),
      context: clean(summary.context),
      objectives: cleanList(summary.objectives),
      sections: summary.sections
          .map(
            (section) => LectureSummarySection(
              title: clean(section.title),
              content: clean(section.content),
              keyPoints: cleanList(section.keyPoints),
              examples: cleanList(section.examples),
              code: cleanList(section.code),
              formulas: cleanList(section.formulas),
            ),
          )
          .toList(growable: false),
      examHints: cleanList(summary.examHints),
      teacherEmphasis: cleanList(summary.teacherEmphasis),
      importantDetails: cleanList(summary.importantDetails),
      questionsAndAnswers: cleanList(summary.questionsAndAnswers),
      assignmentsAndDeadlines: cleanList(summary.assignmentsAndDeadlines),
      actionItems: summary.actionItems
          .map(
            (item) => LectureActionCandidate(
              title: clean(item.title),
              description: clean(item.description),
              dueAt: item.dueAt,
              confidence: item.confidence,
              supportingSegment: clean(item.supportingSegment),
              timestampSeconds: item.timestampSeconds,
            ),
          )
          .toList(growable: false),
      uncertainties: cleanList(summary.uncertainties),
      conclusions: cleanList(summary.conclusions),
      tags: cleanList(summary.tags),
    );
  }
}
