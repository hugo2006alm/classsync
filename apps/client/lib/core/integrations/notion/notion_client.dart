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

  Future<void> validateDataSources({
    required String token,
    required String subjectsDataSourceId,
    required String summariesDataSourceId,
    required bool metadataEnabled,
  }) async {
    try {
      final responses = await Future.wait([
        _dio.get<Map<String, dynamic>>(
          '/data_sources/${Uri.encodeComponent(subjectsDataSourceId)}',
          options: _options(token),
        ),
        _dio.get<Map<String, dynamic>>(
          '/data_sources/${Uri.encodeComponent(summariesDataSourceId)}',
          options: _options(token),
        ),
      ]);
      final subjects =
          responses[0].data?['properties'] as Map<String, dynamic>? ?? const {};
      final summaries =
          responses[1].data?['properties'] as Map<String, dynamic>? ?? const {};
      final problems = <String>[];
      if (!_hasType(subjects, const ['Nome', 'Name'], 'title')) {
        problems.add('subjects: Nome/Name must be a title property');
      }
      if (!_hasType(subjects, const ['Status'], 'status')) {
        problems.add('subjects: Status must be a status property');
      }
      for (final entry in const {
        'Nome': 'title',
        'Data': 'date',
        'Cadeira': 'relation',
      }.entries) {
        if (!_hasType(summaries, [entry.key], entry.value)) {
          problems.add('summaries: ${entry.key} must be ${entry.value}');
        }
      }
      final relation = summaries['Cadeira'] as Map<String, dynamic>?;
      final relationConfig = relation?['relation'] as Map<String, dynamic>?;
      final relationTarget = relationConfig?['data_source_id']?.toString();
      if (relationTarget != null && relationTarget != subjectsDataSourceId) {
        problems.add('summaries: Cadeira relation targets wrong data source');
      }
      if (metadataEnabled &&
          summaries.containsKey('Fireflies ID') &&
          !_hasType(summaries, const ['Fireflies ID'], 'rich_text')) {
        problems.add('summaries: Fireflies ID must be rich_text');
      }
      if (problems.isNotEmpty) {
        throw IntegrationException(
          integration: 'Notion',
          code: 'schema_mismatch',
          userMessage: 'Notion schema mismatch: ${problems.join('; ')}.',
          retryable: false,
        );
      }
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
    _validateMetadata(firefliesId: firefliesId, summary: summary);
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
    _validateMetadata(firefliesId: firefliesId, summary: summary);
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
      await ensureSummaryContent(
        token: token,
        pageId: pageId,
        summary: summary,
        lectureDate: lectureDate,
        firefliesUrl: firefliesUrl,
      );
      final revision = _contentRevision(summary, lectureDate, firefliesUrl);
      final children = await _children(token: token, pageId: pageId);
      for (final block in children) {
        final marker = _ownedMarker(block);
        if (marker == null || marker.revision == revision) continue;
        await _dio.delete<void>(
          '/blocks/${Uri.encodeComponent(block['id'] as String)}',
          options: _options(token),
        );
      }
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  /// Completes only the ClassSync-owned page section. User and template blocks
  /// are never treated as checkpoints and are never mutated.
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
    final revision = _contentRevision(summary, lectureDate, firefliesUrl);
    try {
      final children = await _children(token: token, pageId: pageId);
      final completed = children
          .map(_ownedMarker)
          .whereType<_OwnedMarker>()
          .where((marker) => marker.revision == revision)
          .map((marker) => marker.chunk)
          .toSet();
      final chunks = <List<Map<String, dynamic>>>[];
      for (var offset = 0; offset < blocks.length; offset += 99) {
        chunks.add(blocks.skip(offset).take(99).toList());
      }
      for (var index = 0; index < chunks.length; index += 1) {
        if (completed.contains(index)) continue;
        await _dio.patch<void>(
          '/blocks/${Uri.encodeComponent(pageId)}/children',
          data: {
            'position': {'type': 'end'},
            'children': [
              {
                'object': 'block',
                'type': 'toggle',
                'toggle': {
                  'rich_text': [
                    _text(
                      'ClassSync generated · $revision · ${index + 1}/${chunks.length}',
                    ),
                  ],
                  'children': chunks[index],
                },
              },
            ],
          },
          options: _options(token),
        );
      }
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  Future<List<Map<String, dynamic>>> _children({
    required String token,
    required String pageId,
  }) async {
    final blocks = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final response = await _dio.get<Map<String, dynamic>>(
        '/blocks/${Uri.encodeComponent(pageId)}/children',
        queryParameters: {'page_size': 100, 'start_cursor': ?cursor},
        options: _options(token),
      );
      final data = response.data ?? const {};
      blocks.addAll(
        (data['results'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>(),
      );
      cursor = data['has_more'] == true ? data['next_cursor'] as String? : null;
    } while (cursor != null);
    return blocks;
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

  List<Map<String, dynamic>> renderSummaryBlocks({
    required LectureSummary summary,
    required DateTime lectureDate,
    String? firefliesUrl,
  }) => _summaryBlocks(
    summary: summary,
    lectureDate: lectureDate,
    firefliesUrl: firefliesUrl,
  );
}

bool _hasType(
  Map<String, dynamic> properties,
  List<String> names,
  String type,
) => names.any((name) {
  final property = properties[name];
  return property is Map<String, dynamic> && property['type'] == type;
});

class _OwnedMarker {
  const _OwnedMarker(this.revision, this.chunk);
  final String revision;
  final int chunk;
}

_OwnedMarker? _ownedMarker(Map<String, dynamic> block) {
  if (block['type'] != 'toggle') return null;
  final toggle = block['toggle'] as Map<String, dynamic>?;
  final text = _richText(toggle?['rich_text']);
  if (text == null) return null;
  final match = RegExp(
    r'^ClassSync generated · ([0-9a-f]{16}) · (\d+)\/\d+$',
  ).firstMatch(text);
  if (match == null) return null;
  return _OwnedMarker(match.group(1)!, int.parse(match.group(2)!) - 1);
}

String _contentRevision(
  LectureSummary summary,
  DateTime lectureDate,
  String? firefliesUrl,
) {
  final value =
      '${summary.encode()}|${lectureDate.toUtc().toIso8601String()}|${firefliesUrl ?? ''}';
  var hash = 0xcbf29ce484222325;
  for (final byte in value.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

void _validateMetadata({
  required String firefliesId,
  required LectureSummary summary,
}) {
  if (firefliesId.length > 2000) {
    throw const IntegrationException(
      integration: 'Notion',
      code: 'metadata_too_long',
      userMessage: 'The Fireflies identifier exceeds Notion limits.',
      retryable: false,
    );
  }
  if (summary.title.length > 2000) {
    throw const IntegrationException(
      integration: 'Notion',
      code: 'title_too_long',
      userMessage: 'The generated title exceeds Notion limits.',
      retryable: false,
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
    ..._headings('Contexto e Objetivos da Aula', level: 1),
    ..._paragraphs(summary.context),
    ...summary.objectives.expand(_bullets),
  ];
  for (final section in summary.sections) {
    blocks.addAll(_headings(section.title, level: 2));
    blocks.addAll(_paragraphs(section.content));
    blocks.addAll(section.keyPoints.expand(_bullets));
    for (final example in section.examples) {
      blocks.addAll(_callouts('Exemplo: $example', '💡'));
    }
    for (final formula in section.formulas) {
      blocks.addAll(_equations(formula));
    }
    for (final code in section.code) {
      for (final segment in _splitText(code, 1900)) {
        blocks.add(_code(segment));
      }
    }
  }
  if (summary.teacherEmphasis.isNotEmpty) {
    blocks.addAll(_headings('Ênfase do docente', level: 2));
    blocks.addAll(
      summary.teacherEmphasis.expand((point) => _callouts(point, '📌')),
    );
  }
  if (summary.importantDetails.isNotEmpty) {
    blocks.addAll(_headings('Detalhes pequenos mas importantes', level: 2));
    blocks.addAll(summary.importantDetails.expand(_bullets));
  }
  if (summary.questionsAndAnswers.isNotEmpty) {
    blocks.addAll(_headings('Perguntas e respostas', level: 2));
    blocks.addAll(summary.questionsAndAnswers.expand(_bullets));
  }
  if (summary.assignmentsAndDeadlines.isNotEmpty) {
    blocks.addAll(_headings('Tarefas, prazos e avisos', level: 2));
    blocks.addAll(
      summary.assignmentsAndDeadlines.expand((item) => _callouts(item, '🗓️')),
    );
  }
  if (summary.examHints.isNotEmpty) {
    blocks.addAll(_headings('Pistas para avaliação', level: 2));
    blocks.addAll(summary.examHints.expand((hint) => _callouts(hint, '🎯')));
  }
  if (summary.uncertainties.isNotEmpty) {
    blocks.addAll(_headings('Incertezas da transcrição', level: 2));
    blocks.addAll(
      summary.uncertainties.expand(
        (uncertainty) => _callouts(uncertainty, '⚠️'),
      ),
    );
  }
  blocks
    ..addAll(_headings('Conclusões e Pontos-Chave', level: 1))
    ..addAll(summary.conclusions.expand(_bullets))
    ..add({'object': 'block', 'type': 'divider', 'divider': {}})
    ..add(
      _paragraph(
        'Source: Fireflies · Lecture date: ${lectureDate.toLocal().toIso8601String().split('T').first}',
        url: firefliesUrl,
      ),
    );
  return blocks;
}

List<Map<String, dynamic>> _headings(String value, {required int level}) {
  final parts = _splitText(value, 1900);
  if (parts.isEmpty) return const [];
  final type = 'heading_$level';
  return [
    {
      'object': 'block',
      'type': type,
      type: {
        'rich_text': [_text(parts.first)],
      },
    },
    ...parts.skip(1).map(_paragraph),
  ];
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

List<Map<String, dynamic>> _bullets(String value) => _splitText(value, 1900)
    .map(
      (segment) => {
        'object': 'block',
        'type': 'bulleted_list_item',
        'bulleted_list_item': {
          'rich_text': [_text(segment)],
        },
      },
    )
    .toList();

List<Map<String, dynamic>> _callouts(String value, String emoji) =>
    _splitText(value, 1900)
        .map(
          (segment) => {
            'object': 'block',
            'type': 'callout',
            'callout': {
              'icon': {'type': 'emoji', 'emoji': emoji},
              'rich_text': [_text(segment)],
            },
          },
        )
        .toList();

List<Map<String, dynamic>> _equations(String value) {
  if (value.runes.length <= 1000) {
    return [
      {
        'object': 'block',
        'type': 'equation',
        'equation': {'expression': value},
      },
    ];
  }
  return _splitText(
    value,
    1900,
  ).map((segment) => _code('Formula: $segment')).toList();
}

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
    'content': value,
    if (url != null) 'link': {'url': url},
  },
};

List<String> _splitText(String input, int maxLength) {
  final normalized = input.trim();
  if (normalized.isEmpty) return const [];
  final output = <String>[];
  final buffer = <int>[];
  var codeUnits = 0;
  for (final rune in normalized.runes) {
    final width = rune > 0xffff ? 2 : 1;
    if (buffer.isNotEmpty && codeUnits + width > maxLength) {
      output.add(String.fromCharCodes(buffer));
      buffer.clear();
      codeUnits = 0;
    }
    buffer.add(rune);
    codeUnits += width;
  }
  if (buffer.isNotEmpty) output.add(String.fromCharCodes(buffer));
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
