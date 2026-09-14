import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/database/classsync_database.dart';
import '../../core/integrations/fireflies/fireflies_client.dart';
import '../../core/integrations/gemini/gemini_client.dart';
import '../../core/integrations/integration_exception.dart';
import '../../core/integrations/notion/notion_client.dart';
import '../../core/integrations/relay/relay_client.dart';
import '../../core/logging/redactor.dart';
import '../../core/security/secure_credential_store.dart';
import '../academic/academic_models.dart';
import '../academic/academic_hub_models.dart';
import '../settings/app_settings.dart';
import '../settings/fireflies_connection.dart';
import 'retry_policy.dart';
import 'classification_policy.dart';
import 'sync_models.dart';
import 'sync_notifier.dart';

class SyncRunResult {
  const SyncRunResult({
    required this.discovered,
    required this.processed,
    required this.failed,
    required this.relayAvailable,
  });

  final int discovered;
  final int processed;
  final int failed;
  final bool relayAvailable;
}

class SyncCoordinator {
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
       _credentials = credentials,
       _fireflies = fireflies,
       _gemini = gemini,
       _notion = notion,
       _relay = relay,
       _retryPolicy = retryPolicy,
       _uuid = uuid,
       _notifier = notifier,
       _onModelRetrySuggested = onModelRetrySuggested,
       _owner = uuid.v4();

  final ClassSyncDatabase _database;
  final SecureCredentialStore _credentials;
  final FirefliesClient _fireflies;
  final GeminiClient _gemini;
  final NotionClient _notion;
  final RelayClient _relay;
  final RetryPolicy _retryPolicy;
  final Uuid _uuid;
  final SyncNotifier _notifier;
  final void Function(ModelRetryPrompt prompt)? _onModelRetrySuggested;
  final String _owner;

  Future<SyncRunResult> run(SyncReason reason) async {
    await _database.saveCursor('sync_run_started', DateTime.now().toUtc());
    final settings = await _database.readSettings();
    if (!settings.setupComplete) {
      throw const IntegrationException(
        integration: 'ClassSync',
        code: 'setup_incomplete',
        userMessage: 'Finish setup before syncing.',
        retryable: false,
      );
    }
    var discovered = 0;
    var relayAvailable = true;

    final relayEvents = <RelayEvent>[];
    String? relayToken;
    try {
      relayToken = await _relaySession(settings);
    } on IntegrationException {
      relayAvailable = false;
    }
    if (settings.relayBaseUrl != null && relayToken?.isNotEmpty == true) {
      try {
        relayEvents.addAll(
          await _relay.pendingEvents(
            baseUrl: settings.relayBaseUrl!,
            token: relayToken!,
          ),
        );
      } on IntegrationException {
        relayAvailable = false;
      }
    }

    for (final event in relayEvents) {
      final inserted = await _database.discoverJob(
        id: _uuid.v5(
          Namespace.url.value,
          'fireflies:${event.firefliesTranscriptId}',
        ),
        firefliesId: event.firefliesTranscriptId,
        title: 'Pending Fireflies transcript',
        meetingDate: event.receivedAt,
      );
      if (inserted) discovered += 1;
      try {
        await _relay.acknowledge(
          baseUrl: settings.relayBaseUrl!,
          token: relayToken!,
          eventId: event.id,
        );
      } on IntegrationException {
        relayAvailable = false;
      }
    }

    final firefliesConnections = await _credentials.readFirefliesConnections();
    for (final connection in firefliesConnections) {
      try {
        final cursorKey = 'fireflies:${connection.id}';
        final cursor =
            await _database.readCursor(cursorKey) ??
            (connection.id == FirefliesConnection.legacyId
                ? await _database.readCursor('fireflies')
                : null);
        final from = (cursor ?? DateTime.now().toUtc()).subtract(
          Duration(hours: settings.overlapHours),
        );
        final transcriptRefs = await _fireflies.listTranscripts(
          apiKey: connection.apiKey,
          from: from,
        );
        for (final transcript in transcriptRefs) {
          final inserted = await _database.discoverJob(
            id: _uuid.v5(Namespace.url.value, 'fireflies:${transcript.id}'),
            firefliesId: transcript.id,
            title: transcript.title,
            meetingDate: transcript.date,
            firefliesUrl: transcript.url,
            sourceType: 'fireflies:${connection.id}',
          );
          if (inserted) discovered += 1;
        }
        await _database.saveCursor(cursorKey, DateTime.now().toUtc());
      } on IntegrationException {
        // One unavailable account cannot block other sources or durable work.
      }
    }

    try {
      await refreshActiveSubjects();
    } on IntegrationException {
      if ((await _database.readActiveSubjects()).isEmpty) rethrow;
    }

    var processed = 0;
    var failed = 0;
    final workerCount = settings.workerCount.clamp(1, 2);
    for (var offset = 0; offset < 50; offset += workerCount) {
      final batch = await _database.claimRunnableJobs(
        owner: _owner,
        limit: workerCount,
      );
      if (batch.isEmpty) break;
      final results = await Future.wait(
        batch.map((job) => _processJob(job.id, settings)),
      );
      for (final succeeded in results) {
        if (succeeded) {
          processed += 1;
        } else {
          failed += 1;
        }
      }
    }
    await _database.pruneDiagnostics(
      Duration(days: settings.diagnosticsRetentionDays),
    );
    await _database.pruneAbandonedPayloads(
      Duration(days: settings.diagnosticsRetentionDays),
    );
    await _database.saveCursor('sync_run_completed', DateTime.now().toUtc());
    return SyncRunResult(
      discovered: discovered,
      processed: processed,
      failed: failed,
      relayAvailable: relayAvailable,
    );
  }

  Future<List<AcademicSubject>> refreshActiveSubjects() async {
    final settings = await _database.readSettings();
    final dataSourceId = settings.notionSubjectsDataSourceId;
    if (dataSourceId == null || dataSourceId.isEmpty) {
      throw const IntegrationException(
        integration: 'Notion',
        code: 'subjects_mapping_missing',
        userMessage: 'Select the Lista de Cadeiras data source in Settings.',
        retryable: false,
      );
    }
    final token = await _requiredCredential(CredentialKey.notionToken);
    final subjects = await _notion.querySubjects(
      token: token,
      dataSourceId: dataSourceId,
    );
    await _database.replaceSubjects(subjects);
    return subjects.where((subject) => subject.isActive).toList();
  }

  Future<String> importTranscript({
    required String title,
    required String transcriptText,
    DateTime? lectureDate,
  }) async {
    final trimmed = transcriptText.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Transcript cannot be empty.');
    }
    if (trimmed.length > GeminiClient.maxTranscriptCharacters) {
      throw FormatException(
        'Transcript is too large (${trimmed.length} characters). The safe '
        'limit is ${GeminiClient.maxTranscriptCharacters}. Split it first.',
      );
    }
    final id = _uuid.v4();
    final sourceId = 'manual:$id';
    final date = lectureDate ?? DateTime.now();
    await _database.discoverJob(
      id: id,
      firefliesId: sourceId,
      title: title.trim().isEmpty ? 'Manual lecture import' : title.trim(),
      meetingDate: date,
      sourceType: 'manual',
    );
    final transcript = LectureTranscript(
      firefliesId: sourceId,
      title: title.trim().isEmpty ? 'Manual lecture import' : title.trim(),
      date: date,
      sentences: [TranscriptSentence(text: trimmed)],
    );
    await _database.saveTranscript(id, transcript);
    await _database.setJobStatus(
      id,
      SyncJobStatus.queued,
      'Manual transcript queued',
    );
    if (await _database.claimJob(id: id, owner: _owner)) {
      await _processJob(id, await _database.readSettings());
    }
    return id;
  }

  Future<void> confirmSubject(String jobId, AcademicSubject subject) async {
    if (!await _prepareIfIdle(jobId, () async {
      await _database.learnClassificationCorrection(jobId, subject);
      await _database.prepareManualSubject(jobId, subject);
    })) {
      return;
    }
    await _claimAndProcess(jobId, forcePublish: true);
  }

  Future<void> retryJob(String jobId) async {
    if (!await _prepareIfIdle(
      jobId,
      () => _database.setJobStatus(
        jobId,
        SyncJobStatus.queued,
        'Manual retry requested',
      ),
    )) {
      return;
    }
    await _claimAndProcess(jobId);
  }

  Future<void> reclassifyJob(String jobId) => _reprocess(jobId, 'reclassify');

  Future<void> regenerateSummary(String jobId) =>
      _reprocess(jobId, 'regenerate');

  Future<void> republishJob(String jobId) => _reprocess(jobId, 'republish');

  Future<void> _reprocess(String jobId, String mode) async {
    final job = await _database.readJob(jobId);
    if (job == null) return;
    if (job.sourceType == 'manual' && job.transcriptJson == null) {
      throw const IntegrationException(
        integration: 'ClassSync',
        code: 'manual_transcript_removed',
        userMessage:
            'This manual transcript is no longer stored. Import it again to reprocess.',
        retryable: false,
      );
    }
    if (!await _prepareIfIdle(
      jobId,
      () => _database.prepareReprocess(jobId, mode),
    )) {
      return;
    }
    await _claimAndProcess(jobId, forcePublish: mode != 'reclassify');
  }

  Future<bool> _prepareIfIdle(String jobId, Future<void> Function() prepare) =>
      _database.transaction(() async {
        final job = await _database.readJob(jobId);
        if (job == null ||
            (job.leaseOwner != null &&
                job.leaseExpiresAt?.isAfter(DateTime.now().toUtc()) == true)) {
          return false;
        }
        await prepare();
        return true;
      });

  Future<bool> _claimAndProcess(
    String jobId, {
    bool forcePublish = false,
  }) async {
    if (!await _database.claimJob(id: jobId, owner: _owner)) return false;
    return _processJob(
      jobId,
      await _database.readSettings(),
      forcePublish: forcePublish,
    );
  }

  Future<bool> _processJob(
    String jobId,
    AppSettings settings, {
    bool forcePublish = false,
  }) async {
    try {
      var job = await _database.readJob(jobId);
      if (job == null) return false;
      if (job.leaseOwner != _owner) return false;
      final geminiKey = await _requiredCredential(CredentialKey.geminiApiKey);
      final notionToken = await _requiredCredential(CredentialKey.notionToken);
      final relaySession = job.sourceType == 'manual'
          ? null
          : await _relaySession(settings);

      LectureTranscript transcript;
      if (job.transcriptJson case final stored?) {
        transcript = LectureTranscript.fromStoredJson(stored);
      } else {
        await _renewLease(jobId);
        await _database.setJobStatus(
          jobId,
          SyncJobStatus.fetchingTranscript,
          'Fetching transcript from Fireflies',
        );
        transcript = await _fetchFirefliesTranscript(job);
        await _database.saveTranscript(jobId, transcript);
      }

      var subjects = await _database.readActiveSubjects();
      if (subjects.isEmpty) subjects = await refreshActiveSubjects();

      if (relaySession != null && job.sourceType != 'manual') {
        final claim = await _relay.claim(
          baseUrl: settings.relayBaseUrl!,
          token: relaySession,
          firefliesId: job.firefliesId,
          reprocessPageId: job.reprocessMode == 'replace'
              ? job.notionPageId
              : null,
        );
        if (claim.completed && claim.notionPageId != null) {
          await _database.saveNotionPage(jobId, claim.notionPageId!, null);
          await _database.setJobStatus(
            jobId,
            SyncJobStatus.duplicate,
            'Another device already published this lecture',
            terminal: true,
          );
          return true;
        }
        if (!claim.acquired) {
          throw const IntegrationException(
            integration: 'ClassSync Relay',
            code: 'claim_busy',
            userMessage: 'Another ClassSync device is processing this lecture.',
            retryable: true,
          );
        }
      }

      ClassificationResult? classification;
      if (job.classificationCandidatesJson case final encoded?) {
        classification = ClassificationResult.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
      }
      AcademicSubject? subject;
      if (job.subjectId case final selectedId?) {
        subject = subjects
            .where((item) => item.notionId == selectedId)
            .firstOrNull;
      }
      if (classification == null && subject == null) {
        await _renewLease(jobId);
        await _database.setJobStatus(
          jobId,
          SyncJobStatus.classifying,
          settings.useAiClassification
              ? 'Classifying against active Notion classes'
              : 'Preparing manual class selection',
        );
        final correction = await _database.matchingCorrection(transcript.title);
        final correctedSubject = correction == null
            ? null
            : subjects
                  .where((item) => item.notionId == correction.subjectId)
                  .firstOrNull;
        if (correctedSubject == null) {
          final context = await _timetableContext(transcript);
          if (settings.useAiClassification) {
            final semantic = await _gemini.classify(
              apiKey: geminiKey,
              model: settings.classificationModel,
              transcript: transcript,
              subjects: subjects,
              timetableContext: context,
            );
            classification = TimetableMatcher.combine(
              semantic,
              context,
              subjects,
            );
          } else {
            classification = _manualClassification(subjects, context);
          }
        } else {
          classification = ClassificationResult(
            decision: ClassificationDecision.match,
            subjectId: correctedSubject.notionId,
            subjectName: correctedSubject.name,
            confidence: 1,
            candidates: [
              ClassificationCandidate(
                subjectId: correctedSubject.notionId,
                subjectName: correctedSubject.name,
                confidence: 1,
              ),
            ],
            reasoningSummary: const ['Local correction matched title'],
          );
        }
        await _database.saveClassification(jobId, classification);
        if (classification.decision == ClassificationDecision.notALecture) {
          await _database.setJobStatus(
            jobId,
            SyncJobStatus.ignored,
            'Gemini classified recording as not a lecture',
            terminal: true,
          );
          if (settings.cleanCompletedPayloads && !settings.keepTranscripts) {
            await _database.clearTranscriptPayload(jobId);
          }
          return true;
        }
        subject = subjects
            .where((item) => item.notionId == classification!.subjectId)
            .firstOrNull;
      }

      if (subject == null) {
        await _database.setJobStatus(
          jobId,
          SyncJobStatus.needsReview,
          'No valid class could be selected',
        );
        if (settings.notificationsEnabled) await _notifier.needsReview(jobId);
        return true;
      }

      job = await _database.readJob(jobId);
      if (job == null) return false;
      LectureSummary summary;
      if (job.summaryJson case final encoded?) {
        summary = LectureSummary.decode(encoded);
      } else {
        await _renewLease(jobId);
        await _renewRemoteClaim(job, settings, relaySession);
        await _database.setJobStatus(
          jobId,
          SyncJobStatus.summarizing,
          'Generating structured study summary',
        );
        summary = await _gemini.summarizeResumable(
          apiKey: geminiKey,
          model: settings.summaryModel,
          transcript: transcript,
          subject: subject,
          settings: settings,
          courseContext: (await _database.readAcademicRecords())
              .where(
                (record) =>
                    record.subjectId == subject!.notionId &&
                    (record.kind == AcademicRecordKind.fucProfile ||
                        record.kind == AcademicRecordKind.lessonSummary),
              )
              .take(8)
              .toList(),
          completedPartials: await _database.readSummaryPartials(jobId),
          onCheckpoint: (partials) async {
            await _database.saveSummaryPartials(jobId, partials);
            await _renewLease(jobId);
            await _renewRemoteClaim(job!, settings, relaySession);
          },
        );
        await _database.saveSummary(jobId, summary);
      }
      await _saveLectureTasks(job, subject, summary);

      final confidence =
          classification?.confidence ?? job.classificationConfidence ?? 1.0;
      final policyAction = classification == null
          ? ClassificationAction.autoPublish
          : ClassificationPolicy(
              autoPublishThreshold: settings.autoClassifyThreshold,
              reviewThreshold: settings.reviewThreshold,
            ).evaluate(classification);
      final autoPublish =
          forcePublish || policyAction == ClassificationAction.autoPublish;
      if (!autoPublish) {
        await _database.setJobStatus(
          jobId,
          SyncJobStatus.needsReview,
          confidence < settings.reviewThreshold
              ? 'Classification below review threshold'
              : 'Class confirmation required before publishing',
        );
        if (settings.notificationsEnabled) await _notifier.needsReview(jobId);
        return true;
      }

      final summariesId = settings.notionSummariesDataSourceId;
      if (summariesId == null || summariesId.isEmpty) {
        throw const IntegrationException(
          integration: 'Notion',
          code: 'summaries_mapping_missing',
          userMessage:
              'Select the Histórico de Resumos data source in Settings.',
          retryable: false,
        );
      }
      await _database.setJobStatus(
        jobId,
        SyncJobStatus.publishing,
        'Publishing to Notion',
      );
      job = await _database.readJob(jobId);
      if (job == null) return false;
      await _renewLease(jobId);
      await _renewRemoteClaim(job, settings, relaySession);
      if (job.notionPageId == null && settings.notionMetadataEnabled) {
        final existing = await _notion.findSummaryByFirefliesId(
          token: notionToken,
          dataSourceId: summariesId,
          firefliesId: job.firefliesId,
        );
        if (existing != null) {
          await _database.saveNotionPage(jobId, existing.id, existing.url);
          await _notion.ensureSummaryContent(
            token: notionToken,
            pageId: existing.id,
            summary: summary,
            lectureDate: transcript.date,
            firefliesUrl: transcript.firefliesUrl,
          );
          await _completeRemoteClaim(job, settings, relaySession, existing.id);
          await _database.setJobStatus(
            jobId,
            SyncJobStatus.duplicate,
            'Existing Notion summary linked; duplicate prevented',
            terminal: true,
          );
          if (settings.cleanCompletedPayloads && !settings.keepTranscripts) {
            await _database.clearTranscriptPayload(jobId);
          }
          return true;
        }
      }
      if (job.notionPageId == null) {
        final page = await _notion.createSummaryPage(
          token: notionToken,
          dataSourceId: summariesId,
          firefliesId: job.firefliesId,
          lectureDate: transcript.date,
          subjectId: subject.notionId,
          summary: summary,
          includeMetadata: settings.notionMetadataEnabled,
        );
        await _database.saveNotionPage(jobId, page.id, page.url);
        job = await _database.readJob(jobId);
        if (job == null) return false;
      }
      if (job.reprocessMode == 'replace') {
        await _notion.replaceSummaryPage(
          token: notionToken,
          pageId: job.notionPageId!,
          firefliesId: job.firefliesId,
          lectureDate: transcript.date,
          subjectId: subject.notionId,
          summary: summary,
          firefliesUrl: transcript.firefliesUrl,
          includeMetadata: settings.notionMetadataEnabled,
        );
        await _database.finishReprocess(jobId);
      } else {
        await _notion.ensureSummaryContent(
          token: notionToken,
          pageId: job.notionPageId!,
          summary: summary,
          lectureDate: transcript.date,
          firefliesUrl: transcript.firefliesUrl,
        );
      }
      await _completeRemoteClaim(
        job,
        settings,
        relaySession,
        job.notionPageId!,
      );
      await _database.setJobStatus(
        jobId,
        SyncJobStatus.success,
        'Published to Notion',
        terminal: true,
      );
      if (settings.notificationsEnabled) {
        await _notifier.success(jobId, subject.name);
      }
      if (settings.cleanCompletedPayloads && !settings.keepTranscripts) {
        await _database.clearTranscriptPayload(jobId);
      }
      return true;
    } on IntegrationException catch (error) {
      await _recordFailure(jobId, error);
      return false;
    } catch (error) {
      await _recordFailure(
        jobId,
        IntegrationException(
          integration: 'ClassSync',
          code: 'unexpected',
          userMessage: SecretRedactor.redact(error.toString()),
          retryable: true,
        ),
      );
      return false;
    }
  }

  Future<void> _saveLectureTasks(
    SyncJob job,
    AcademicSubject subject,
    LectureSummary summary,
  ) => _database.transaction(() async {
    final current = await _database.readAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
    );
    final retained = current
        .where((record) => record.payload['sourceLectureId'] != job.id)
        .toList();
    final generated = <AcademicRecord>[];
    final seen = <String>{};
    for (final candidate in summary.actionItems) {
      final normalized = SubjectMapper.normalize(candidate.title);
      final due = candidate.dueAt?.toUtc().toIso8601String() ?? 'undated';
      if (normalized.isEmpty || !seen.add('$normalized:$due')) continue;
      final id = _uuid.v5(
        Namespace.url.value,
        'classsync:task:${job.firefliesId}:$normalized:$due',
      );
      final task = LectureTask(
        id: id,
        title: candidate.title.trim(),
        description: candidate.description.trim(),
        sourceLectureId: job.id,
        sourceLectureTitle: job.title,
        subjectId: subject.notionId,
        subjectName: subject.name,
        dueAt: candidate.dueAt,
        confidence: candidate.confidence,
        supportingSegment: candidate.supportingSegment,
        timestampSeconds: candidate.timestampSeconds,
        status: LectureTaskStatus.pending,
      );
      generated.add(
        AcademicRecord(
          key: AcademicRecord.keyFor(
            AcademicSource.manual,
            AcademicRecordKind.lectureTask,
            id,
          ),
          source: AcademicSource.manual,
          kind: AcademicRecordKind.lectureTask,
          externalId: id,
          title: task.title,
          subjectId: task.subjectId,
          startsAt: task.dueAt,
          payload: task.toJson(),
          syncedAt: DateTime.now().toUtc(),
        ),
      );
    }
    await _database.replaceAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
      records: [...retained, ...generated],
    );
  });

  Future<TimetableContext> _timetableContext(
    LectureTranscript transcript,
  ) async {
    final timetableRecords = await _database.readAcademicRecords(
      kind: AcademicRecordKind.timetable,
    );
    final slots = <TimetableSlot>[];
    for (final record in timetableRecords) {
      try {
        slots.add(TimetableSlot.fromJson(record.payload));
      } on FormatException {
        // A stale malformed cache row cannot block lecture processing.
      }
    }
    final lastSentenceSecond = transcript.sentences
        .map((item) => item.endTimeSeconds ?? item.startTimeSeconds ?? 0)
        .fold<double>(0, (maximum, value) => value > maximum ? value : maximum);
    return TimetableMatcher.match(
      meetingStart: transcript.date,
      meetingEnd: transcript.date.add(
        Duration(
          seconds: lastSentenceSecond > 0 ? lastSentenceSecond.ceil() : 5400,
        ),
      ),
      slots: slots,
    );
  }

  ClassificationResult _manualClassification(
    List<AcademicSubject> subjects,
    TimetableContext context,
  ) {
    final ordered = [...subjects]
      ..sort((left, right) {
        final leftMatches = context.subjectIds.contains(left.notionId);
        final rightMatches = context.subjectIds.contains(right.notionId);
        if (leftMatches != rightMatches) return leftMatches ? -1 : 1;
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
    return ClassificationResult(
      decision: ClassificationDecision.uncertain,
      confidence: 0,
      candidates: ordered
          .map(
            (subject) => ClassificationCandidate(
              subjectId: subject.notionId,
              subjectName: subject.name,
              confidence: context.subjectIds.contains(subject.notionId)
                  ? 0.65
                  : 0,
            ),
          )
          .toList(),
      reasoningSummary: [
        'AI class identification is disabled; manual selection required',
        context.explanation,
      ],
    );
  }

  Future<void> _renewLease(String jobId) async {
    if (!await _database.renewLease(jobId, _owner)) {
      throw const IntegrationException(
        integration: 'ClassSync',
        code: 'lease_lost',
        userMessage:
            'This sync job was taken over by another ClassSync worker.',
        retryable: true,
      );
    }
  }

  Future<LectureTranscript> _fetchFirefliesTranscript(SyncJob job) async {
    final connections = await _credentials.readFirefliesConnections();
    if (connections.isEmpty) {
      throw const IntegrationException(
        integration: 'Fireflies',
        code: 'not_configured',
        userMessage: 'Add at least one Fireflies connection in Settings.',
        retryable: false,
      );
    }
    final sourceId = job.sourceType.startsWith('fireflies:')
        ? job.sourceType.substring('fireflies:'.length)
        : null;
    final exact = connections.where((item) => item.id == sourceId).toList();
    final ordered = exact.isNotEmpty ? exact : connections;
    IntegrationException? lastFailure;
    IntegrationException? retryableFailure;
    for (final connection in ordered) {
      try {
        final transcript = await _fireflies.fetchTranscript(
          apiKey: connection.apiKey,
          transcriptId: job.firefliesId,
        );
        final sourceType = 'fireflies:${connection.id}';
        if (job.sourceType != sourceType) {
          await _database.setJobSourceType(job.id, sourceType);
        }
        return transcript;
      } on IntegrationException catch (failure) {
        lastFailure = failure;
        if (failure.retryable) retryableFailure ??= failure;
      }
    }
    throw retryableFailure ??
        lastFailure ??
        const IntegrationException(
          integration: 'Fireflies',
          code: 'transcript_unavailable',
          userMessage:
              'No named Fireflies connection can access this transcript.',
          retryable: false,
        );
  }

  Future<String?> _relaySession(AppSettings settings) async {
    final baseUrl = settings.relayBaseUrl;
    final bootstrap = await _credentials.read(CredentialKey.relayDeviceToken);
    final account = await _credentials.read(
      CredentialKey.syncAccountAuthSecret,
    );
    final device = await _credentials.read(CredentialKey.relayDeviceCredential);
    if (baseUrl == null ||
        baseUrl.isEmpty ||
        (bootstrap?.isNotEmpty != true &&
            account?.isNotEmpty != true &&
            device?.isNotEmpty != true)) {
      return null;
    }
    return _relay.ensureDeviceSession(
      baseUrl: baseUrl,
      bootstrapToken: bootstrap ?? '',
      credentials: _credentials,
    );
  }

  Future<void> _renewRemoteClaim(
    SyncJob job,
    AppSettings settings,
    String? session,
  ) async {
    if (session == null || job.sourceType == 'manual') return;
    final claim = await _relay.claim(
      baseUrl: settings.relayBaseUrl!,
      token: session,
      firefliesId: job.firefliesId,
      reprocessPageId: job.reprocessMode == 'replace' ? job.notionPageId : null,
    );
    if (!claim.acquired) {
      throw const IntegrationException(
        integration: 'ClassSync Relay',
        code: 'claim_lost',
        userMessage: 'Another ClassSync device took over this lecture.',
        retryable: true,
      );
    }
  }

  Future<void> _completeRemoteClaim(
    SyncJob job,
    AppSettings settings,
    String? session,
    String notionPageId,
  ) async {
    if (session == null || job.sourceType == 'manual') return;
    await _relay.completeClaim(
      baseUrl: settings.relayBaseUrl!,
      token: session,
      firefliesId: job.firefliesId,
      notionPageId: notionPageId,
    );
  }

  Future<void> _recordFailure(String jobId, IntegrationException error) async {
    ModelRetryPrompt? modelPrompt;
    final recorded = await _database.transaction(() async {
      final current = await _database.readJob(jobId);
      if (current == null || current.leaseOwner != _owner) return false;
      final nextAttempt = current.attemptCount + 1;
      final retryable =
          error.retryable && _retryPolicy.shouldRetry(nextAttempt);
      final delay =
          error.retryAfter ??
          _retryPolicy.delayFor(nextAttempt, jitterSeed: jobId.hashCode);
      await _database.markFailure(
        id: jobId,
        errorType: '${error.integration}.${error.code}',
        message: SecretRedactor.redact(error.userMessage),
        retryable: retryable,
        nextRetryAt: retryable ? DateTime.now().toUtc().add(delay) : null,
      );
      final operation = switch (current.status) {
        SyncJobStatus.classifying => GeminiOperation.classification,
        SyncJobStatus.summarizing => GeminiOperation.summary,
        _ => null,
      };
      if (error.integration == 'Gemini' &&
          operation != null &&
          nextAttempt >= 3 &&
          (nextAttempt == 3 || nextAttempt == 6 || !retryable)) {
        final settings = await _database.readSettings();
        modelPrompt = ModelRetryPrompt(
          jobId: jobId,
          operation: operation,
          currentModel: operation == GeminiOperation.classification
              ? settings.classificationModel
              : settings.summaryModel,
          attemptCount: nextAttempt,
          message: SecretRedactor.redact(error.userMessage),
          retryScheduled: retryable,
        );
      }
      return true;
    });
    if (recorded && modelPrompt != null) {
      _onModelRetrySuggested?.call(modelPrompt!);
    }
    if (recorded && (await _database.readSettings()).notificationsEnabled) {
      await _notifier.failure(jobId, SecretRedactor.redact(error.userMessage));
    }
  }

  Future<String> _requiredCredential(CredentialKey key) async {
    final value = await _credentials.read(key);
    if (value == null || value.isEmpty) {
      throw IntegrationException(
        integration: switch (key) {
          CredentialKey.firefliesApiKey => 'Fireflies',
          CredentialKey.geminiApiKey => 'Gemini',
          CredentialKey.notionToken => 'Notion',
          CredentialKey.relayDeviceToken => 'ClassSync Relay',
          CredentialKey.relayDeviceCredential => 'ClassSync Relay',
          _ => 'ClassSync account',
        },
        code: 'not_configured',
        userMessage: 'Required integration is not configured.',
        retryable: false,
      );
    }
    return value;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
