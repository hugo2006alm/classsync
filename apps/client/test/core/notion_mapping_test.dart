import 'package:classsync/core/integrations/notion/notion_client.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the existing Portuguese Notion subject schema', () {
    final subject = NotionClient().subjectFromPage({
      'id': 'subject-1',
      'url': 'https://notion.so/subject-1',
      'properties': {
        'Nome': {
          'type': 'title',
          'title': [
            {'plain_text': 'Inteligência Artificial'},
          ],
        },
        'Ano': {
          'type': 'select',
          'select': {'name': '3º Ano'},
        },
        'Semestre': {
          'type': 'rich_text',
          'rich_text': [
            {'plain_text': '1º Semestre'},
          ],
        },
        'Status': {
          'type': 'status',
          'status': {'name': 'In progress'},
        },
        'Aliases': {
          'type': 'multi_select',
          'multi_select': [
            {'name': 'IA'},
          ],
        },
      },
    });

    expect(subject.notionId, 'subject-1');
    expect(subject.name, 'Inteligência Artificial');
    expect(subject.year, '3º Ano');
    expect(subject.semester, '1º Semestre');
    expect(subject.status, 'In progress');
    expect(subject.aliases, ['IA']);
  });

  test('renderer preserves long Unicode list content without truncation', () {
    final longPoint = '${List.filled(2001, 'x').join()}🚀tail';
    final blocks = NotionClient().renderSummaryBlocks(
      summary: LectureSummary(
        title: 'Lecture',
        context: 'Context',
        objectives: [longPoint],
        sections: const [],
        conclusions: const [],
      ),
      lectureDate: DateTime.utc(2026),
    );
    final bullets = blocks
        .where((block) => block['type'] == 'bulleted_list_item')
        .map((block) {
          final body = block['bulleted_list_item'] as Map<String, dynamic>;
          final richText = body['rich_text'] as List<dynamic>;
          final text = richText.single as Map<String, dynamic>;
          return (text['text'] as Map<String, dynamic>)['content'] as String;
        })
        .join();
    expect(bullets, longPoint);
    expect(bullets.runes.last, 'l'.runes.single);
  });

  test('maps summary pages for the in-app semester library', () {
    final summary = NotionClient().summaryFromPage({
      'id': 'summary-1',
      'url': 'https://notion.so/summary-1',
      'properties': {
        'Nome': {
          'type': 'title',
          'title': [
            {'plain_text': 'Process scheduling'},
          ],
        },
        'Data': {
          'type': 'date',
          'date': {'start': '2026-09-06'},
        },
        'Cadeira': {
          'type': 'relation',
          'relation': [
            {'id': 'subject-1'},
          ],
        },
      },
    });

    expect(summary.id, 'summary-1');
    expect(summary.title, 'Process scheduling');
    expect(summary.date, DateTime(2026, 9, 6));
    expect(summary.subjectIds, ['subject-1']);
  });

  test(
    'class summary query is subject-filtered, sorted, and bounded',
    () async {
      Map<String, dynamic>? requestBody;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.notion.com/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestBody = options.data as Map<String, dynamic>;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'has_more': true,
                  'results': [
                    {
                      'id': 'summary-newest',
                      'url': 'https://www.notion.so/summary-newest',
                      'properties': {
                        'Nome': {
                          'type': 'title',
                          'title': [
                            {'plain_text': 'Newest lecture'},
                          ],
                        },
                        'Data': {
                          'type': 'date',
                          'date': {'start': '2026-09-08'},
                        },
                        'Cadeira': {
                          'type': 'relation',
                          'relation': [
                            {'id': 'subject-1'},
                          ],
                        },
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final values = await NotionClient(dio: dio)
          .queryRecentSummariesForSubject(
            token: 'secret',
            dataSourceId: 'summaries',
            subjectId: 'subject-1',
          );

      expect(values.single.title, 'Newest lecture');
      expect(requestBody?['page_size'], 20);
      expect(requestBody?['filter'], {
        'property': 'Cadeira',
        'relation': {'contains': 'subject-1'},
      });
      expect(requestBody?['sorts'], [
        {'property': 'Data', 'direction': 'descending'},
      ]);
      expect(requestBody?.containsKey('start_cursor'), isFalse);
    },
  );
}
