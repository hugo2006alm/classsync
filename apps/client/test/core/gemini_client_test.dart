import 'dart:convert';

import 'package:classsync/core/integrations/gemini/gemini_client.dart';
import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'connection test uses model catalogue without generating tokens',
    () async {
      final requests = <RequestOptions>[];
      final client = GeminiClient(
        dio: _stubDio((options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'models': [
                  {
                    'name': 'models/gemini-3.7-flash',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
              },
            ),
          );
        }),
      );

      final selected = await client.testConnection(
        apiKey: 'test-key',
        model: 'gemini-3.8-flash',
      );

      expect(selected, 'gemini-3.7-flash');
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/v1beta/models');
      expect(requests.single.headers['x-goog-api-key'], 'test-key');
      expect(requests.single.uri.queryParameters, isNot(contains('key')));
    },
  );

  test(
    'temporarily unavailable model falls back once and caches success',
    () async {
      final paths = <String>[];
      final client = GeminiClient(
        dio: _stubDio((options, handler) {
          paths.add(options.path);
          expect(options.headers['x-goog-api-key'], 'test-key');
          expect(options.uri.queryParameters, isNot(contains('key')));
          if (options.path.contains('gemini-3.8-flash')) {
            handler.reject(
              _apiError(options, 503, 'UNAVAILABLE', 'Overloaded'),
            );
            return;
          }
          final body = options.data as Map<String, dynamic>;
          final config = body['generationConfig'] as Map<String, dynamic>;
          expect(config, isNot(contains('temperature')));
          handler.resolve(_classificationResponse(options));
        }),
      );

      await client.classify(
        apiKey: 'test-key',
        model: 'gemini-3.8-flash',
        transcript: _transcript,
        subjects: [_subject],
      );
      await client.classify(
        apiKey: 'test-key',
        model: 'gemini-3.8-flash',
        transcript: _transcript,
        subjects: [_subject],
      );

      expect(paths, [
        '/v1beta/models/gemini-3.8-flash:generateContent',
        '/v1beta/models/gemini-3.7-flash:generateContent',
        '/v1beta/models/gemini-3.7-flash:generateContent',
      ]);
    },
  );

  test('retired model discovery selects the best listed fallback', () async {
    final paths = <String>[];
    final client = GeminiClient(
      dio: _stubDio((options, handler) {
        paths.add(options.path);
        if (options.method == 'GET') {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'models': [
                  {
                    'name': 'models/gemini-3.6-flash',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
              },
            ),
          );
          return;
        }
        if (options.path.contains('gemini-3.8-flash')) {
          handler.reject(
            _apiError(options, 404, 'NOT_FOUND', 'Model not found'),
          );
          return;
        }
        handler.resolve(_classificationResponse(options));
      }),
    );

    await client.classify(
      apiKey: 'test-key',
      model: 'gemini-3.8-flash',
      transcript: _transcript,
      subjects: [_subject],
    );

    expect(paths, [
      '/v1beta/models/gemini-3.8-flash:generateContent',
      '/v1beta/models',
      '/v1beta/models/gemini-3.6-flash:generateContent',
    ]);
  });

  test(
    'quota response does not try another model and enforces cooldown',
    () async {
      var requestCount = 0;
      final client = GeminiClient(
        dio: _stubDio((options, handler) {
          requestCount += 1;
          handler.reject(
            _apiError(
              options,
              429,
              'RESOURCE_EXHAUSTED',
              'Quota exceeded',
              details: [
                {
                  '@type': 'type.googleapis.com/google.rpc.RetryInfo',
                  'retryDelay': '5s',
                },
              ],
            ),
          );
        }),
      );

      await expectLater(
        client.classify(
          apiKey: 'test-key',
          model: 'gemini-3.8-flash',
          transcript: _transcript,
          subjects: [_subject],
        ),
        throwsA(
          isA<IntegrationException>()
              .having((error) => error.code, 'code', 'rate_limited')
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(minutes: 1),
              ),
        ),
      );
      expect(requestCount, 1);
    },
  );
}

Dio _stubDio(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://generativelanguage.googleapis.com'),
  );
  dio.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return dio;
}

DioException _apiError(
  RequestOptions options,
  int statusCode,
  String status,
  String message, {
  List<Map<String, dynamic>> details = const [],
}) => DioException(
  requestOptions: options,
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: options,
    statusCode: statusCode,
    data: {
      'error': {
        'code': statusCode,
        'status': status,
        'message': message,
        'details': details,
      },
    },
  ),
);

Response<Map<String, dynamic>> _classificationResponse(
  RequestOptions options,
) => Response<Map<String, dynamic>>(
  requestOptions: options,
  statusCode: 200,
  data: {
    'candidates': [
      {
        'content': {
          'parts': [
            {
              'text': jsonEncode({
                'decision': 'match',
                'subjectId': _subject.notionId,
                'subjectName': _subject.name,
                'confidence': 0.9,
                'candidates': [
                  {
                    'subjectId': _subject.notionId,
                    'subjectName': _subject.name,
                    'confidence': 0.9,
                  },
                ],
                'reasoningSummary': ['Matched lecture title'],
                'suggestedLectureTitle': null,
              }),
            },
          ],
        },
      },
    ],
  },
);

final _subject = AcademicSubject(
  notionId: 'subject-1',
  name: 'Artificial Intelligence',
  year: '3',
  semester: '1',
  status: 'In progress',
  lastSyncedAt: DateTime.utc(2026, 9, 5),
);

final _transcript = LectureTranscript(
  firefliesId: 'meeting-1',
  title: 'Search algorithms',
  date: DateTime.utc(2026, 9, 5),
  sentences: const [TranscriptSentence(text: 'Today we compare BFS and A*.')],
);
