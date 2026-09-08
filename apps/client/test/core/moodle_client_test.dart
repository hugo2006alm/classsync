import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/moodle/moodle_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exchanges credentials for a Moodle mobile token using POST', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://moodle.isep.ipp.pt'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {'token': 'mobile-token'},
            ),
          );
        },
      ),
    );

    final token = await MoodleClient(
      dio: dio,
    ).authenticate(username: ' student ', password: 'secret');

    expect(token, 'mobile-token');
    expect(request.method, 'POST');
    expect(request.uri.path, '/login/token.php');
    expect(request.queryParameters, isEmpty);
    expect(request.contentType, Headers.formUrlEncodedContentType);
    expect(request.data, {
      'username': 'student',
      'password': 'secret',
      'service': MoodleClient.mobileService,
    });
  });

  test('maps rejected Moodle credentials to an actionable error', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://moodle.isep.ipp.pt'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'error': 'Invalid login, please try again',
              'errorcode': 'invalidlogin',
            },
          ),
        ),
      ),
    );

    await expectLater(
      MoodleClient(
        dio: dio,
      ).authenticate(username: 'student', password: 'wrong'),
      throwsA(
        isA<IntegrationException>()
            .having((error) => error.code, 'code', 'invalidlogin')
            .having(
              (error) => error.userMessage,
              'message',
              'The Moodle username or password is incorrect.',
            ),
      ),
    );
  });

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
