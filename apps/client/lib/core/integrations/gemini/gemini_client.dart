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
  static const maxTranscriptCharacters = 1200000;
  static const maxClassificationCharacters = 24000;
  static const fallbackModels = <String>[
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash-lite',
  ];

  final Map<String, String> _resolvedModels = {};
  Set<String>? _availableModels;
  DateTime? _availableModelsExpiresAt;

  /// Validates the key without spending a generate-content request.
  ///
  /// Returns the requested model, or the highest-ranked available fallback.
  Future<String> testConnection({
    required String apiKey,
    required String model,
  }) async {
    final selected = await _discoverAvailableModel(
      apiKey: apiKey,
      requestedModel: model,
      forceRefresh: true,
      strict: true,
    );
    if (selected == null) {
      throw const IntegrationException(
        integration: 'Gemini',
        code: 'model_unavailable',
        userMessage:
            'No supported Gemini text model is available for this API key.',
        retryable: false,
      );
    }
    _resolvedModels[model] = selected;
    return selected;
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
    return summarizeResumable(
      apiKey: apiKey,
      model: model,
      transcript: transcript,
      subject: subject,
      settings: settings,
    );
  }

  Future<LectureSummary> summarizeResumable({
    required String apiKey,
    required String model,
    required LectureTranscript transcript,
    required AcademicSubject subject,
    required AppSettings settings,
    List<Map<String, dynamic>> completedPartials = const [],
    Future<void> Function(List<Map<String, dynamic>> partials)? onCheckpoint,
  }) async {
    final chunks = const TranscriptChunker(
      maxInputCharacters: maxTranscriptCharacters,
      maxChunks: 25,
    ).chunk(transcript.plainText);
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

    final partials = <Map<String, dynamic>>[...completedPartials];
    if (partials.length > chunks.length) partials.clear();
    for (var index = partials.length; index < chunks.length; index += 1) {
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
      await onCheckpoint?.call(List.unmodifiable(partials));
    }
    var level = partials;
    while (level.length > 1) {
      final next = <Map<String, dynamic>>[];
      for (var offset = 0; offset < level.length; offset += 5) {
        final batch = level.skip(offset).take(5).toList();
        next.add(
          await _summaryRequest(
            apiKey: apiKey,
            model: model,
            subject: subject,
            settings: settings,
            text: jsonEncode(batch),
            synthesis: true,
          ),
        );
      }
      level = next;
    }
    return LectureSummary.fromJson(level.single);
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
    final attempted = <String>{};
    var candidates = _modelCandidates(model).toList();
    DioException? lastError;
    var transientFallbackUsed = false;

    while (candidates.isNotEmpty && attempted.length < 3) {
      final candidate = candidates.first;
      candidates = candidates.skip(1).toList();
      if (!attempted.add(candidate)) continue;
      try {
        final result = await _generateOnce(
          apiKey: apiKey,
          model: candidate,
          prompt: prompt,
          schema: schema,
        );
        _resolvedModels[model] = candidate;
        return result;
      } on DioException catch (error) {
        lastError = error;
        final fallbackKind = _fallbackKind(error);
        if (fallbackKind == _FallbackKind.none) {
          throw _geminiException(error);
        }
        if (fallbackKind == _FallbackKind.transient) {
          if (transientFallbackUsed) throw _geminiException(error);
          transientFallbackUsed = true;
        } else {
          final discovered = await _discoverAvailableModel(
            apiKey: apiKey,
            requestedModel: model,
            excludedModels: attempted,
            forceRefresh: true,
          );
          if (discovered != null && !attempted.contains(discovered)) {
            candidates = [
              discovered,
              ...candidates.where((item) => item != discovered),
            ];
          }
        }
      } on FormatException {
        throw const IntegrationException(
          integration: 'Gemini',
          code: 'invalid_json',
          userMessage: 'Gemini returned invalid structured content.',
          retryable: true,
        );
      }
    }

    throw lastError == null
        ? const IntegrationException(
            integration: 'Gemini',
            code: 'model_unavailable',
            userMessage: 'No working Gemini summary model is available.',
            retryable: false,
          )
        : _geminiException(lastError);
  }

  Future<Map<String, dynamic>> _generateOnce({
    required String apiKey,
    required String model,
    required String prompt,
    required Map<String, dynamic> schema,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1beta/models/${Uri.encodeComponent(model)}:generateContent',
      options: Options(headers: {'x-goog-api-key': apiKey}),
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
          'maxOutputTokens': 8192,
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
  }

  Iterable<String> _modelCandidates(String requestedModel) sync* {
    final requested = requestedModel.trim();
    final resolved = _resolvedModels[requested];
    if (resolved != null) yield resolved;
    yield requested;
    final requestedIndex = fallbackModels.indexOf(requested);
    final fallbacks = requestedIndex < 0
        ? fallbackModels
        : fallbackModels.skip(requestedIndex + 1);
    yield* fallbacks;
  }

  Future<String?> _discoverAvailableModel({
    required String apiKey,
    required String requestedModel,
    Set<String> excludedModels = const {},
    bool forceRefresh = false,
    bool strict = false,
  }) async {
    final now = DateTime.now().toUtc();
    if (forceRefresh ||
        _availableModels == null ||
        !(_availableModelsExpiresAt?.isAfter(now) ?? false)) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/v1beta/models',
          queryParameters: const {'pageSize': 100},
          options: Options(headers: {'x-goog-api-key': apiKey}),
        );
        final models = response.data?['models'] as List<dynamic>? ?? const [];
        _availableModels = models
            .whereType<Map<String, dynamic>>()
            .where((entry) {
              final methods = entry['supportedGenerationMethods'];
              return methods is List && methods.contains('generateContent');
            })
            .map((entry) => entry['name'] as String?)
            .whereType<String>()
            .map((name) => name.replaceFirst('models/', ''))
            .toSet();
        _availableModelsExpiresAt = now.add(const Duration(hours: 6));
      } on DioException catch (error) {
        final mapped = _geminiException(error);
        if (strict ||
            mapped.code == 'invalid_credentials' ||
            mapped.code == 'rate_limited') {
          throw mapped;
        }
      }
    }

    final available = _availableModels ?? const <String>{};
    for (final candidate in _modelCandidates(requestedModel)) {
      if (!excludedModels.contains(candidate) &&
          available.contains(candidate)) {
        return candidate;
      }
    }
    return null;
  }
}

enum _FallbackKind { none, permanent, transient }

_FallbackKind _fallbackKind(DioException error) {
  final statusCode = error.response?.statusCode;
  final apiStatus = _apiErrorField(error, 'status')?.toUpperCase();
  final message = _apiErrorField(error, 'message')?.toLowerCase() ?? '';
  if (statusCode == 404 || apiStatus == 'NOT_FOUND') {
    return _FallbackKind.permanent;
  }
  if (statusCode == 400 &&
      message.contains('model') &&
      (message.contains('not found') ||
          message.contains('not supported') ||
          message.contains('unavailable'))) {
    return _FallbackKind.permanent;
  }
  if (statusCode == 503 || apiStatus == 'UNAVAILABLE') {
    return _FallbackKind.transient;
  }
  return _FallbackKind.none;
}

IntegrationException _geminiException(DioException error) {
  final mapped = IntegrationException.fromDio('Gemini', error);
  if (mapped.code != 'rate_limited') return mapped;
  final retryAfter = mapped.retryAfter ?? _retryDelayFromBody(error);
  final safeDelay =
      retryAfter == null || retryAfter < const Duration(minutes: 1)
      ? const Duration(minutes: 1)
      : retryAfter;
  return IntegrationException(
    integration: 'Gemini',
    code: 'rate_limited',
    userMessage:
        'Gemini quota is busy. ClassSync will wait before trying again.',
    retryable: true,
    retryAfter: safeDelay,
    statusCode: mapped.statusCode,
  );
}

String? _apiErrorField(DioException error, String field) {
  final data = error.response?.data;
  if (data is! Map) return null;
  final payload = data['error'];
  if (payload is! Map) return null;
  return payload[field]?.toString();
}

Duration? _retryDelayFromBody(DioException error) {
  final data = error.response?.data;
  if (data is! Map || data['error'] is! Map) return null;
  final details = (data['error'] as Map)['details'];
  if (details is! List) return null;
  for (final detail in details.whereType<Map>()) {
    final value = detail['retryDelay']?.toString();
    final match = value == null
        ? null
        : RegExp(r'^(\d+(?:\.\d+)?)s$').firstMatch(value);
    if (match != null) {
      final seconds = double.parse(match.group(1)!);
      return Duration(milliseconds: (seconds * 1000).ceil());
    }
  }
  return null;
}

String _classificationSample(LectureTranscript transcript) {
  final sentences = transcript.sentences;
  if (sentences.length <= 120 &&
      transcript.plainText.length <= GeminiClient.maxClassificationCharacters) {
    return transcript.plainText;
  }
  final selected = <TranscriptSentence>[
    ...sentences.take(40),
    ...sentences.skip(max(0, sentences.length ~/ 2 - 20)).take(40),
    ...sentences.skip(max(0, sentences.length - 40)),
  ];
  final sample = selected
      .map(
        (sentence) => '${sentence.speakerName ?? 'Speaker'}: ${sentence.text}',
      )
      .join('\n');
  return _takeRunes(sample, GeminiClient.maxClassificationCharacters);
}

String _takeRunes(String value, int limit) {
  if (value.runes.length <= limit) return value;
  return String.fromCharCodes(value.runes.take(limit));
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
