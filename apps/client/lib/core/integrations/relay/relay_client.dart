import 'package:dio/dio.dart';

import '../integration_exception.dart';

class RelayEvent {
  const RelayEvent({
    required this.id,
    required this.firefliesTranscriptId,
    required this.eventType,
    required this.receivedAt,
  });

  final String id;
  final String firefliesTranscriptId;
  final String eventType;
  final DateTime receivedAt;
}

class RelayClient {
  RelayClient({Dio? dio}) : _dio = dio ?? createDio();

  final Dio _dio;

  Future<void> testConnection(String baseUrl) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${_base(baseUrl)}/health',
      );
      if (response.data?['status'] != 'ok') {
        throw const IntegrationException(
          integration: 'ClassSync Relay',
          code: 'unhealthy',
          userMessage: 'ClassSync Relay health check failed.',
          retryable: true,
        );
      }
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  Future<List<RelayEvent>> pendingEvents({
    required String baseUrl,
    required String token,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${_base(baseUrl)}/events',
        options: Options(headers: {'authorization': 'Bearer $token'}),
      );
      return (response.data?['events'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (event) => RelayEvent(
              id: event['id'] as String,
              firefliesTranscriptId: event['fireflies_transcript_id'] as String,
              eventType: event['event_type'] as String,
              receivedAt: DateTime.parse(
                event['received_at'] as String,
              ).toUtc(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  Future<void> acknowledge({
    required String baseUrl,
    required String token,
    required String eventId,
  }) async {
    try {
      await _dio.post<void>(
        '${_base(baseUrl)}/events/${Uri.encodeComponent(eventId)}/ack',
        options: Options(headers: {'authorization': 'Bearer $token'}),
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  Future<void> registerPushToken({
    required String baseUrl,
    required String deviceToken,
    required String pushToken,
  }) async {
    try {
      await _dio.post<void>(
        '${_base(baseUrl)}/devices/register',
        data: {'pushToken': pushToken, 'platform': 'android'},
        options: Options(headers: {'authorization': 'Bearer $deviceToken'}),
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  Future<void> unregisterPushToken({
    required String baseUrl,
    required String deviceToken,
    required String pushToken,
  }) async {
    try {
      await _dio.delete<void>(
        '${_base(baseUrl)}/devices/register',
        data: {'pushToken': pushToken, 'platform': 'android'},
        options: Options(headers: {'authorization': 'Bearer $deviceToken'}),
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  String _base(String value) => value.trim().replaceFirst(RegExp(r'/+$'), '');
}
