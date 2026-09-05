import 'dart:io';

import 'package:dio/dio.dart';

class IntegrationException implements Exception {
  const IntegrationException({
    required this.integration,
    required this.code,
    required this.userMessage,
    required this.retryable,
    this.retryAfter,
    this.statusCode,
  });

  final String integration;
  final String code;
  final String userMessage;
  final bool retryable;
  final Duration? retryAfter;
  final int? statusCode;

  @override
  String toString() => '$integration:$code: $userMessage';

  static IntegrationException fromDio(String integration, DioException error) {
    final status = error.response?.statusCode;
    final retryAfterHeader = error.response?.headers.value('retry-after');
    final retryAfter = _parseRetryAfter(retryAfterHeader);
    if (status == 401 || status == 403) {
      return IntegrationException(
        integration: integration,
        code: 'invalid_credentials',
        userMessage:
            '$integration refused access. Check its credentials and permissions.',
        retryable: false,
        statusCode: status,
      );
    }
    if (status == 400 || status == 404) {
      return IntegrationException(
        integration: integration,
        code: 'invalid_configuration',
        userMessage:
            '$integration configuration or resource mapping is invalid.',
        retryable: false,
        statusCode: status,
      );
    }
    if (status == 429) {
      return IntegrationException(
        integration: integration,
        code: 'rate_limited',
        userMessage:
            '$integration is rate limiting ClassSync. It will retry later.',
        retryable: true,
        retryAfter: retryAfter,
        statusCode: status,
      );
    }
    final retryable = status == null || status >= 500;
    return IntegrationException(
      integration: integration,
      code: switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => 'timeout',
        DioExceptionType.connectionError => 'offline',
        _ => 'request_failed',
      },
      userMessage: retryable
          ? '$integration is temporarily unavailable.'
          : '$integration rejected the request.',
      retryable: retryable,
      statusCode: status,
    );
  }
}

Duration? _parseRetryAfter(String? value) {
  if (value == null) return null;
  final seconds = int.tryParse(value.trim());
  if (seconds != null) return Duration(seconds: seconds.clamp(0, 86400));
  try {
    final target = HttpDate.parse(value).toUtc();
    final delay = target.difference(DateTime.now().toUtc());
    return delay.isNegative
        ? Duration.zero
        : Duration(seconds: delay.inSeconds.clamp(0, 86400));
  } on FormatException {
    return null;
  }
}

Dio createDio({String? baseUrl}) => Dio(
  BaseOptions(
    baseUrl: baseUrl ?? '',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 90),
    sendTimeout: const Duration(seconds: 90),
    responseType: ResponseType.json,
    headers: const {'accept': 'application/json'},
  ),
);
