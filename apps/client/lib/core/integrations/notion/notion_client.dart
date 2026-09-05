import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../domain/academic/academic_models.dart';
import '../integration_exception.dart';

class NotionDataSource {
  const NotionDataSource({required this.id, required this.name});
  final String id;
  final String name;
}

class NotionPageRef {
  const NotionPageRef({required this.id, this.url});
  final String id;
  final String? url;
}

class NotionClient {
  NotionClient({Dio? dio})
    : _dio = dio ?? createDio(baseUrl: 'https://api.notion.com/v1');

  static const apiVersion = '2026-03-11';
  final Dio _dio;

  Options _options(String token) => Options(
    headers: {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'notion-version': apiVersion,
    },
  );

  Future<void> testConnection(String token) async {
    try {
      await _dio.get<void>('/users/me', options: _options(token));
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  Future<List<NotionDataSource>> searchDataSources({
    required String token,
    String query = '',
  }) async {
    final results = <NotionDataSource>[];
    String? cursor;
    do {
      final body = <String, dynamic>{
        'page_size': 100,
        'filter': {'property': 'object', 'value': 'data_source'},
        if (query.trim().isNotEmpty) 'query': query.trim(),
        'start_cursor': ?cursor,
      };
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/search',
          data: body,
          options: _options(token),
        );
        final data = response.data ?? const {};
        results.addAll(
          (data['results'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => NotionDataSource(
                  id: item['id'] as String,
                  name: _richText(item['title']) ?? 'Untitled data source',
                ),
              ),
        );
        cursor = data['has_more'] == true
            ? data['next_cursor'] as String?
            : null;
      } on DioException catch (error) {
        throw IntegrationException.fromDio('Notion', error);
      }
    } while (cursor != null);
    return results;
  }

  Future<List<AcademicSubject>> queryActiveSubjects({
    required String token,
    required String dataSourceId,
  }) async {
    final results = <AcademicSubject>[];
    String? cursor;
    do {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/data_sources/${Uri.encodeComponent(dataSourceId)}/query',
          data: {
            'page_size': 100,
            'filter': {
              'property': 'Status',
              'status': {'equals': 'In progress'},
            },
            'start_cursor': ?cursor,
          },
          options: _options(token),
        );
        final data = response.data ?? const {};
        results.addAll(
          (data['results'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(subjectFromPage),
        );
        cursor = data['has_more'] == true
            ? data['next_cursor'] as String?
            : null;
      } on DioException catch (error) {
        throw IntegrationException.fromDio('Notion', error);
      }
    } while (cursor != null);
    return results;
  }

  Future<void> addFirefliesIdProperty({
    required String token,
    required String summariesDataSourceId,
  }) async {
    try {
      await _dio.patch<void>(
        '/data_sources/${Uri.encodeComponent(summariesDataSourceId)}',
        data: {
          'properties': {
            'Fireflies ID': {'rich_text': {}},
          },
        },
        options: _options(token),
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  Future<NotionPageRef?> findSummaryByFirefliesId({
    required String token,
    required String dataSourceId,
    required String firefliesId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/data_sources/${Uri.encodeComponent(dataSourceId)}/query',
        data: {
          'page_size': 1,
          'filter': {
            'property': 'Fireflies ID',
            'rich_text': {'equals': firefliesId},
          },
        },
        options: _options(token),
      );
      final results = response.data?['results'] as List<dynamic>? ?? const [];
      if (results.isEmpty) return null;
      final page = results.first as Map<String, dynamic>;
      return NotionPageRef(
        id: page['id'] as String,
        url: page['url'] as String?,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  Future<NotionPageRef> createSummaryPage({
    required String token,
    required String dataSourceId,
    required String firefliesId,
    required DateTime lectureDate,
    required String subjectId,
    required LectureSummary summary,
    required bool includeMetadata,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/pages',
        data: {
          'parent': {'type': 'data_source_id', 'data_source_id': dataSourceId},
          'properties': _summaryProperties(
            firefliesId: firefliesId,
            lectureDate: lectureDate,
            subjectId: subjectId,
            summary: summary,
            includeMetadata: includeMetadata,
          ),
        },
        options: _options(token),
      );
      final page = response.data ?? const {};
      return NotionPageRef(
        id: page['id'] as String,
        url: page['url'] as String?,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  Future<void> replaceSummaryPage({
    required String token,
    required String pageId,
    required String firefliesId,
    required DateTime lectureDate,
    required String subjectId,
    required LectureSummary summary,
    required String? firefliesUrl,
    required bool includeMetadata,
  }) async {
    try {
      await _dio.patch<void>(
        '/pages/${Uri.encodeComponent(pageId)}',
        data: {
          'properties': _summaryProperties(
            firefliesId: firefliesId,
            lectureDate: lectureDate,
            subjectId: subjectId,
            summary: summary,
            includeMetadata: includeMetadata,
          ),
        },
        options: _options(token),
      );
      final childIds = await _childIds(token: token, pageId: pageId);
      for (final childId in childIds) {
        await _dio.delete<void>(
          '/blocks/${Uri.encodeComponent(childId)}',
          options: _options(token),
        );
      }
      await ensureSummaryContent(
        token: token,
        pageId: pageId,
        summary: summary,
        lectureDate: lectureDate,
        firefliesUrl: firefliesUrl,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  /// Completes a page body without duplicating a chunk after a lost response.
  ///
  /// The page is created empty, so its current top-level child count is a
  /// durable remote checkpoint. Each retry resumes at that count.
  Future<void> ensureSummaryContent({
    required String token,
    required String pageId,
    required LectureSummary summary,
    required DateTime lectureDate,
    required String? firefliesUrl,
  }) async {
    final blocks = _summaryBlocks(
      summary: summary,
      lectureDate: lectureDate,
      firefliesUrl: firefliesUrl,
    );
    try {
      var offset = await _childCount(token: token, pageId: pageId);
      while (offset < blocks.length) {
        await _dio.patch<void>(
          '/blocks/${Uri.encodeComponent(pageId)}/children',
          data: {
            'position': {'type': 'end'},
            'children': blocks.skip(offset).take(100).toList(),
          },
          options: _options(token),
        );
        // Re-read the remote checkpoint. If the response was lost after Notion
        // committed the append, the next retry observes the committed blocks.
        offset = await _childCount(token: token, pageId: pageId);
      }
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  Future<int> _childCount({
    required String token,
    required String pageId,
  }) async {
    var count = 0;
    String? cursor;
    do {
      final response = await _dio.get<Map<String, dynamic>>(
        '/blocks/${Uri.encodeComponent(pageId)}/children',
        queryParameters: {'page_size': 100, 'start_cursor': ?cursor},
        options: _options(token),
      );
      final data = response.data ?? const {};
      count += (data['results'] as List<dynamic>? ?? const []).length;
      cursor = data['has_more'] == true ? data['next_cursor'] as String? : null;
    } while (cursor != null);
    return count;
  }

  Future<List<String>> _childIds({
    required String token,
    required String pageId,
  }) async {
    final ids = <String>[];
    String? cursor;
    do {
      final response = await _dio.get<Map<String, dynamic>>(
        '/blocks/${Uri.encodeComponent(pageId)}/children',
        queryParameters: {'page_size': 100, 'start_cursor': ?cursor},
        options: _options(token),
      );
      final data = response.data ?? const {};
      ids.addAll(
        (data['results'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((block) => block['id'] as String),
      );
      cursor = data['has_more'] == true ? data['next_cursor'] as String? : null;
    } while (cursor != null);
    return ids;
  }

  AcademicSubject subjectFromPage(Map<String, dynamic> page) {
    final properties = page['properties'] as Map<String, dynamic>? ?? const {};
    return AcademicSubject(
      notionId: page['id'] as String,
      name:
          _propertyText(properties['Nome']) ??
          _propertyText(properties['Name']) ??
          'Unnamed class',
      year: _propertyText(properties['Ano']) ?? '',
      semester: _propertyText(properties['Semestre']) ?? '',
      status: _propertyText(properties['Status']) ?? '',
      notionUrl: page['url'] as String?,
      aliases: _propertyStringList(properties['Aliases']),
      professors: _propertyStringList(properties['Professores']),
      scheduleHints: _propertyStringList(properties['Horário']),
      lastSyncedAt: DateTime.now().toUtc(),
    );
  }
}

Map<String, dynamic> _summaryProperties({
  required String firefliesId,
  required DateTime lectureDate,
  required String subjectId,
  required LectureSummary summary,
  required bool includeMetadata,
}) => {
  'Nome': {
    'title': [_text(summary.title)],
  },
  'Data': {
    'date': {'start': lectureDate.toUtc().toIso8601String()},
  },
  'Cadeira': {
    'relation': [
      {'id': subjectId},
    ],
  },
  if (includeMetadata)
    'Fireflies ID': {
      'rich_text': [_text(firefliesId)],
    },
};

List<Map<String, dynamic>> _summaryBlocks({
  required LectureSummary summary,
  required DateTime lectureDate,
  required String? firefliesUrl,
}) {
  final blocks = <Map<String, dynamic>>[
    _heading('Contexto e Objetivos da Aula', level: 1),
    ..._paragraphs(summary.context),
    ...summary.objectives.map(_bullet),
  ];
  for (final section in summary.sections) {
    blocks.add(_heading(section.title, level: 2));
    blocks.addAll(_paragraphs(section.content));
    blocks.addAll(section.keyPoints.map(_bullet));
    for (final example in section.examples) {
      blocks.add(_callout('Exemplo: $example', '💡'));
    }
    for (final formula in section.formulas) {
      blocks.add(_equation(formula));
    }
    for (final code in section.code) {
      for (final segment in _splitText(code, 1900)) {
        blocks.add(_code(segment));
      }
    }
  }
  if (summary.examHints.isNotEmpty) {
    blocks.add(_heading('Pistas para avaliação', level: 2));
    blocks.addAll(summary.examHints.map((hint) => _callout(hint, '🎯')));
  }
  if (summary.uncertainties.isNotEmpty) {
    blocks.add(_heading('Incertezas da transcrição', level: 2));
    blocks.addAll(
      summary.uncertainties.map((uncertainty) => _callout(uncertainty, '⚠️')),
    );
  }
  blocks
    ..add(_heading('Conclusões e Pontos-Chave', level: 1))
    ..addAll(summary.conclusions.map(_bullet))
    ..add({'object': 'block', 'type': 'divider', 'divider': {}})
    ..add(
      _paragraph(
        'Source: Fireflies · Lecture date: ${lectureDate.toLocal().toIso8601String().split('T').first}',
        url: firefliesUrl,
      ),
    );
  return blocks;
}

Map<String, dynamic> _heading(String value, {required int level}) {
  final type = 'heading_$level';
  return {
    'object': 'block',
    'type': type,
    type: {
      'rich_text': [_text(value)],
    },
  };
}

List<Map<String, dynamic>> _paragraphs(String value) =>
    _splitText(value, 1900).map((segment) => _paragraph(segment)).toList();

Map<String, dynamic> _paragraph(String value, {String? url}) => {
  'object': 'block',
  'type': 'paragraph',
  'paragraph': {
    'rich_text': [if (url == null) _text(value) else _text(value, url: url)],
  },
};

Map<String, dynamic> _bullet(String value) => {
  'object': 'block',
  'type': 'bulleted_list_item',
  'bulleted_list_item': {
    'rich_text': [_text(value)],
  },
};

Map<String, dynamic> _callout(String value, String emoji) => {
  'object': 'block',
  'type': 'callout',
  'callout': {
    'icon': {'type': 'emoji', 'emoji': emoji},
    'rich_text': [_text(value)],
  },
};

Map<String, dynamic> _equation(String value) => {
  'object': 'block',
  'type': 'equation',
  'equation': {'expression': value.substring(0, min(value.length, 1000))},
};

Map<String, dynamic> _code(String value) => {
  'object': 'block',
  'type': 'code',
  'code': {
    'language': 'plain text',
    'rich_text': [_text(value)],
  },
};

Map<String, dynamic> _text(String value, {String? url}) => {
  'type': 'text',
  'text': {
    'content': value.substring(0, min(value.length, 2000)),
    if (url != null) 'link': {'url': url},
  },
};

List<String> _splitText(String input, int maxLength) {
  final normalized = input.trim();
  if (normalized.isEmpty) return const [];
  final output = <String>[];
  var remaining = normalized;
  while (remaining.length > maxLength) {
    var split = remaining.lastIndexOf('\n', maxLength);
    if (split < maxLength ~/ 2) split = remaining.lastIndexOf(' ', maxLength);
    if (split < 1) split = maxLength;
    output.add(remaining.substring(0, split).trim());
    remaining = remaining.substring(split).trimLeft();
  }
  if (remaining.isNotEmpty) output.add(remaining);
  return output;
}

String? _propertyText(dynamic property) {
  if (property is! Map<String, dynamic>) return null;
  final type = property['type'];
  return switch (type) {
    'title' => _richText(property['title']),
    'rich_text' => _richText(property['rich_text']),
    'select' => (property['select'] as Map?)?['name']?.toString(),
    'status' => (property['status'] as Map?)?['name']?.toString(),
    'formula' => _formulaText(property['formula']),
    'number' => property['number']?.toString(),
    _ => null,
  };
}

String? _formulaText(dynamic formula) {
  if (formula is! Map) return null;
  return formula['string']?.toString() ?? formula['number']?.toString();
}

List<String> _propertyStringList(dynamic property) {
  if (property is! Map<String, dynamic>) return const [];
  if (property['type'] == 'multi_select') {
    return (property['multi_select'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => item['name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }
  final text = _propertyText(property);
  if (text == null || text.trim().isEmpty) return const [];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _richText(dynamic richText) {
  if (richText is! List) return null;
  final value = richText
      .whereType<Map<String, dynamic>>()
      .map((item) => item['plain_text']?.toString() ?? '')
      .join();
  return value.isEmpty ? null : value;
}
