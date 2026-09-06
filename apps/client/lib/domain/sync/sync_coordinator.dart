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
import '../settings/app_settings.dart';
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
  }) : _database = database,
       _credentials = credentials,
       _fireflies = fireflies,
       _gemini = gemini,
       _notion = notion,
       _relay = relay,
       _retryPolicy = retryPolicy,
       _uuid = uuid,
       _notifier = notifier,
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

    try {
      final firefliesKey = await _requiredCredential(
        CredentialKey.firefliesApiKey,
      );
      final cursor = await _database.readCursor('fireflies');
      final from = (cursor ?? DateTime.now().toUtc()).subtract(
        Duration(hours: settings.overlapHours),
      );
      final transcriptRefs = await _fireflies.listTranscripts(
        apiKey: firefliesKey,
        from: from,
      );
      for (final transcript in transcriptRefs) {
        final inserted = await _database.discoverJob(
          id: _uuid.v5(Namespace.url.value, 'fireflies:${transcript.id}'),
          firefliesId: transcript.id,
          title: transcript.title,
          meetingDate: transcript.date,
          firefliesUrl: transcript.url,
        );
        if (inserted) discovered += 1;
      }
      await _database.saveCursor('fireflies', DateTime.now().toUtc());
    } on IntegrationException {
      // Discovery is a recovery path. Durable local work must continue when
      // Fireflies is temporarily unavailable.
    }

    try {
      await refreshActiveSubjects();
    } on IntegrationException {
      if ((await _database.readActiveSubjects()).isEmpty) rethrow;
    }

    final runnable = await _database.claimRunnableJobs(owner: _owner);
    var processed = 0;
    var failed = 0;
    final workerCount = settings.workerCount.clamp(1, 2);
    for (var offset = 0; offset < runnable.length; offset += workerCount) {
      final batch = runnable.skip(offset).take(workerCount);
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
    final subjects = await _notion.queryActiveSubjects(
      token: token,
      dataSourceId: dataSourceId,
    );
    await _database.replaceSubjects(subjects);
    return subjects;
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
    await _database.learnClassificationCorrection(jobId, subject);
    await _database.saveManualSubject(jobId, subject);
    await _claimAndProcess(jobId, forcePublish: true);
  }

  Future<void> retryJob(String jobId) async {
    await _database.setJobStatus(
      jobId,
      SyncJobStatus.queued,
      'Manual retry requested',
    );
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
    await _database.prepareReprocess(jobId, mode);
    await _claimAndProcess(jobId, forcePublish: mode != 'reclassify');
  }

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
      final firefliesKey = job.sourceType == 'manual'
          ? null
          : await _requiredCredential(CredentialKey.firefliesApiKey);
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
        transcript = await _fireflies.fetchTranscript(
          apiKey: firefliesKey!,
          transcriptId: job.firefliesId,
        );
        await _database.saveTranscript(jobId, transcript);
      }

      var subjects = await _database.readActiveSubjects();
      if (subjects.isEmpty) subjects = await refreshActiveSubjects();

      if (relaySession != null && job.sourceType != 'manual') {
        final claim = await _relay.claim(
          baseUrl: settings.relayBaseUrl!,
          token: relaySession,
          firefliesId: job.firefliesId,
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
          'Classifying against active Notion classes',
        );
        final correction = await _database.matchingCorrection(transcript.title);
        final correctedSubject = correction == null
            ? null
            : subjects
                  .where((item) => item.notionId == correction.subjectId)
                  .firstOrNull;
        classification = correctedSubject == null
            ? await _gemini.classify(
                apiKey: geminiKey,
                model: settings.classificationModel,
                transcript: transcript,
                subjects: subjects,
              )
            : ClassificationResult(
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
          completedPartials: await _database.readSummaryPartials(jobId),
          onCheckpoint: (partials) async {
            await _database.saveSummaryPartials(jobId, partials);
            await _renewLease(jobId);
            await _renewRemoteClaim(job!, settings, relaySession);
          },
        );
        await _database.saveSummary(jobId, summary);
      }

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
          await _database.setJobStatus(
            jobId,
            SyncJobStatus.duplicate,
            'Existing Notion summary linked; duplicate prevented',
            terminal: true,
          );
          await _completeRemoteClaim(job, settings, relaySession, existing.id);
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
      await _database.setJobStatus(
        jobId,
        SyncJobStatus.success,
        'Published to Notion',
        terminal: true,
      );
      await _completeRemoteClaim(
        job,
        settings,
        relaySession,
        job.notionPageId!,
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

  Future<String?> _relaySession(AppSettings settings) async {
    final baseUrl = settings.relayBaseUrl;
    final bootstrap = await _credentials.read(CredentialKey.relayDeviceToken);
    if (baseUrl == null || baseUrl.isEmpty || bootstrap?.isNotEmpty != true) {
      return null;
    }
    return _relay.ensureDeviceSession(
      baseUrl: baseUrl,
      bootstrapToken: bootstrap!,
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
    final current = await _database.readJob(jobId);
    final nextAttempt = (current?.attemptCount ?? 0) + 1;
    final retryable = error.retryable && _retryPolicy.shouldRetry(nextAttempt);
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
    if ((await _database.readSettings()).notificationsEnabled) {
      await _notifier.failure(jobId, error.userMessage);
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
