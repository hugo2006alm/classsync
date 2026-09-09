import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../security/secure_credential_store.dart';
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

  Future<void> testConnection(String baseUrl, {required String token}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${_base(baseUrl)}/session',
        options: Options(headers: {'authorization': 'Bearer $token'}),
      );
      if (response.data?['protocolVersion'] != 2) {
        throw const IntegrationException(
          integration: 'ClassSync Relay',
          code: 'protocol_mismatch',
          userMessage: 'This relay does not support the required protocol.',
          retryable: false,
        );
      }
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  Future<String> ensureDeviceSession({
    required String baseUrl,
    required String bootstrapToken,
    required SecureCredentialStore credentials,
  }) async {
    final accountValues = await Future.wait([
      credentials.read(CredentialKey.syncAccountId),
      credentials.read(CredentialKey.syncAccountAuthSecret),
      credentials.read(CredentialKey.syncDeviceId),
    ]);
    if (accountValues.every((value) => value?.isNotEmpty == true)) {
      return 'account:${accountValues[0]}.${accountValues[1]}.${accountValues[2]}';
    }
    final existing = await credentials.read(
      CredentialKey.relayDeviceCredential,
    );
    if (existing?.isNotEmpty == true) return existing!;
    const uuid = Uuid();
    final deviceId = uuid.v4();
    final random = Random.secure();
    final secret = base64UrlEncode(
      List<int>.generate(48, (_) => random.nextInt(256)),
    );
    try {
      await _dio.post<void>(
        '${_base(baseUrl)}/devices/enroll',
        data: {'deviceId': deviceId, 'credential': secret},
        options: Options(headers: {'authorization': 'Bearer $bootstrapToken'}),
      );
      final session = '$deviceId.$secret';
      await credentials.write(CredentialKey.relayDeviceCredential, session);
      return session;
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
        '${_base(baseUrl)}${_path(token, '/events', '/account/events')}',
        options: Options(headers: _sessionHeaders(token)),
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
        '${_base(baseUrl)}${_path(token, '/events', '/account/events')}/${Uri.encodeComponent(eventId)}/ack',
        options: Options(headers: _sessionHeaders(token)),
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
        '${_base(baseUrl)}${_path(deviceToken, '/devices/register', '/account/devices/register')}',
        data: {'pushToken': pushToken, 'platform': 'android'},
        options: Options(headers: _sessionHeaders(deviceToken)),
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
        '${_base(baseUrl)}${_path(deviceToken, '/devices/register', '/account/devices/register')}',
        data: {'pushToken': pushToken, 'platform': 'android'},
        options: Options(headers: _sessionHeaders(deviceToken)),
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  Future<RelayClaim> claim({
    required String baseUrl,
    required String token,
    required String firefliesId,
    String? reprocessPageId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${_base(baseUrl)}${_path(token, '/claims', '/account/claims')}/${Uri.encodeComponent(firefliesId)}',
        options: Options(
          headers: {
            ..._sessionHeaders(token),
            'x-classsync-reprocess-page-id': ?reprocessPageId,
          },
        ),
      );
      return RelayClaim(
        acquired: response.data?['acquired'] == true,
        completed: response.data?['completed'] == true,
        notionPageId: response.data?['notionPageId'] as String?,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  Future<void> completeClaim({
    required String baseUrl,
    required String token,
    required String firefliesId,
    required String notionPageId,
  }) async {
    try {
      await _dio.post<void>(
        '${_base(baseUrl)}${_path(token, '/claims', '/account/claims')}/${Uri.encodeComponent(firefliesId)}/complete',
        data: {'notionPageId': notionPageId},
        options: Options(headers: _sessionHeaders(token)),
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  Future<void> revokeDevice({
    required String baseUrl,
    required String token,
  }) async {
    try {
      await _dio.delete<void>(
        '${_base(baseUrl)}/session',
        options: Options(headers: _deviceHeaders(token)),
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ClassSync Relay', error);
    }
  }

  String _base(String value) => value.trim().replaceFirst(RegExp(r'/+$'), '');

  String _path(String session, String legacy, String account) =>
      session.startsWith('account:') ? account : legacy;

  Map<String, String> _sessionHeaders(String session) =>
      session.startsWith('account:')
      ? _accountHeaders(session)
      : _deviceHeaders(session);

  Map<String, String> _accountHeaders(String session) {
    final parts = session.substring('account:'.length).split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw const IntegrationException(
        integration: 'ClassSync Relay',
        code: 'account_not_connected',
        userMessage: 'Reconnect this device to your ClassSync account.',
        retryable: false,
      );
    }
    return {
      'authorization': 'Bearer ${parts[1]}',
      'x-classsync-account-id': parts[0],
      'x-classsync-device-id': parts[2],
    };
  }

  Map<String, String> _deviceHeaders(String session) {
    final separator = session.indexOf('.');
    if (separator < 1 || separator == session.length - 1) {
      throw const IntegrationException(
        integration: 'ClassSync Relay',
        code: 'device_not_enrolled',
        userMessage: 'This device must be enrolled with the relay again.',
        retryable: false,
      );
    }
    return {
      'authorization': 'Bearer ${session.substring(separator + 1)}',
      'x-classsync-device-id': session.substring(0, separator),
    };
  }
}

class RelayClaim {
  const RelayClaim({
    required this.acquired,
    required this.completed,
    this.notionPageId,
  });
  final bool acquired;
  final bool completed;
  final String? notionPageId;
}
