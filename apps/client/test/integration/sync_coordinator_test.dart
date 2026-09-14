import 'dart:convert';

import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/integrations/fireflies/fireflies_client.dart';
import 'package:classsync/core/integrations/gemini/gemini_client.dart';
import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/notion/notion_client.dart';
import 'package:classsync/core/integrations/relay/relay_client.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:classsync/domain/settings/app_settings.dart';
import 'package:classsync/domain/settings/fireflies_connection.dart';
import 'package:classsync/domain/sync/sync_coordinator.dart';
import 'package:classsync/domain/sync/sync_models.dart';
import 'package:classsync/domain/sync/sync_notifier.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClassSyncDatabase database;
  late _FakeFireflies fireflies;
  late _FakeGemini gemini;
  late _FakeNotion notion;
  late _FakeRelay relay;
  late _FakeNotifier notifier;
  late SyncCoordinator coordinator;

  setUp(() async {
    database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
    await database.saveSettings(
      AppSettings.defaults.copyWith(
        setupComplete: true,
        notionSubjectsDataSourceId: 'subjects-db',
        notionSummariesDataSourceId: 'summaries-db',
        relayBaseUrl: 'https://relay.test',
      ),
    );
    fireflies = _FakeFireflies();
    gemini = _FakeGemini();
    notion = _FakeNotion();
    relay = _FakeRelay();
    notifier = _FakeNotifier();
    coordinator = SyncCoordinator(
      database: database,
      credentials: _FakeCredentials(),
      fireflies: fireflies,
      gemini: gemini,
      notion: notion,
      relay: relay,
      notifier: notifier,
    );
  });

  tearDown(() => database.close());

  test('late remote failure preserves a replacement worker lease', () async {
    notion.beforeContent = () async {
      final job = (await database.readJobs()).single;
      await database.customStatement(
        'UPDATE sync_jobs SET lease_owner = ? WHERE id = ?',
        ['replacement-worker', job.id],
      );
    };
    notion.failNextContentAppend = true;
    await coordinator.run(SyncReason.manual);
    final job = (await database.readJobs()).single;
    expect(job.leaseOwner, 'replacement-worker');
    expect(job.attemptCount, 0);
    expect(job.lastErrorType, isNull);
  });

  test('concurrent lectures retain both sets of extracted tasks', () async {
    await database.replaceSubjects([notion.subject]);
    await Future.wait([
      coordinator.importTranscript(
        title: 'First lecture',
        transcriptText: 'A star search',
      ),
      coordinator.importTranscript(
        title: 'Second lecture',
        transcriptText: 'Breadth first search',
      ),
    ]);
    expect(
      await database.readAcademicRecords(kind: AcademicRecordKind.lectureTask),
      hasLength(2),
    );
  });

  test(
    'joined accounts acquire remote claims without a bootstrap token',
    () async {
      coordinator = SyncCoordinator(
        database: database,
        credentials: _FakeCredentials(withBootstrap: false),
        fireflies: fireflies,
        gemini: gemini,
        notion: notion,
        relay: relay,
      );
      await coordinator.run(SyncReason.manual);
      expect(relay.claimCalls, greaterThan(0));
    },
  );

  test('reprocessing cannot clear a live worker lease', () async {
    await database.discoverJob(
      id: 'busy',
      firefliesId: 'busy',
      title: 'Busy',
      meetingDate: DateTime.utc(2026),
    );
    await database.claimJob(id: 'busy', owner: 'other-worker');
    await coordinator.regenerateSummary('busy');
    expect((await database.readJob('busy'))!.leaseOwner, 'other-worker');
    expect(gemini.summaryCalls, 0);
  });

  test(
    'Fireflies to Gemini to Notion reaches success and clears transcript',
    () async {
      final result = await coordinator.run(SyncReason.manual);
      final job = (await database.watchJobs().first).single;

      expect(result.discovered, 1);
      expect(result.processed, 1);
      expect(job.status, SyncJobStatus.success);
      expect(job.transcriptJson, isNull);
      expect(job.notionPageId, 'notion-page');
      expect(gemini.summaryCalls, 1);
      expect(notion.createCalls, 1);
      expect(notifier.successes, 1);
      final tasks = await database.readAcademicRecords(
        kind: AcademicRecordKind.lectureTask,
      );
      expect(tasks, hasLength(1));
      expect(tasks.single.payload['supportingSegment'], contains('sexta'));
    },
  );

  test(
    'low confidence generates once, pauses, then publishes manual choice',
    () async {
      gemini.result = const ClassificationResult(
        decision: ClassificationDecision.uncertain,
        subjectId: 'subject-ai',
        subjectName: 'Inteligência Artificial',
        confidence: 0.67,
        candidates: [
          ClassificationCandidate(
            subjectId: 'subject-ai',
            subjectName: 'Inteligência Artificial',
            confidence: 0.67,
          ),
        ],
        reasoningSummary: ['Ambiguous title'],
      );

      await coordinator.run(SyncReason.manual);
      var job = (await database.watchJobs().first).single;
      expect(job.status, SyncJobStatus.needsReview);
      expect(job.summaryJson, isNotNull);
      expect(notion.createCalls, 0);

      await coordinator.confirmSubject(job.id, notion.subject);
      job = (await database.readJob(job.id))!;
      expect(job.status, SyncJobStatus.success);
      expect(
        gemini.summaryCalls,
        1,
        reason: 'manual choice reuses generated summary',
      );
      expect(notion.createCalls, 1);
    },
  );

  test('AI-disabled classification waits for a manual class choice', () async {
    await database.saveSettings(
      (await database.readSettings()).copyWith(useAiClassification: false),
    );

    await coordinator.run(SyncReason.manual);

    final job = (await database.readJobs()).single;
    expect(job.status, SyncJobStatus.needsReview);
    expect(job.subjectId, isNull);
    expect(job.summaryJson, isNull);
    expect(gemini.classificationCalls, 0);
    final classification = ClassificationResult.fromJson(
      jsonDecode(job.classificationCandidatesJson!) as Map<String, dynamic>,
    );
    expect(classification.candidates.single.subjectId, notion.subject.notionId);
  });

  test(
    'third Gemini failure suggests a model but keeps normal retry',
    () async {
      gemini.failClassification = true;
      ModelRetryPrompt? prompt;
      coordinator = SyncCoordinator(
        database: database,
        credentials: _FakeCredentials(),
        fireflies: fireflies,
        gemini: gemini,
        notion: notion,
        relay: relay,
        notifier: notifier,
        onModelRetrySuggested: (value) => prompt = value,
      );

      await coordinator.run(SyncReason.manual);
      var job = (await database.readJobs()).single;
      await coordinator.retryJob(job.id);
      await coordinator.retryJob(job.id);

      job = (await database.readJob(job.id))!;
      expect(job.status, SyncJobStatus.failedRetryable);
      expect(job.attemptCount, 3);
      expect(job.nextRetryAt, isNotNull);
      expect(prompt?.operation, GeminiOperation.classification);
      expect(prompt?.currentModel, AppSettings.defaults.classificationModel);
      expect(prompt?.retryScheduled, isTrue);
    },
  );

  test('existing Fireflies ID prevents a second Notion page', () async {
    notion.existing = const NotionPageRef(
      id: 'existing-page',
      url: 'https://notion.so/existing',
    );

    await coordinator.run(SyncReason.manual);
    final job = (await database.watchJobs().first).single;

    expect(job.status, SyncJobStatus.duplicate);
    expect(job.notionPageId, 'existing-page');
    expect(notion.createCalls, 0);
  });

  test('Notion append failure retries the same persisted page', () async {
    notion.failNextContentAppend = true;

    await coordinator.run(SyncReason.manual);
    var job = (await database.watchJobs().first).single;
    expect(job.status, SyncJobStatus.failedRetryable);
    expect(job.notionPageId, 'notion-page');
    expect(notion.createCalls, 1);

    await coordinator.retryJob(job.id);
    job = (await database.readJob(job.id))!;
    expect(job.status, SyncJobStatus.success);
    expect(job.notionPageId, 'notion-page');
    expect(
      notion.createCalls,
      1,
      reason: 'retry must not create a second page',
    );
    expect(notion.contentCalls, 2);
  });

  test(
    'regeneration updates the existing Notion page without duplication',
    () async {
      await coordinator.run(SyncReason.manual);
      var job = (await database.watchJobs().first).single;

      await coordinator.regenerateSummary(job.id);

      job = (await database.readJob(job.id))!;
      expect(job.status, SyncJobStatus.success);
      expect(job.reprocessMode, isNull);
      expect(gemini.summaryCalls, 2);
      expect(notion.createCalls, 1);
      expect(notion.contentCalls, 2);
    },
  );

  test('changing an AI subject replaces the existing Notion summary', () async {
    await coordinator.run(SyncReason.manual);
    var job = (await database.readJobs()).single;
    final corrected = AcademicSubject(
      notionId: 'subject-corrected',
      name: 'Lógica',
      year: '3º Ano',
      semester: '1º Semestre',
      status: 'In progress',
      lastSyncedAt: DateTime.utc(2026, 9, 5),
    );
    await database.replaceSubjects([notion.subject, corrected]);

    await coordinator.confirmSubject(job.id, corrected);

    job = (await database.readJob(job.id))!;
    expect(job.status, SyncJobStatus.success);
    expect(job.subjectId, corrected.notionId);
    expect(job.classificationConfidence, isNull);
    expect(gemini.summaryCalls, 2);
    expect(notion.createCalls, 1);
    expect(notion.replaceCalls, 1);
  });

  test('relay and polling discovery merge to one durable job', () async {
    relay.events = [
      RelayEvent(
        id: 'meeting.transcribed:meeting-1',
        firefliesTranscriptId: 'meeting-1',
        eventType: 'meeting.transcribed',
        receivedAt: DateTime.utc(2026, 9, 5),
      ),
    ];

    await coordinator.run(SyncReason.manual);

    expect(await database.watchJobs().first, hasLength(1));
    expect(relay.acknowledged, ['meeting.transcribed:meeting-1']);
  });

  test('Fireflies polling uses the durable cursor overlap', () async {
    final cursor = DateTime.utc(2026, 9, 5, 12);
    await database.saveCursor('fireflies', cursor);

    await coordinator.run(SyncReason.manual);

    expect(
      fireflies.lastFrom?.toUtc(),
      cursor.subtract(const Duration(hours: 48)),
    );
  });

  test(
    'polls every named Fireflies connection and fetches with its key',
    () async {
      final credentials = _FakeCredentials(
        connections: const [
          FirefliesConnection(id: 'ana', name: 'Ana', apiKey: 'key-ana'),
          FirefliesConnection(id: 'rui', name: 'Rui', apiKey: 'key-rui'),
        ],
      );
      fireflies.transcriptsByKey = {
        'key-ana': [_lecture('meeting-ana', 'Ana recorder')],
        'key-rui': [_lecture('meeting-rui', 'Rui recorder')],
      };
      coordinator = SyncCoordinator(
        database: database,
        credentials: credentials,
        fireflies: fireflies,
        gemini: gemini,
        notion: notion,
        relay: relay,
        notifier: notifier,
      );

      final result = await coordinator.run(SyncReason.manual);

      expect(result.discovered, 2);
      expect(fireflies.listKeys, containsAll(['key-ana', 'key-rui']));
      expect(fireflies.fetchKeys, containsAll(['key-ana', 'key-rui']));
      expect(await database.readJobs(), hasLength(2));
    },
  );

  test(
    'webhook transcript tries named keys until owner access succeeds',
    () async {
      final credentials = _FakeCredentials(
        connections: const [
          FirefliesConnection(id: 'mine', name: 'Mine', apiKey: 'key-mine'),
          FirefliesConnection(
            id: 'colleague',
            name: 'Colleague',
            apiKey: 'key-colleague',
          ),
        ],
      );
      fireflies.transcriptsByKey = {
        'key-mine': const [],
        'key-colleague': [_lecture('meeting-shared', 'Shared recorder')],
      };
      relay.events = [
        RelayEvent(
          id: 'meeting.transcribed:meeting-shared',
          firefliesTranscriptId: 'meeting-shared',
          eventType: 'meeting.transcribed',
          receivedAt: DateTime.utc(2026, 9, 5),
        ),
      ];
      coordinator = SyncCoordinator(
        database: database,
        credentials: credentials,
        fireflies: fireflies,
        gemini: gemini,
        notion: notion,
        relay: relay,
        notifier: notifier,
      );

      final result = await coordinator.run(SyncReason.firefliesWebhook);

      expect(result.processed, 1);
      expect(fireflies.fetchKeys, ['key-mine', 'key-colleague']);
      final job = (await database.readJobs()).single;
      expect(job.status, SyncJobStatus.success);
      expect(job.sourceType, 'fireflies:colleague');
    },
  );

  test('discovery outages do not block a durable manual job', () async {
    await database.replaceSubjects([notion.subject]);
    await database.discoverJob(
      id: 'manual-job',
      firefliesId: 'manual:job',
      title: 'Search algorithms',
      meetingDate: DateTime.utc(2026, 9, 5),
      sourceType: 'manual',
    );
    await database.saveTranscript(
      'manual-job',
      LectureTranscript(
        firefliesId: 'manual:job',
        title: 'Search algorithms',
        date: DateTime.utc(2026, 9, 5),
        sentences: const [TranscriptSentence(text: 'A star search')],
      ),
    );
    await database.setJobStatus('manual-job', SyncJobStatus.queued, 'Queued');
    fireflies.failList = true;
    notion.failQuery = true;

    final result = await coordinator.run(SyncReason.manual);

    expect(result.processed, 1);
    expect(
      (await database.readJob('manual-job'))?.status,
      SyncJobStatus.success,
    );
  });
}

LectureTranscript _lecture(String id, String title) => LectureTranscript(
  firefliesId: id,
  title: title,
  date: DateTime.utc(2026, 9, 5, 10),
  sentences: const [TranscriptSentence(text: 'Shared lecture transcript')],
);

class _FakeCredentials extends SecureCredentialStore {
  _FakeCredentials({
    this.withBootstrap = true,
    this.connections = const [
      FirefliesConnection(
        id: FirefliesConnection.legacyId,
        name: 'Primary',
        apiKey: 'test-key',
      ),
    ],
  });

  final List<FirefliesConnection> connections;
  final bool withBootstrap;

  @override
  Future<List<FirefliesConnection>> readFirefliesConnections() async =>
      connections;

  @override
  Future<String?> read(CredentialKey key) async => switch (key) {
    CredentialKey.relayDeviceToken =>
      withBootstrap ? '0123456789abcdef0123456789abcdef' : null,
    CredentialKey.relayDeviceCredential =>
      'device-test.0123456789abcdef0123456789abcdef',
    _ => 'test-key',
  };
}

class _FakeFireflies extends FirefliesClient {
  DateTime? lastFrom;
  var failList = false;
  Map<String, List<LectureTranscript>>? transcriptsByKey;
  final listKeys = <String>[];
  final fetchKeys = <String>[];
  final transcript = LectureTranscript(
    firefliesId: 'meeting-1',
    title: 'Search algorithms',
    date: DateTime.utc(2026, 9, 5, 10),
    firefliesUrl: 'https://app.fireflies.ai/view/meeting-1',
    sentences: const [
      TranscriptSentence(
        speakerName: 'Professor',
        text: 'Today we compare breadth-first and A-star search.',
      ),
    ],
  );

  @override
  Future<List<FirefliesTranscriptRef>> listTranscripts({
    required String apiKey,
    required DateTime from,
  }) async {
    if (failList) {
      throw const IntegrationException(
        integration: 'Fireflies',
        code: 'offline',
        userMessage: 'offline',
        retryable: true,
      );
    }
    listKeys.add(apiKey);
    lastFrom = from;
    final configured = transcriptsByKey;
    if (configured != null) {
      return (configured[apiKey] ?? const [])
          .map(
            (item) => FirefliesTranscriptRef(
              id: item.firefliesId,
              title: item.title,
              date: item.date,
              url: item.firefliesUrl,
            ),
          )
          .toList();
    }
    return [
      FirefliesTranscriptRef(
        id: transcript.firefliesId,
        title: transcript.title,
        date: transcript.date,
        url: transcript.firefliesUrl,
      ),
    ];
  }

  @override
  Future<LectureTranscript> fetchTranscript({
    required String apiKey,
    required String transcriptId,
  }) async {
    fetchKeys.add(apiKey);
    final configured = transcriptsByKey;
    if (configured == null) return transcript;
    for (final item in configured[apiKey] ?? const []) {
      if (item.firefliesId == transcriptId) return item;
    }
    throw const IntegrationException(
      integration: 'Fireflies',
      code: 'forbidden',
      userMessage: 'Key cannot access transcript.',
      retryable: false,
    );
  }
}

class _FakeGemini extends GeminiClient {
  var classificationCalls = 0;
  var summaryCalls = 0;
  var failClassification = false;
  ClassificationResult result = const ClassificationResult(
    decision: ClassificationDecision.match,
    subjectId: 'subject-ai',
    subjectName: 'Inteligência Artificial',
    confidence: 0.94,
    candidates: [
      ClassificationCandidate(
        subjectId: 'subject-ai',
        subjectName: 'Inteligência Artificial',
        confidence: 0.94,
      ),
    ],
    reasoningSummary: ['Search algorithms'],
  );

  @override
  Future<ClassificationResult> classify({
    required String apiKey,
    required String model,
    required LectureTranscript transcript,
    required List<AcademicSubject> subjects,
    TimetableContext? timetableContext,
  }) async {
    classificationCalls += 1;
    if (failClassification) {
      throw const IntegrationException(
        integration: 'Gemini',
        code: 'timeout',
        userMessage: 'Gemini is temporarily unavailable.',
        retryable: true,
      );
    }
    return result;
  }

  @override
  Future<LectureSummary> summarize({
    required String apiKey,
    required String model,
    required LectureTranscript transcript,
    required AcademicSubject subject,
    required AppSettings settings,
    List<AcademicRecord> courseContext = const [],
  }) async {
    summaryCalls += 1;
    return LectureSummary(
      title: 'Algoritmos de Pesquisa',
      context: 'Comparação de algoritmos de pesquisa.',
      objectives: ['Distinguir BFS e A*.'],
      sections: [
        LectureSummarySection(
          title: 'Pesquisa informada',
          content: 'A* usa uma heurística.',
          keyPoints: ['A heurística não deve sobrestimar.'],
        ),
      ],
      conclusions: ['Escolher o algoritmo conforme o problema.'],
      actionItems: [
        LectureActionCandidate(
          title: 'Entregar implementação A*',
          description: 'Submeter o exercício pedido na aula.',
          dueAt: DateTime.utc(2026, 9, 11, 18),
          confidence: LectureActionConfidence.certain,
          supportingSegment: 'Entreguem a implementação até sexta.',
          timestampSeconds: 900,
        ),
      ],
    );
  }

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
  }) => summarize(
    apiKey: apiKey,
    model: model,
    transcript: transcript,
    subject: subject,
    settings: settings,
  );
}

class _FakeNotion extends NotionClient {
  final subject = AcademicSubject(
    notionId: 'subject-ai',
    name: 'Inteligência Artificial',
    year: '3º Ano',
    semester: '1º Semestre',
    status: 'In progress',
    lastSyncedAt: DateTime.utc(2026, 9, 5),
  );
  NotionPageRef? existing;
  var createCalls = 0;
  var contentCalls = 0;
  var replaceCalls = 0;
  var failNextContentAppend = false;
  var failQuery = false;
  Future<void> Function()? beforeContent;

  @override
  Future<List<AcademicSubject>> querySubjects({
    required String token,
    required String dataSourceId,
  }) async {
    if (failQuery) {
      throw const IntegrationException(
        integration: 'Notion',
        code: 'offline',
        userMessage: 'offline',
        retryable: true,
      );
    }
    return [subject];
  }

  @override
  Future<NotionPageRef?> findSummaryByFirefliesId({
    required String token,
    required String dataSourceId,
    required String firefliesId,
  }) async => existing;

  @override
  Future<NotionPageRef> createSummaryPage({
    required String token,
    required String dataSourceId,
    required String firefliesId,
    required DateTime lectureDate,
    required String subjectId,
    required LectureSummary summary,
    required bool includeMetadata,
  }) async {
    createCalls += 1;
    return const NotionPageRef(
      id: 'notion-page',
      url: 'https://notion.so/notion-page',
    );
  }

  @override
  Future<void> ensureSummaryContent({
    required String token,
    required String pageId,
    required LectureSummary summary,
    required DateTime lectureDate,
    required String? firefliesUrl,
  }) async {
    contentCalls += 1;
    await beforeContent?.call();
    if (failNextContentAppend) {
      failNextContentAppend = false;
      throw const IntegrationException(
        integration: 'Notion',
        code: 'offline',
        userMessage: 'Notion is temporarily unavailable.',
        retryable: true,
      );
    }
  }

  @override
  Future<void> replaceSummaryPage({
    required String token,
    required String pageId,
    required String firefliesId,
    required DateTime lectureDate,
    required String subjectId,
    required LectureSummary summary,
    required String? firefliesUrl,
    required bool includeMetadata,
  }) async {
    contentCalls += 1;
    replaceCalls += 1;
  }
}

class _FakeRelay extends RelayClient {
  var claimCalls = 0;
  final completedPages = <String, String>{};
  List<RelayEvent> events = const [];
  final acknowledged = <String>[];

  @override
  Future<RelayClaim> claim({
    required String baseUrl,
    required String token,
    required String firefliesId,
    String? reprocessPageId,
  }) async {
    claimCalls++;
    final page = completedPages[firefliesId];
    if (page != null && reprocessPageId != page) {
      return RelayClaim(acquired: false, completed: true, notionPageId: page);
    }
    if (reprocessPageId == page) completedPages.remove(firefliesId);
    return const RelayClaim(acquired: true, completed: false);
  }

  @override
  Future<void> completeClaim({
    required String baseUrl,
    required String token,
    required String firefliesId,
    required String notionPageId,
  }) async {
    completedPages[firefliesId] = notionPageId;
  }

  @override
  Future<List<RelayEvent>> pendingEvents({
    required String baseUrl,
    required String token,
  }) async => events;

  @override
  Future<void> acknowledge({
    required String baseUrl,
    required String token,
    required String eventId,
  }) async {
    acknowledged.add(eventId);
  }
}

class _FakeNotifier implements SyncNotifier {
  var successes = 0;

  @override
  Future<void> failure(String jobId, String message) async {}

  @override
  Future<void> needsReview(String jobId) async {}

  @override
  Future<void> success(String jobId, String subjectName) async {
    successes += 1;
  }
}
