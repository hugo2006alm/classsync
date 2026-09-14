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

class FirefliesIdentity {
  const FirefliesIdentity({
    required this.userId,
    required this.email,
    this.name,
  });

  final String userId;
  final String email;
  final String? name;
}

class FirefliesClient {
  FirefliesClient({Dio? dio})
    : _dio = dio ?? createDio(baseUrl: 'https://api.fireflies.ai');

  final Dio _dio;

  Future<FirefliesIdentity> testConnection(String apiKey) async {
    final data = await _request(
      apiKey,
      'query CurrentUser { user { user_id email name } }',
      const {},
    );
    final user = data['user'];
    if (user is! Map<String, dynamic> ||
        (user['user_id']?.toString().trim().isEmpty ?? true) ||
        (user['email']?.toString().trim().isEmpty ?? true)) {
      throw const IntegrationException(
        integration: 'Fireflies',
        code: 'identity_unavailable',
        userMessage: 'Fireflies did not return a stable account identity.',
        retryable: false,
      );
    }
    return FirefliesIdentity(
      userId: user['user_id'].toString().trim(),
      email: user['email'].toString().trim(),
      name: user['name']?.toString().trim(),
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
    final seenIds = <String>{};
    while (true) {
      final data = await _request(apiKey, query, {
        'fromDate': from.toUtc().toIso8601String(),
        'limit': 50,
        'skip': skip,
      });
      final page = (data['transcripts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final fresh = page
          .map(_refFromJson)
          .where((item) => seenIds.add(item.id))
          .toList();
      if ((page.isNotEmpty && fresh.isEmpty) || skip >= 5000) {
        throw const IntegrationException(
          integration: 'Fireflies',
          code: 'pagination_invalid',
          userMessage:
              'Fireflies pagination did not finish safely. The discovery cursor was retained.',
          retryable: true,
        );
      }
      items.addAll(fresh);
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
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const IntegrationException(
        integration: 'Fireflies',
        code: 'invalid_credentials',
        userMessage: 'Enter a Fireflies API key.',
        retryable: false,
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/graphql',
        data: {'query': query, 'variables': variables},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'authorization': 'Bearer $key',
            'accept': 'application/json',
          },
        ),
      );
      return _dataOrThrow(response.data ?? const <String, dynamic>{});
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) _throwGraphQl(errors);
      }
      throw IntegrationException.fromDio('Fireflies', error);
    }
  }

  Map<String, dynamic> _dataOrThrow(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) _throwGraphQl(errors);
    return (body['data'] as Map<String, dynamic>?) ?? const {};
  }

  Never _throwGraphQl(List<dynamic> errors) {
    final firstValue = errors.isEmpty ? null : errors.first;
    final first = firstValue is Map ? firstValue : null;
    final message = first?['message']?.toString().trim() ?? '';
    final extensions = first?['extensions'] as Map?;
    final providerCode = extensions?['code']?.toString().toLowerCase() ?? '';
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
    final shortened = message.length > 180
        ? '${message.substring(0, 180)}…'
        : message;
    final detail = shortened.isEmpty ? '' : ' Fireflies says: $shortened';
    throw IntegrationException(
      integration: 'Fireflies',
      code: terminal
          ? 'graphql_terminal'
          : notReady
          ? 'transcript_not_ready'
          : 'graphql_error',
      userMessage: terminal
          ? 'Fireflies rejected this request.$detail'
          : notReady
          ? 'Fireflies has not finished this transcript yet.$detail'
          : 'Fireflies returned a GraphQL error.$detail',
      retryable: notReady,
    );
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
