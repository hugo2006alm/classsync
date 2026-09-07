import 'dart:convert';

import '../../domain/academic/academic_hub_models.dart';
import '../../domain/academic/academic_models.dart';
import '../database/classsync_database.dart';
import '../integrations/gemini/gemini_client.dart';
import '../security/secure_credential_store.dart';

class AcademicResearchService {
  const AcademicResearchService({
    required ClassSyncDatabase database,
    required SecureCredentialStore credentials,
    required GeminiClient gemini,
  }) : _database = database,
       _credentials = credentials,
       _gemini = gemini;

  final ClassSyncDatabase _database;
  final SecureCredentialStore _credentials;
  final GeminiClient _gemini;

  Future<List<AcademicSearchHit>> search(
    String query, {
    String? subjectId,
    Set<String>? subjectIds,
    Set<AcademicRecordKind>? kinds,
    DateTime? from,
    DateTime? to,
  }) async {
    final terms = SubjectMapper.normalize(
      query,
    ).split(' ').where((term) => term.length > 1).toSet();
    if (terms.isEmpty) return const [];
    final hits = <AcademicSearchHit>[];
    final records = await _database.readAcademicRecords();
    for (final record in records) {
      if (subjectId != null && record.subjectId != subjectId) continue;
      if (subjectIds != null && !subjectIds.contains(record.subjectId)) {
        continue;
      }
      if (kinds != null && !kinds.contains(record.kind)) continue;
      if (from != null && record.startsAt?.isBefore(from) == true) continue;
      if (to != null && record.startsAt?.isAfter(to) == true) continue;
      final body = '${record.title}\n${jsonEncode(record.payload)}';
      final score = _score(terms, body, title: record.title);
      if (score == 0) continue;
      hits.add(
        AcademicSearchHit(
          id: record.key,
          title: record.title,
          excerpt: _excerpt(body, terms),
          kind: record.kind,
          source: record.source,
          score: score,
          subjectId: record.subjectId,
          date: record.startsAt,
          url: record.payload['sourceUrl'] as String?,
        ),
      );
    }
    if (kinds == null || kinds.contains(AcademicRecordKind.lessonSummary)) {
      for (final job in await _database.readJobs()) {
        if (subjectId != null && job.subjectId != subjectId) continue;
        if (subjectIds != null && !subjectIds.contains(job.subjectId)) continue;
        if (from != null && job.meetingDate.isBefore(from)) continue;
        if (to != null && job.meetingDate.isAfter(to)) continue;
        final summary = job.summaryJson;
        final transcript = job.transcriptJson;
        if (summary == null && transcript == null) continue;
        final body = [
          job.title,
          ?summary,
          // A transcript participates only while local retention has kept it.
          if (transcript != null)
            LectureTranscript.fromStoredJson(transcript).plainText,
        ].join('\n');
        final score = _score(terms, body, title: job.title);
        if (score == 0) continue;
        hits.add(
          AcademicSearchHit(
            id: 'lecture:${job.id}',
            title: job.summaryTitle ?? job.title,
            excerpt: _excerpt(body, terms),
            kind: AcademicRecordKind.lessonSummary,
            source: AcademicSource.manual,
            score: score,
            subjectId: job.subjectId,
            date: job.meetingDate,
            url: job.notionUrl ?? job.firefliesUrl,
          ),
        );
      }
    }
    hits.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
    });
    return hits.take(50).toList(growable: false);
  }

  Future<AcademicGroundedAnswer> ask(
    String question, {
    String? subjectId,
    Set<String>? subjectIds,
    Set<AcademicRecordKind>? kinds,
    DateTime? from,
    DateTime? to,
  }) async {
    final evidence = await search(
      question,
      subjectId: subjectId,
      subjectIds: subjectIds,
      kinds: kinds,
      from: from,
      to: to,
    );
    if (evidence.isEmpty) {
      return const AcademicGroundedAnswer(
        answer: 'There is not enough local evidence to answer that question.',
        citationIds: [],
        insufficientEvidence: true,
      );
    }
    final apiKey = await _credentials.read(CredentialKey.geminiApiKey);
    if (apiKey == null || apiKey.isEmpty) {
      return AcademicGroundedAnswer(
        answer:
            'Gemini is not configured. The matching local sources are shown below.',
        citationIds: evidence.take(5).map((item) => item.id).toList(),
        insufficientEvidence: true,
      );
    }
    final settings = await _database.readSettings();
    return _gemini.answerFromEvidence(
      apiKey: apiKey,
      model: settings.summaryModel,
      question: question,
      evidence: evidence,
    );
  }

  static int _score(Set<String> terms, String body, {required String title}) {
    final normalizedBody = SubjectMapper.normalize(body);
    final normalizedTitle = SubjectMapper.normalize(title);
    var score = 0;
    for (final term in terms) {
      if (normalizedTitle.contains(term)) score += 5;
      score += RegExp(
        '(?:^| )${RegExp.escape(term)}(?: |\$)',
      ).allMatches(normalizedBody).length;
    }
    return score;
  }

  static String _excerpt(String body, Set<String> terms) {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 280) return compact;
    final lower = compact.toLowerCase();
    final positions = terms
        .map(lower.indexOf)
        .where((position) => position >= 0)
        .toList();
    final start = positions.isEmpty
        ? 0
        : (positions.reduce((a, b) => a < b ? a : b) - 80)
              .clamp(0, compact.length)
              .toInt();
    final end = (start + 280).clamp(0, compact.length).toInt();
    return '${start > 0 ? '…' : ''}${compact.substring(start, end)}${end < compact.length ? '…' : ''}';
  }
}
