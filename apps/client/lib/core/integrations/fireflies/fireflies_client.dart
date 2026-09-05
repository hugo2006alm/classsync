import 'package:dio/dio.dart';

import '../../../../domain/academic/academic_models.dart';
import '../integration_exception.dart';

class FirefliesTranscriptRef {
  const FirefliesTranscriptRef({
    required this.id,
    required this.title,
    required this.date,
    this.url,
  });

  final String id;
  final String title;
  final DateTime date;
  final String? url;
}

class FirefliesClient {
  FirefliesClient({Dio? dio})
    : _dio = dio ?? createDio(baseUrl: 'https://api.fireflies.ai/graphql');

  final Dio _dio;

  Future<void> testConnection(String apiKey) async {
    await _request(
      apiKey,
      'query CurrentUser { user { user_id email } }',
      const {},
    );
  }

  Future<List<FirefliesTranscriptRef>> listTranscripts({
    required String apiKey,
    required DateTime from,
  }) async {
    const query = r'''
      query ClassSyncTranscripts($fromDate: DateTime, $limit: Int, $skip: Int) {
        transcripts(fromDate: $fromDate, limit: $limit, skip: $skip, mine: true) {
          id
          title
          date
          dateString
          transcript_url
        }
      }
    ''';
    final items = <FirefliesTranscriptRef>[];
    var skip = 0;
    while (true) {
      final data = await _request(apiKey, query, {
        'fromDate': from.toUtc().toIso8601String(),
        'limit': 50,
        'skip': skip,
      });
      final page = (data['transcripts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      items.addAll(page.map(_refFromJson));
      if (page.length < 50) break;
      skip += page.length;
    }
    return items;
  }

  Future<LectureTranscript> fetchTranscript({
    required String apiKey,
    required String transcriptId,
  }) async {
    const query = r'''
      query ClassSyncTranscript($transcriptId: String!) {
        transcript(id: $transcriptId) {
          id
          title
          date
          dateString
          transcript_url
          participants
          sentences {
            speaker_name
            text
            raw_text
            start_time
            end_time
          }
        }
      }
    ''';
    final data = await _request(apiKey, query, {'transcriptId': transcriptId});
    final item = data['transcript'];
    if (item is! Map<String, dynamic>) {
      throw const IntegrationException(
        integration: 'Fireflies',
        code: 'transcript_not_ready',
        userMessage: 'Fireflies transcript is not ready yet.',
        retryable: true,
      );
    }
    final sentences = (item['sentences'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (sentence) => TranscriptSentence(
            text: (sentence['text'] ?? sentence['raw_text'] ?? '').toString(),
            speakerName: sentence['speaker_name'] as String?,
            startTimeSeconds: (sentence['start_time'] as num?)?.toDouble(),
            endTimeSeconds: (sentence['end_time'] as num?)?.toDouble(),
          ),
        )
        .where((sentence) => sentence.text.trim().isNotEmpty)
        .toList();
    if (sentences.isEmpty) {
      throw const IntegrationException(
        integration: 'Fireflies',
        code: 'transcript_not_ready',
        userMessage:
            'Fireflies returned an empty transcript. ClassSync will retry.',
        retryable: true,
      );
    }
    return LectureTranscript(
      firefliesId: item['id'] as String? ?? transcriptId,
      title: item['title'] as String? ?? 'Untitled lecture',
      date: _parseFirefliesDate(item),
      firefliesUrl: item['transcript_url'] as String?,
      participants: (item['participants'] as List<dynamic>? ?? const [])
          .map((participant) => participant.toString())
          .toList(),
      sentences: sentences,
    );
  }

  Future<Map<String, dynamic>> _request(
    String apiKey,
    String query,
    Map<String, dynamic> variables,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '',
        data: {'query': query, 'variables': variables},
        options: Options(headers: {'authorization': 'Bearer $apiKey'}),
      );
      final body = response.data ?? const <String, dynamic>{};
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first as Map?;
        final message = first?['message']?.toString() ?? '';
        final extensions = first?['extensions'] as Map?;
        final providerCode =
            extensions?['code']?.toString().toLowerCase() ?? '';
        final normalized = '$providerCode $message'.toLowerCase();
        final notReady =
            normalized.contains('not ready') ||
            normalized.contains('processing') ||
            normalized.contains('temporarily') ||
            normalized.contains('internal');
        final terminal =
            normalized.contains('auth') ||
            normalized.contains('permission') ||
            normalized.contains('forbidden') ||
            normalized.contains('not found') ||
            normalized.contains('invalid') ||
            normalized.contains('plan') ||
            normalized.contains('limit');
        throw IntegrationException(
          integration: 'Fireflies',
          code: terminal
              ? 'graphql_terminal'
              : notReady
              ? 'transcript_not_ready'
              : 'graphql_error',
          userMessage: terminal
              ? 'Fireflies rejected this request. Check access, plan, and transcript ID.'
              : notReady
              ? 'Fireflies has not finished this transcript yet.'
              : 'Fireflies returned an unexpected GraphQL error.',
          retryable: notReady,
        );
      }
      return (body['data'] as Map<String, dynamic>?) ?? const {};
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Fireflies', error);
    }
  }

  FirefliesTranscriptRef _refFromJson(Map<String, dynamic> json) =>
      FirefliesTranscriptRef(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled lecture',
        date: _parseFirefliesDate(json),
        url: json['transcript_url'] as String?,
      );
}

DateTime _parseFirefliesDate(Map<String, dynamic> json) {
  final milliseconds = json['date'];
  if (milliseconds is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds.round(),
      isUtc: true,
    );
  }
  final dateString = json['dateString'];
  if (dateString is String) {
    return DateTime.tryParse(dateString)?.toUtc() ?? DateTime.now().toUtc();
  }
  return DateTime.now().toUtc();
}
