import 'package:classsync/core/integrations/notion/notion_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('readPageContent preserves rich Notion formatting metadata', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.notion.com/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'has_more': false,
                'results': [
                  {
                    'id': 'paragraph',
                    'type': 'paragraph',
                    'has_children': false,
                    'paragraph': {
                      'color': 'blue_background',
                      'rich_text': [
                        {
                          'plain_text': 'Important ',
                          'annotations': {'bold': true},
                        },
                        {
                          'plain_text': 'source',
                          'href': 'https://app.fireflies.ai/view/example',
                          'annotations': {'italic': true, 'underline': true},
                        },
                      ],
                    },
                  },
                  {
                    'id': 'callout',
                    'type': 'callout',
                    'has_children': false,
                    'callout': {
                      'color': 'yellow_background',
                      'icon': {'type': 'emoji', 'emoji': '💡'},
                      'rich_text': [
                        {'plain_text': 'Remember this'},
                      ],
                    },
                  },
                  {
                    'id': 'code',
                    'type': 'code',
                    'has_children': false,
                    'code': {
                      'language': 'dart',
                      'rich_text': [
                        {'plain_text': 'final answer = 42;'},
                      ],
                    },
                  },
                  {
                    'id': 'todo',
                    'type': 'to_do',
                    'has_children': false,
                    'to_do': {
                      'checked': true,
                      'rich_text': [
                        {'plain_text': 'Review lecture'},
                      ],
                    },
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final blocks = await NotionClient(
      dio: dio,
    ).readPageContent(token: 'secret', pageId: 'page');

    expect(blocks, hasLength(4));
    expect(blocks[0].text, 'Important source');
    expect(blocks[0].color, 'blue_background');
    expect(blocks[0].spans[0].bold, isTrue);
    expect(blocks[0].spans[1].italic, isTrue);
    expect(blocks[0].spans[1].underline, isTrue);
    expect(blocks[0].spans[1].href, 'https://app.fireflies.ai/view/example');
    expect(blocks[1].icon, '💡');
    expect(blocks[1].color, 'yellow_background');
    expect(blocks[2].language, 'dart');
    expect(blocks[3].checked, isTrue);
  });
}
