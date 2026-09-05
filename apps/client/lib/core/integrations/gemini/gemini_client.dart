import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../domain/academic/academic_models.dart';
import '../../../../domain/settings/app_settings.dart';
import '../../../../domain/sync/sync_models.dart';
import '../../../../domain/sync/transcript_chunker.dart';
import '../integration_exception.dart';

class GeminiClient {
  GeminiClient({Dio? dio})
    : _dio =
          dio ??
          createDio(baseUrl: 'https://generativelanguage.googleapis.com');

  final Dio _dio;

  Future<void> testConnection({
    required String apiKey,
    required String model,
  }) async {
    await _generate(
      apiKey: apiKey,
      model: model,
      prompt: 'Return JSON with ok=true.',
      schema: const {
        'type': 'object',
        'properties': {
          'ok': {'type': 'boolean'},
        },
        'required': ['ok'],
      },
    );
  }

  Future<ClassificationResult> classify({
    required String apiKey,
    required String model,
    required LectureTranscript transcript,
    required List<AcademicSubject> subjects,
  }) async {
    if (subjects.isEmpty) {
      throw const IntegrationException(
        integration: 'Notion',
        code: 'no_active_subjects',
        userMessage: 'No active Notion classes were found.',
        retryable: false,
      );
    }
    final candidateJson = subjects
        .map(
          (subject) => {
            'subjectId': subject.notionId,
            'subjectName': subject.name,
            'year': subject.year,
            'semester': subject.semester,
            'aliases': subject.aliases,
            'professors': subject.professors,
            'scheduleHints': subject.scheduleHints,
          },
        )
        .toList();
    final prompt =
        '''
You classify university lecture transcripts. Return only schema-valid JSON.
Decide match, uncertain, or not_a_lecture. Confidence is a heuristic from 0 to 1.
Never invent a subjectId; use only supplied candidates. Timetable alone cannot force a match.

Meeting title: ${transcript.title}
Date: ${transcript.date.toIso8601String()}
Participants: ${transcript.participants.join(', ')}
Candidates: ${jsonEncode(candidateJson)}

Representative transcript sample:
${_classificationSample(transcript)}
''';
    final json = await _generate(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      schema: _classificationSchema,
    );
    final result = ClassificationResult.fromJson(json);
    if (result.decision != ClassificationDecision.notALecture &&
        result.subjectId != null &&
        !result.hasValidSubject(subjects)) {
      throw const IntegrationException(
        integration: 'Gemini',
        code: 'invented_subject',
        userMessage: 'Gemini returned a class outside the active Notion list.',
        retryable: false,
      );
    }
    return result;
  }

  Future<LectureSummary> summarize({
    required String apiKey,
    required String model,
    required LectureTranscript transcript,
    required AcademicSubject subject,
    required AppSettings settings,
  }) async {
    final chunks = const TranscriptChunker().chunk(transcript.plainText);
    if (chunks.length == 1) {
      final json = await _summaryRequest(
        apiKey: apiKey,
        model: model,
        subject: subject,
        settings: settings,
        text: chunks.single,
        synthesis: false,
      );
      return LectureSummary.fromJson(json);
    }

    final partials = <Map<String, dynamic>>[];
    for (var index = 0; index < chunks.length; index += 1) {
      partials.add(
        await _summaryRequest(
          apiKey: apiKey,
          model: model,
          subject: subject,
          settings: settings,
          text: 'Chunk ${index + 1}/${chunks.length}:\n${chunks[index]}',
          synthesis: false,
        ),
      );
    }
    final synthesis = await _summaryRequest(
      apiKey: apiKey,
      model: model,
      subject: subject,
      settings: settings,
      text: jsonEncode(partials),
      synthesis: true,
    );
    return LectureSummary.fromJson(synthesis);
  }

  Future<Map<String, dynamic>> _summaryRequest({
    required String apiKey,
    required String model,
    required AcademicSubject subject,
    required AppSettings settings,
    required String text,
    required bool synthesis,
  }) => _generate(
    apiKey: apiKey,
    model: model,
    schema: _summarySchema,
    prompt:
        '''
Create detailed university study notes in ${settings.summaryLanguage} for ${subject.name}.
Detail: ${settings.summaryDetail.name}. ${synthesis ? 'Synthesize chunk notes, preserve chronology when useful, and remove duplicates.' : 'Summarize transcript faithfully.'}

Required style: start with Contexto e Objetivos da Aula; use meaningful topic sections; finish with Conclusões e Pontos-Chave. Preserve definitions, technical terms, formulas, code, algorithms, examples, procedures, warnings, comparisons, exam hints, and explicit emphasis. Remove filler and repetition. Never fabricate. Put unreliable passages in uncertainties instead of guessing. Return only schema-valid JSON.

Source:
$text
''',
  );

  Future<Map<String, dynamic>> _generate({
    required String apiKey,
    required String model,
    required String prompt,
    required Map<String, dynamic> schema,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1beta/models/${Uri.encodeComponent(model)}:generateContent',
        queryParameters: {'key': apiKey},
        data: {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
            'responseJsonSchema': schema,
          },
        },
      );
      final candidates = response.data?['candidates'] as List<dynamic>?;
      final content = candidates?.firstOrNull as Map<String, dynamic>?;
      final parts =
          (content?['content'] as Map<String, dynamic>?)?['parts']
              as List<dynamic>?;
      final text =
          (parts?.firstOrNull as Map<String, dynamic>?)?['text'] as String?;
      if (text == null || text.isEmpty) {
        throw const IntegrationException(
          integration: 'Gemini',
          code: 'empty_response',
          userMessage: 'Gemini returned no structured content.',
          retryable: true,
        );
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Gemini', error);
    } on FormatException {
      throw const IntegrationException(
        integration: 'Gemini',
        code: 'invalid_json',
        userMessage: 'Gemini returned invalid structured content.',
        retryable: true,
      );
    }
  }
}

String _classificationSample(LectureTranscript transcript) {
  final sentences = transcript.sentences;
  if (sentences.length <= 120) return transcript.plainText;
  final selected = <TranscriptSentence>[
    ...sentences.take(40),
    ...sentences.skip(max(0, sentences.length ~/ 2 - 20)).take(40),
    ...sentences.skip(max(0, sentences.length - 40)),
  ];
  return selected
      .map(
        (sentence) => '${sentence.speakerName ?? 'Speaker'}: ${sentence.text}',
      )
      .join('\n');
}

const _classificationSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'decision': {
      'type': 'string',
      'enum': ['match', 'uncertain', 'not_a_lecture'],
    },
    'subjectId': {
      'type': ['string', 'null'],
    },
    'subjectName': {
      'type': ['string', 'null'],
    },
    'confidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
    'candidates': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'subjectId': {'type': 'string'},
          'subjectName': {'type': 'string'},
          'confidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
        },
        'required': ['subjectId', 'subjectName', 'confidence'],
      },
    },
    'reasoningSummary': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'suggestedLectureTitle': {
      'type': ['string', 'null'],
    },
  },
  'required': [
    'decision',
    'subjectId',
    'subjectName',
    'confidence',
    'candidates',
    'reasoningSummary',
    'suggestedLectureTitle',
  ],
};

const _summarySchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'title': {'type': 'string'},
    'context': {'type': 'string'},
    'objectives': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'sections': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'content': {'type': 'string'},
          'keyPoints': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'examples': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'code': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'formulas': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': [
          'title',
          'content',
          'keyPoints',
          'examples',
          'code',
          'formulas',
        ],
      },
    },
    'examHints': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'uncertainties': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'conclusions': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'tags': {
      'type': 'array',
      'items': {'type': 'string'},
    },
  },
  'required': [
    'title',
    'context',
    'objectives',
    'sections',
    'examHints',
    'uncertainties',
    'conclusions',
    'tags',
  ],
};

extension _FirstOrNull on List<dynamic> {
  dynamic get firstOrNull => isEmpty ? null : first;
}
