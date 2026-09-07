import 'dart:io';

import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/portal/isep_portal_client.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = IsepPortalParser();

  test('normalizes enrolment from sanitized Portal fixture', () {
    final values = parser.parseEnrollment(
      _fixture('enrollment'),
      sourceUrl: 'https://portal.isep.ipp.pt/enrollment',
    );
    expect(values.single.code, 'BDAD');
    expect(values.single.academicYear, '2026/2027');
  });

  test('normalizes and deduplicates timetable', () {
    final html = _fixture('timetable');
    final values = parser.parseTimetable(
      '$html$html',
      sourceUrl: 'https://portal.isep.ipp.pt/timetable',
    );
    expect(values, hasLength(1));
    expect(values.single.lessonType, 'TP');
    expect(
      values.single.end.difference(values.single.start),
      const Duration(minutes: 90),
    );
  });

  test('keeps schedule separate from registration proof', () {
    final values = parser.parseExams(
      _fixture('exams'),
      sourceUrl: 'https://portal.isep.ipp.pt/exams',
    );
    expect(values.single.registrationState, ExamRegistrationState.unknown);
    expect(values.single.location, 'E101');
  });

  test('parses authenticated exam registration separately', () {
    final values = parser.parseExamRegistrations(
      _fixture('exam_registrations'),
      sourceUrl: 'https://portal.isep.ipp.pt/registrations',
    );
    expect(values.single.externalId, 'exam-1');
    expect(values.single.state, ExamRegistrationState.registered);
  });

  test('fallback exam identity survives date changes', () {
    const first =
        '''<table><tr><th>Data</th><th>Hora</th><th>Sigla</th><th>UC</th><th>Época</th></tr>
      <tr><td>18/01/2027</td><td>14:30</td><td>BDAD</td><td>Bases de Dados</td><td>Normal</td></tr></table>''';
    const moved =
        '''<table><tr><th>Data</th><th>Hora</th><th>Sigla</th><th>UC</th><th>Época</th></tr>
      <tr><td>19/01/2027</td><td>09:30</td><td>BDAD</td><td>Bases de Dados</td><td>Normal</td></tr></table>''';
    final firstId = parser
        .parseExams(first, sourceUrl: 'https://portal.isep.ipp.pt/exams')
        .single
        .externalId;
    final movedId = parser
        .parseExams(moved, sourceUrl: 'https://portal.isep.ipp.pt/exams')
        .single
        .externalId;
    expect(movedId, firstId);
  });

  test('parses alternative FUC formulas but requires confirmation', () {
    final values = parser.parseFucFormulas(
      _fixture('fuc'),
      sourceUrl: 'https://portal.isep.ipp.pt/fuc',
    );
    expect(values, hasLength(2));
    expect(values.every((item) => !item.confirmed), isTrue);
    expect(
      values.first.components.fold<double>(
        0,
        (sum, item) => sum + item.weight!,
      ),
      1,
    );
  });

  test('normalizes decimal grades, weights, and thresholds', () {
    final values = parser.parseGrades(
      _fixture('grades'),
      sourceUrl: 'https://portal.isep.ipp.pt/grades',
    );
    expect(values.single.value, 14.5);
    expect(values.single.weight, 0.4);
    expect(values.single.minimum, 8);
    expect(values.single.source, GradeValueSource.officialPortal);
  });

  test('layout drift fails closed without partial values', () {
    expect(
      () => parser.parseTimetable(
        '<html><body>changed</body></html>',
        sourceUrl: 'https://portal.isep.ipp.pt',
      ),
      throwsA(
        isA<IntegrationException>().having(
          (error) => error.code,
          'code',
          'portal_layout_changed',
        ),
      ),
    );
  });

  test(
    'WebForms authentication replays hidden state and validates cookie session',
    () async {
      var authenticated = false;
      final requests = <RequestOptions>[];
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://portal.isep.ipp.pt/intranet/',
          responseType: ResponseType.plain,
        ),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (options.method == 'POST') {
              expect(options.uri.path, '/intranet/');
              final form = options.data as Map<String, String>;
              expect(form['__VIEWSTATE'], 'sanitized-state');
              expect(
                form['ctl00\$ContentPlaceHolderMain\$txtLoginISEP'],
                'student',
              );
              expect(
                options.headers['cookie'],
                contains('ASP.NET_SessionId=session'),
              );
              authenticated = true;
              handler.resolve(_htmlResponse(options, _dashboardHtml));
              return;
            }
            if (options.path.contains('horario.aspx')) {
              handler.resolve(_htmlResponse(options, _fixture('timetable')));
              return;
            }
            if (authenticated) {
              handler.resolve(_htmlResponse(options, _dashboardHtml));
              return;
            }
            handler.resolve(
              _htmlResponse(
                options,
                '<form><input type="hidden" name="__VIEWSTATE" value="sanitized-state">'
                '<input id="ContentPlaceHolderMain_txtLoginISEP">'
                '<input type="password"></form>',
                headers: Headers.fromMap({
                  'set-cookie': ['ASP.NET_SessionId=session; Path=/; HttpOnly'],
                }),
              ),
            );
          },
        ),
      );
      final client = IsepPortalClient(dio: dio);
      final profile = await client.authenticate(
        const PortalCredentials(username: 'student', password: 'password'),
      );
      expect(profile.displayName, 'Student Example');
      expect(await client.validateSession(), isTrue);
      expect(await client.getTimetable(), hasLength(1));
      expect(requests.where((item) => item.method == 'POST'), hasLength(1));
    },
  );

  test(
    'rejects cross-host feature links before attaching session cookies',
    () async {
      var authenticated = false;
      final requestedHosts = <String>[];
      final dio = Dio(
        BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedHosts.add(options.uri.host);
            if (options.method == 'POST') {
              authenticated = true;
              handler.resolve(
                _htmlResponse(
                  options,
                  '<span id="CurrentUser">Student</span>'
                  '<a href="https://attacker.example/timetable">Horário</a>',
                ),
              );
              return;
            }
            handler.resolve(
              _htmlResponse(
                options,
                authenticated
                    ? '<span id="CurrentUser">Student</span>'
                    : '<input type="hidden" name="__VIEWSTATE" value="state">'
                          '<input id="ContentPlaceHolderMain_txtLoginISEP">'
                          '<input type="password">',
              ),
            );
          },
        ),
      );
      final client = IsepPortalClient(dio: dio);
      await client.authenticate(
        const PortalCredentials(username: 'student', password: 'password'),
      );
      await expectLater(
        client.getTimetable(),
        throwsA(
          isA<IntegrationException>().having(
            (error) => error.code,
            'code',
            'unsafe_portal_url',
          ),
        ),
      );
      expect(requestedHosts, everyElement('portal.isep.ipp.pt'));
    },
  );

  test('bounds Portal response bodies', () async {
    var authenticated = false;
    final dio = Dio(
      BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST') {
            authenticated = true;
            handler.resolve(_htmlResponse(options, _dashboardHtml));
            return;
          }
          if (authenticated && options.path.contains('horario.aspx')) {
            handler.resolve(
              _htmlResponse(
                options,
                'small',
                headers: Headers.fromMap({
                  'content-length': ['2097153'],
                }),
              ),
            );
            return;
          }
          handler.resolve(
            _htmlResponse(
              options,
              '<input type="hidden" name="__VIEWSTATE" value="state">'
              '<input id="ContentPlaceHolderMain_txtLoginISEP">'
              '<input type="password">',
            ),
          );
        },
      ),
    );
    final client = IsepPortalClient(dio: dio);
    await client.authenticate(
      const PortalCredentials(username: 'student', password: 'password'),
    );
    await expectLater(
      client.getTimetable(),
      throwsA(
        isA<IntegrationException>().having(
          (error) => error.code,
          'code',
          'response_too_large',
        ),
      ),
    );
  });

  test('retries a transient Portal GET once', () async {
    var attempts = 0;
    final dio = Dio(
      BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'GET' && attempts++ == 0) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          if (options.method == 'POST') {
            handler.resolve(_htmlResponse(options, _dashboardHtml));
            return;
          }
          handler.resolve(
            _htmlResponse(
              options,
              '<input type="hidden" name="__VIEWSTATE" value="state">'
              '<input id="ContentPlaceHolderMain_txtLoginISEP">'
              '<input type="password">',
            ),
          );
        },
      ),
    );
    final client = IsepPortalClient(dio: dio);
    await client.authenticate(
      const PortalCredentials(username: 'student', password: 'password'),
    );
    expect(attempts, 2);
  });
}

String _fixture(String name) =>
    File('test/fixtures/portal/$name.html').readAsStringSync();

const _dashboardHtml = '''
<html><body>
  <span id="CurrentUser">Student Example</span>
  <a href="academic/horario.aspx">Horário</a>
</body></html>
''';

Response<String> _htmlResponse(
  RequestOptions options,
  String body, {
  Headers? headers,
}) => Response<String>(
  requestOptions: options,
  statusCode: 200,
  data: body,
  headers: headers,
);
