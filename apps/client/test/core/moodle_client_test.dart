import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/moodle/moodle_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes stable Moodle course IDs', () {
    final values = MoodleClient.decodeCourses([
      {'id': 42, 'fullname': 'Bases de Dados', 'shortname': 'BDAD'},
    ], baseUrl: 'https://moodle.isep.ipp.pt');
    expect(values.single.externalId, '42');
    expect(values.single.url, endsWith('course/view.php?id=42'));
  });

  test(
    'decodes assignment due dates without duplicates by generated identity',
    () {
      final values = MoodleClient.decodeAssignments({
        'courses': [
          {
            'id': 42,
            'assignments': [
              {'id': 7, 'cmid': 70, 'name': 'Project', 'duedate': 1800000000},
            ],
          },
        ],
      }, baseUrl: 'https://moodle.isep.ipp.pt');
      expect(values.single.externalId, '7');
      expect(values.single.courseId, '42');
      expect(values.single.dueAt.isUtc, isTrue);
    },
  );

  test('decodes relevant news discussions with source link', () {
    final values = MoodleClient.decodeAnnouncements(
      {
        'discussions': [
          {
            'discussion': 9,
            'name': 'Assessment update',
            'message': '<p>Room changed to <strong>B301</strong>.</p>',
            'created': 1800000000,
          },
        ],
      },
      courseId: '42',
      baseUrl: 'https://moodle.isep.ipp.pt',
    );
    expect(values.single.preview, 'Room changed to B301.');
    expect(values.single.url, endsWith('mod/forum/discuss.php?d=9'));
  });

  test('decodes connected student submission state without inferring it', () {
    expect(
      MoodleClient.decodeSubmissionState({
        'lastattempt': {
          'submission': {'status': 'submitted'},
        },
      }),
      'submitted',
    );
    expect(MoodleClient.decodeSubmissionState({'lastattempt': {}}), isNull);
  });

  test('incremental assignment decode keeps only changed records', () {
    final values = MoodleClient.decodeAssignments(
      {
        'courses': [
          {
            'id': 42,
            'assignments': [
              {
                'id': 7,
                'name': 'Old',
                'duedate': 1800000000,
                'timemodified': 1700000000,
              },
              {
                'id': 8,
                'name': 'Changed',
                'duedate': 1800000000,
                'timemodified': 1800000000,
              },
            ],
          },
        ],
      },
      baseUrl: 'https://moodle.isep.ipp.pt',
      since: DateTime.fromMillisecondsSinceEpoch(
        1750000000 * 1000,
        isUtc: true,
      ),
    );
    expect(values.map((item) => item.externalId), ['8']);
  });

  test('bounds Moodle response bodies', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://moodle.isep.ipp.pt'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {'userid': 1},
            headers: Headers.fromMap({
              'content-length': ['2097153'],
            }),
          ),
        ),
      ),
    );
    await expectLater(
      MoodleClient(dio: dio).testConnection('token'),
      throwsA(
        isA<IntegrationException>().having(
          (error) => error.code,
          'code',
          'response_too_large',
        ),
      ),
    );
  });
}
