import 'dart:convert';

import '../academic/academic_models.dart';

const _summaryLanguageOverrideKey = '_classsync_summary_language';

String? summaryLanguageOverrideFromPartials(
  Iterable<Map<String, dynamic>> partials,
) {
  for (final partial in partials) {
    final value = partial[_summaryLanguageOverrideKey];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

List<Map<String, dynamic>> summaryContentPartials(
  Iterable<Map<String, dynamic>> partials,
) => partials
    .where((partial) => !partial.containsKey(_summaryLanguageOverrideKey))
    .map((partial) => Map<String, dynamic>.from(partial))
    .toList();

List<Map<String, dynamic>> summaryPartialsWithLanguage(
  Iterable<Map<String, dynamic>> partials,
  String? language,
) {
  final content = summaryContentPartials(partials);
  final normalized = language?.trim();
  if (normalized == null || normalized.isEmpty) return content;
  return [
    {_summaryLanguageOverrideKey: normalized},
    ...content,
  ];
}

enum SyncJobStatus {
  discovered,
  queued,
  fetchingTranscript,
  classifying,
  summarizing,
  publishing,
  needsReview,
  ignored,
  duplicate,
  success,
  failedRetryable,
  failedTerminal,
  corrupt;

  String get wireName => switch (this) {
    SyncJobStatus.fetchingTranscript => 'fetching_transcript',
    SyncJobStatus.needsReview => 'needs_review',
    SyncJobStatus.failedRetryable => 'failed_retryable',
    SyncJobStatus.failedTerminal => 'failed_terminal',
    _ => name,
  };

  static SyncJobStatus fromWire(String value) => values.firstWhere(
    (status) => status.wireName == value,
    orElse: () => SyncJobStatus.corrupt,
  );

  bool get isProcessing => const {
    SyncJobStatus.fetchingTranscript,
    SyncJobStatus.classifying,
    SyncJobStatus.summarizing,
    SyncJobStatus.publishing,
  }.contains(this);

  bool get isTerminal => const {
    SyncJobStatus.ignored,
    SyncJobStatus.duplicate,
    SyncJobStatus.success,
    SyncJobStatus.failedTerminal,
    SyncJobStatus.corrupt,
  }.contains(this);
}

enum SyncReason {
  desktopStartup,
  manual,
  periodicPoll,
  mobileBackground,
  firefliesWebhook,
  appResume;

  String get wireName => switch (this) {
    SyncReason.desktopStartup => 'desktop_startup',
    SyncReason.periodicPoll => 'periodic_poll',
    SyncReason.mobileBackground => 'mobile_background',
    SyncReason.firefliesWebhook => 'fireflies_webhook',
    SyncReason.appResume => 'app_resume',
    SyncReason.manual => 'manual',
  };
}

enum ClassificationDecision { match, uncertain, notALecture }

enum GeminiOperation { classification, summary }

class ModelRetryPrompt {
  const ModelRetryPrompt({
    required this.jobId,
    required this.operation,
    required this.currentModel,
    required this.attemptCount,
    required this.message,
    required this.retryScheduled,
  });

  final String jobId;
  final GeminiOperation operation;
  final String currentModel;
  final int attemptCount;
  final String message;
  final bool retryScheduled;
}

class ClassificationCandidate {
  const ClassificationCandidate({
    required this.subjectId,
    required this.subjectName,
    required this.confidence,
  });

  final String subjectId;
  final String subjectName;
  final double confidence;

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'subjectName': subjectName,
    'confidence': confidence,
  };

  factory ClassificationCandidate.fromJson(Map<String, dynamic> json) =>
      ClassificationCandidate(
        subjectId: json['subjectId'] as String? ?? '',
        subjectName: json['subjectName'] as String? ?? '',
        confidence: (json['confidence'] as num? ?? 0).toDouble().clamp(0, 1),
      );
}

class ClassificationResult {
  const ClassificationResult({
    required this.decision,
    required this.confidence,
    required this.candidates,
    required this.reasoningSummary,
    this.subjectId,
    this.subjectName,
    this.suggestedLectureTitle,
  });

  final ClassificationDecision decision;
  final String? subjectId;
  final String? subjectName;
  final double confidence;
  final List<ClassificationCandidate> candidates;
  final List<String> reasoningSummary;
  final String? suggestedLectureTitle;

  bool hasValidSubject(Iterable<AcademicSubject> subjects) =>
      subjectId != null &&
      subjects.any((subject) => subject.notionId == subjectId);

  Map<String, dynamic> toJson() => {
    'decision': switch (decision) {
      ClassificationDecision.match => 'match',
      ClassificationDecision.uncertain => 'uncertain',
      ClassificationDecision.notALecture => 'not_a_lecture',
    },
    'subjectId': subjectId,
    'subjectName': subjectName,
    'confidence': confidence,
    'candidates': candidates.map((candidate) => candidate.toJson()).toList(),
    'reasoningSummary': reasoningSummary,
    'suggestedLectureTitle': suggestedLectureTitle,
  };

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    final decision = switch (json['decision']) {
      'match' => ClassificationDecision.match,
      'not_a_lecture' => ClassificationDecision.notALecture,
      _ => ClassificationDecision.uncertain,
    };
    return ClassificationResult(
      decision: decision,
      subjectId: json['subjectId'] as String?,
      subjectName: json['subjectName'] as String?,
      confidence: (json['confidence'] as num? ?? 0).toDouble().clamp(0, 1),
      candidates: (json['candidates'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClassificationCandidate.fromJson)
          .toList(),
      reasoningSummary: (json['reasoningSummary'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      suggestedLectureTitle: json['suggestedLectureTitle'] as String?,
    );
  }
}

class SyncJob {
  const SyncJob({
    required this.id,
    required this.firefliesId,
    required this.title,
    required this.meetingDate,
    required this.status,
    required this.sourceType,
    required this.attemptCount,
    required this.discoveredAt,
    required this.updatedAt,
    this.firefliesUrl,
    this.subjectId,
    this.subjectName,
    this.classificationConfidence,
    this.classificationCandidatesJson,
    this.transcriptJson,
    this.summaryTitle,
    this.summaryJson,
    this.notionPageId,
    this.notionUrl,
    this.reprocessMode,
    this.nextRetryAt,
    this.lastErrorType,
    this.lastErrorMessage,
    this.startedAt,
    this.completedAt,
    this.leaseOwner,
    this.leaseExpiresAt,
    this.summaryPartialsJson,
  });

  final String id;
  final String firefliesId;
  final String title;
  final DateTime meetingDate;
  final String? firefliesUrl;
  final SyncJobStatus status;
  final String sourceType;
  final String? subjectId;
  final String? subjectName;
  final double? classificationConfidence;
  final String? classificationCandidatesJson;
  final String? transcriptJson;
  final String? summaryTitle;
  final String? summaryJson;
  final String? notionPageId;
  final String? notionUrl;
  final String? reprocessMode;
  final int attemptCount;
  final DateTime? nextRetryAt;
  final String? lastErrorType;
  final String? lastErrorMessage;
  final DateTime discoveredAt;
  final DateTime? startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? leaseOwner;
  final DateTime? leaseExpiresAt;
  final String? summaryPartialsJson;

  String? get summaryLanguageOverride {
    final encoded = summaryPartialsJson;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List<dynamic>) return null;
      return summaryLanguageOverrideFromPartials(
        decoded.whereType<Map<String, dynamic>>(),
      );
    } on FormatException {
      return null;
    }
  }
}

class JobTimelineEvent {
  const JobTimelineEvent({
    required this.id,
    required this.jobId,
    required this.stage,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String jobId;
  final String stage;
  final String message;
  final DateTime createdAt;
}
