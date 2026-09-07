import 'dart:convert';

import 'package:dio/dio.dart';

const maxAcademicResponseBytes = 2 * 1024 * 1024;

class IntegrationPayloadTooLarge implements Exception {
  const IntegrationPayloadTooLarge(this.limit);

  final int limit;
}

Future<List<int>> readBoundedResponse(
  Object? data,
  Headers headers, {
  int limit = maxAcademicResponseBytes,
}) async {
  final declaredLength = int.tryParse(headers.value('content-length') ?? '');
  if (declaredLength != null && declaredLength > limit) {
    throw IntegrationPayloadTooLarge(limit);
  }

  if (data == null) return const [];
  if (data is String) return _bounded(utf8.encode(data), limit);
  if (data is List<int>) return _bounded(data, limit);
  if (data is Map || data is List) {
    return _bounded(utf8.encode(jsonEncode(data)), limit);
  }
  if (data is ResponseBody) {
    final bytes = <int>[];
    await for (final chunk in data.stream) {
      if (bytes.length + chunk.length > limit) {
        throw IntegrationPayloadTooLarge(limit);
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }
  throw const FormatException('Unsupported HTTP response body.');
}

List<int> _bounded(List<int> bytes, int limit) {
  if (bytes.length > limit) throw IntegrationPayloadTooLarge(limit);
  return bytes;
}
