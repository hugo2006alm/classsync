import 'package:dio/dio.dart';

import '../../../../domain/academic/academic_models.dart';
import '../integration_exception.dart';
import 'notion_client_base.dart' as base;

export 'notion_client_base.dart'
    show NotionDataSource, NotionPageRef, NotionSummaryRecord;

const _notionMarkerHost = 'classsync.invalid';

class NotionRichTextSpan {
  const NotionRichTextSpan({
    required this.text,
    this.href,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.code = false,
    this.color,
  });

  final String text;
  final String? href;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool code;
  final String? color;
}

class NotionContentBlock extends base.NotionContentBlock {
  const NotionContentBlock({
    required super.type,
    required super.text,
    required super.depth,
    this.spans = const [],
    this.icon,
    this.color,
    this.checked,
    this.language,
  });

  final List<NotionRichTextSpan> spans;
  final String? icon;
  final String? color;
  final bool? checked;
  final String? language;
}

/// Compatibility layer around the original Notion adapter.
///
/// Generated summaries used to be wrapped in collapsed toggles so ClassSync
/// could checkpoint chunks safely. The wrapper keeps the same checkpointing
/// guarantee while using an invisible paragraph parent whose children are
/// immediately visible in Notion. Legacy ClassSync toggles are migrated when a
/// summary is opened or re-published.
class NotionClient extends base.NotionClient {
  NotionClient({Dio? dio}) : this._(dio ?? createDio(baseUrl: _baseUrl));

  NotionClient._(Dio dio) : _dio = dio, super(dio: dio);

  static const apiVersion = base.NotionClient.apiVersion;
  static const _baseUrl = 'https://api.notion.com/v1';

  final Dio _dio;

  Options _options(String token) => Options(
    headers: {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'notion-version': apiVersion,
    },
  );

  @override
  Future<List<NotionContentBlock>> readPageContent({
    required String token,
    required String pageId,
  }) async {
    try {
      await _migrateLegacySummaryContent(token: token, pageId: pageId);
      final output = <NotionContentBlock>[];
      await _readContentLevel(
        token: token,
        blockId: pageId,
        depth: 0,
        output: output,
      );
      return output;
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  @override
  Future<void> ensureSummaryContent({
    required String token,
    required String pageId,
    required LectureSummary summary,
    required DateTime lectureDate,
    required String? firefliesUrl,
  }) async {
    final blocks = super.renderSummaryBlocks(
      summary: summary,
      lectureDate: lectureDate,
      firefliesUrl: firefliesUrl,
    );
    final revision = _contentRevision(summary, lectureDate, firefliesUrl);
    final chunks = <List<Map<String, dynamic>>>[];
    for (var offset = 0; offset < blocks.length; offset += 99) {
      chunks.add(blocks.skip(offset).take(99).toList());
    }

    try {
      final children = await _children(token: token, blockId: pageId);
      final completed = children
          .map(_ownedMarker)
          .whereType<_OwnedMarker>()
          .where((marker) => marker.revision == revision && !marker.legacy)
          .map((marker) => marker.chunk)
          .toSet();

      for (var index = 0; index < chunks.length; index += 1) {
        if (completed.contains(index)) continue;
        await _dio.patch<void>(
          '/blocks/${Uri.encodeComponent(pageId)}/children',
          data: {
            'position': {'type': 'end'},
            'children': [
              _visibleWrapper(
                revision: revision,
                chunk: index,
                total: chunks.length,
                children: chunks[index],
              ),
            ],
          },
          options: _options(token),
        );
      }

      await _migrateLegacySummaryContent(
        token: token,
        pageId: pageId,
        onlyRevision: revision,
      );
      await _cleanVisibleMarkers(
        token: token,
        pageId: pageId,
        currentRevision: revision,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  @override
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
    await super.replaceSummaryPage(
      token: token,
      pageId: pageId,
      firefliesId: firefliesId,
      lectureDate: lectureDate,
      subjectId: subjectId,
      summary: summary,
      firefliesUrl: firefliesUrl,
      includeMetadata: includeMetadata,
    );
    try {
      await _cleanVisibleMarkers(
        token: token,
        pageId: pageId,
        currentRevision: _contentRevision(summary, lectureDate, firefliesUrl),
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Notion', error);
    }
  }

  Future<void> _readContentLevel({
    required String token,
    required String blockId,
    required int depth,
    required List<NotionContentBlock> output,
  }) async {
    if (depth > 5 || output.length >= 800) return;
    final children = await _children(token: token, blockId: blockId);
    for (final block in children) {
      if (output.length >= 800) break;
      final type = block['type'] as String? ?? 'unsupported';
      final payload = block[type] as Map<String, dynamic>?;
      final marker = _ownedMarker(block);
      final spans = _richTextSpans(payload?['rich_text']);
      final text = switch (type) {
        'equation' => payload?['expression']?.toString() ?? '',
        'bookmark' =>
          spans.isNotEmpty
              ? spans.map((span) => span.text).join()
              : payload?['url']?.toString() ?? '',
        _ => spans.map((span) => span.text).join(),
      };
      if (marker == null && (text.isNotEmpty || type == 'divider')) {
        output.add(
          NotionContentBlock(
            type: type,
            text: text,
            depth: depth,
            spans: spans,
            icon: type == 'callout'
                ? _calloutEmoji(payload ?? const <String, dynamic>{})
                : null,
            color: payload?['color']?.toString(),
            checked: type == 'to_do' ? payload?['checked'] as bool? : null,
            language: type == 'code' ? payload?['language']?.toString() : null,
          ),
        );
      }
      if (block['has_children'] == true && block['id'] is String) {
        await _readContentLevel(
          token: token,
          blockId: block['id'] as String,
          depth: marker == null ? depth + 1 : depth,
          output: output,
        );
      }
    }
  }

  Future<void> _migrateLegacySummaryContent({
    required String token,
    required String pageId,
    String? onlyRevision,
  }) async {
    final topLevel = await _children(token: token, blockId: pageId);
    final markers = topLevel
        .map(_ownedMarker)
        .whereType<_OwnedMarker>()
        .toList();
    final targetRevision =
        onlyRevision ?? (markers.isEmpty ? null : markers.last.revision);
    if (targetRevision == null) return;

    for (final block in topLevel) {
      final marker = _ownedMarker(block);
      if (marker == null || !marker.legacy || block['id'] is! String) {
        continue;
      }
      final blockId = block['id'] as String;
      if (marker.revision != targetRevision) {
        await _dio.delete<void>(
          '/blocks/${Uri.encodeComponent(blockId)}',
          options: _options(token),
        );
        continue;
      }

      final legacyChildren = await _children(token: token, blockId: blockId);
      final migratedChildren = legacyChildren
          .map(_cloneGeneratedChild)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (legacyChildren.isNotEmpty && migratedChildren.isEmpty) {
        continue;
      }

      await _dio.patch<void>(
        '/blocks/${Uri.encodeComponent(pageId)}/children',
        data: {
          'position': {
            'type': 'after_block',
            'after_block': {'id': blockId},
          },
          'children': [
            _visibleWrapper(
              revision: marker.revision,
              chunk: marker.chunk,
              total: marker.total,
              children: migratedChildren,
            ),
          ],
        },
        options: _options(token),
      );
      await _dio.delete<void>(
        '/blocks/${Uri.encodeComponent(blockId)}',
        options: _options(token),
      );
    }

    await _cleanVisibleMarkers(
      token: token,
      pageId: pageId,
      currentRevision: targetRevision,
    );
  }

  Future<void> _cleanVisibleMarkers({
    required String token,
    required String pageId,
    required String currentRevision,
  }) async {
    final children = await _children(token: token, blockId: pageId);
    final seenChunks = <int>{};
    for (final block in children) {
      final marker = _ownedMarker(block);
      if (marker == null || marker.legacy || block['id'] is! String) continue;
      if (marker.revision == currentRevision && seenChunks.add(marker.chunk)) {
        continue;
      }
      await _dio.delete<void>(
        '/blocks/${Uri.encodeComponent(block['id'] as String)}',
        options: _options(token),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _children({
    required String token,
    required String blockId,
  }) async {
    final blocks = <Map<String, dynamic>>[];
    String? cursor;
    final seen = <String>{};
    do {
      final response = await _dio.get<Map<String, dynamic>>(
        '/blocks/${Uri.encodeComponent(blockId)}/children',
        queryParameters: {'page_size': 100, 'start_cursor': ?cursor},
        options: _options(token),
      );
      final data = response.data ?? const {};
      blocks.addAll(
        (data['results'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>(),
      );
      if (data['has_more'] != true) {
        cursor = null;
      } else {
        final next = data['next_cursor'];
        if (next is! String || next.isEmpty || !seen.add(next)) {
          throw const IntegrationException(
            integration: 'Notion',
            code: 'pagination_invalid',
            userMessage:
                'Notion pagination did not finish safely. Cached data was retained.',
            retryable: true,
          );
        }
        cursor = next;
      }
    } while (cursor != null && seen.length < 100);
    return blocks;
  }
}

class _OwnedMarker {
  const _OwnedMarker({
    required this.revision,
    required this.chunk,
    required this.total,
    required this.legacy,
  });

  final String revision;
  final int chunk;
  final int total;
  final bool legacy;
}

_OwnedMarker? _ownedMarker(Map<String, dynamic> block) {
  if (block['type'] == 'toggle') {
    final toggle = block['toggle'] as Map<String, dynamic>?;
    final text = _richText(toggle?['rich_text']);
    if (text == null) return null;
    final match = RegExp(
      r'^ClassSync generated · ([0-9a-f]{16}) · (\d+)\/(\d+)$',
    ).firstMatch(text);
    if (match == null) return null;
    return _OwnedMarker(
      revision: match.group(1)!,
      chunk: int.parse(match.group(2)!) - 1,
      total: int.parse(match.group(3)!),
      legacy: true,
    );
  }

  if (block['type'] != 'paragraph') return null;
  final paragraph = block['paragraph'] as Map<String, dynamic>?;
  final richText = paragraph?['rich_text'] as List<dynamic>?;
  if (richText == null || richText.isEmpty) return null;
  final first = richText.first;
  if (first is! Map<String, dynamic>) return null;
  final text = first['text'] as Map<String, dynamic>?;
  final link = text?['link'] as Map<String, dynamic>?;
  final url = link?['url']?.toString() ?? first['href']?.toString();
  if (url == null) return null;
  final match = RegExp(
    r'^https://classsync\.invalid/generated/([0-9a-f]{16})/(\d+)/(\d+)$',
  ).firstMatch(url);
  if (match == null) return null;
  return _OwnedMarker(
    revision: match.group(1)!,
    chunk: int.parse(match.group(2)!) - 1,
    total: int.parse(match.group(3)!),
    legacy: false,
  );
}

Map<String, dynamic> _visibleWrapper({
  required String revision,
  required int chunk,
  required int total,
  required List<Map<String, dynamic>> children,
}) => {
  'object': 'block',
  'type': 'paragraph',
  'paragraph': {
    'rich_text': [
      {
        'type': 'text',
        'text': {
          'content': '\u200b',
          'link': {
            'url':
                'https://$_notionMarkerHost/generated/$revision/${chunk + 1}/$total',
          },
        },
      },
    ],
    'children': children,
  },
};

Map<String, dynamic>? _cloneGeneratedChild(Map<String, dynamic> block) {
  final type = block['type'] as String?;
  if (type == null) return null;
  if (type == 'divider') {
    return {'object': 'block', 'type': 'divider', 'divider': <String, dynamic>{}};
  }
  final payload = block[type] as Map<String, dynamic>?;
  if (payload == null) return null;
  if (type == 'equation') {
    final expression = payload['expression']?.toString() ?? '';
    return expression.isEmpty
        ? null
        : {
            'object': 'block',
            'type': 'equation',
            'equation': {'expression': expression},
          };
  }

  final text = _richText(payload['rich_text']) ?? '';
  if (text.isEmpty) return null;
  final href = _firstHref(payload['rich_text']);
  final richText = [_requestText(text, url: href)];
  return switch (type) {
    'paragraph' => {
      'object': 'block',
      'type': 'paragraph',
      'paragraph': {'rich_text': richText},
    },
    'heading_1' || 'heading_2' || 'heading_3' => {
      'object': 'block',
      'type': type,
      type: {'rich_text': richText},
    },
    'bulleted_list_item' || 'numbered_list_item' => {
      'object': 'block',
      'type': type,
      type: {'rich_text': richText},
    },
    'callout' => {
      'object': 'block',
      'type': 'callout',
      'callout': {
        'rich_text': richText,
        'icon': {
          'type': 'emoji',
          'emoji': _calloutEmoji(payload) ?? '📌',
        },
      },
    },
    'code' => {
      'object': 'block',
      'type': 'code',
      'code': {
        'rich_text': richText,
        'language': payload['language']?.toString() ?? 'plain text',
      },
    },
    _ => null,
  };
}

Map<String, dynamic> _requestText(String value, {String? url}) => {
  'type': 'text',
  'text': {
    'content': value,
    if (url != null) 'link': {'url': url},
  },
};

String? _calloutEmoji(Map<String, dynamic> payload) {
  final icon = payload['icon'];
  if (icon is! Map<String, dynamic> || icon['type'] != 'emoji') return null;
  return icon['emoji']?.toString();
}

String? _firstHref(dynamic richText) {
  if (richText is! List) return null;
  for (final item in richText.whereType<Map<String, dynamic>>()) {
    final href = item['href']?.toString();
    if (href != null && href.isNotEmpty) return href;
    final text = item['text'];
    if (text is Map<String, dynamic>) {
      final link = text['link'];
      if (link is Map<String, dynamic>) {
        final url = link['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    }
  }
  return null;
}

List<NotionRichTextSpan> _richTextSpans(dynamic richText) {
  if (richText is! List) return const [];
  return richText.whereType<Map<String, dynamic>>().map((item) {
    final annotations = item['annotations'] as Map<String, dynamic>? ?? const {};
    final text = item['text'] as Map<String, dynamic>?;
    final equation = item['equation'] as Map<String, dynamic>?;
    final value =
        item['plain_text']?.toString() ??
        text?['content']?.toString() ??
        equation?['expression']?.toString() ??
        '';
    final link = text?['link'] as Map<String, dynamic>?;
    return NotionRichTextSpan(
      text: value,
      href: item['href']?.toString() ?? link?['url']?.toString(),
      bold: annotations['bold'] == true,
      italic: annotations['italic'] == true,
      underline: annotations['underline'] == true,
      strikethrough: annotations['strikethrough'] == true,
      code: annotations['code'] == true,
      color: annotations['color']?.toString(),
    );
  }).where((span) => span.text.isNotEmpty).toList();
}

String? _richText(dynamic richText) {
  final spans = _richTextSpans(richText);
  if (spans.isEmpty) return null;
  return spans.map((span) => span.text).join();
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