import 'package:classsync/core/integrations/notion/notion_client.dart';
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
}
