import 'package:classsync/core/integrations/fireflies/fireflies_client.dart';
import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/notion/notion_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Notion rejects a repeated cursor before replacing a partial cache',
    () async {
      var calls = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            handler.resolve(
              Response(
                requestOptions: options,
                data: <String, dynamic>{
                  'results': [],
                  'has_more': calls < 4,
                  'next_cursor': 'repeated',
                },
              ),
            );
          },
        ),
      );
      await expectLater(
        NotionClient(
          dio: dio,
        ).querySubjects(token: 'test', dataSourceId: 'subjects'),
        throwsA(
          isA<IntegrationException>().having(
            (e) => e.code,
            'code',
            'pagination_invalid',
          ),
        ),
      );
      expect(calls, 2);
    },
  );

  test(
    'Fireflies rejects repeated pages rather than looping or advancing cursor',
    () async {
      var calls = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            handler.resolve(
              Response(
                requestOptions: options,
                data: <String, dynamic>{
                  'data': {
                    'transcripts': calls >= 4
                        ? []
                        : List.generate(
                            50,
                            (i) => {
                              'id': 'lecture-$i',
                              'title': 'Lecture',
                              'date': 1788600000000,
                            },
                          ),
                  },
                },
              ),
            );
          },
        ),
      );
      await expectLater(
        FirefliesClient(
          dio: dio,
        ).listTranscripts(apiKey: 'test', from: DateTime.utc(2026)),
        throwsA(
          isA<IntegrationException>().having(
            (e) => e.code,
            'code',
            'pagination_invalid',
          ),
        ),
      );
      expect(calls, 2);
    },
  );
}
