import 'dart:convert';
import 'dart:io';

import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/portal/isep_portal_client.dart';
import 'package:classsync/core/integrations/portal/strict_isep_portal_parser.dart';
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

  test('parses live Portal week-calendar script with room and teacher', () {
    final values = parser.parseTimetable(
      _fixture('timetable_script'),
      sourceUrl: 'https://portal.isep.ipp.pt/timetable',
    );
    expect(values, hasLength(1));
    expect(values.single.subjectCode, 'PENGEL');
    expect(values.single.lessonType, 'PL');
    expect(values.single.className, '1DF');
    expect(values.single.room, 'B301');
    expect(values.single.lecturer, 'SSN');
    expect(values.single.start, DateTime(2026, 9, 16, 9, 10));
    expect(values.single.end, DateTime(2026, 9, 16, 11));
  });

  test('normalizes Portal JavaScript dates that cross a month boundary', () {
    const html = '''<script>function getEventData() { return { events: [{
      'start': new Date(2026,8,32,9,10),
      'end': new Date(2026,8,32,10,0),
      'title':'<table><tr><td><a title="Disciplina">TEST</a></td><td><label>TP</label></td></tr></table>',
      'body':'',
      'footer':''
    }] }; }</script>''';

    final values = parser.parseTimetable(
      html,
      sourceUrl: 'https://portal.isep.ipp.pt/timetable',
    );

    expect(values, hasLength(1));
    expect(values.single.start, DateTime(2026, 10, 2, 9, 10));
    expect(values.single.end, DateTime(2026, 10, 2, 10));
  });

  test('accepts recognized empty Portal week calendar', () {
    final values = parser.parseTimetable(
      '<script>return { events: [] };</script>',
      sourceUrl: 'https://portal.isep.ipp.pt/timetable',
    );
    expect(values, isEmpty);
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

  test('academic history keeps credited rows without a numeric grade', () {
    const html =
        '''<table><tr><th>ID</th><th>Sigla</th><th>UC</th><th>Ano Letivo</th><th>Estado</th><th>ECTS</th><th>Curso</th></tr>
      <tr><td>h-1</td><td>MAT</td><td>Matemática</td><td>2025/2026</td><td>Creditado</td><td>6</td><td>LEI</td></tr></table>''';
    final value = parser
        .parseGrades(
          html,
          sourceUrl: 'https://portal.isep.ipp.pt/history',
          forceHistorical: true,
        )
        .single;
    expect(value.value, isNull);
    expect(value.academicStatus, 'Creditado');
    expect(value.ects, 6);
    expect(value.courseContext, 'LEI');
  });

  test('normalizes registration windows without inferring registration', () {
    const html =
        '''<table><tr><th>ID</th><th>Sigla</th><th>UC</th><th>Época</th><th>Estado</th><th>Início Inscrição</th><th>Fim Inscrição</th><th>Data Exame</th><th>Taxa</th></tr>
      <tr><td>exam-2</td><td>SO</td><td>Sistemas Operativos</td><td>Recurso</td><td>Disponível</td><td>01/02/2027</td><td>08/02/2027</td><td>12/02/2027</td><td>3 EUR</td></tr></table>''';
    final value = parser
        .parseExamRegistrations(
          html,
          sourceUrl: 'https://portal.isep.ipp.pt/registrations',
        )
        .single;
    expect(value.state, ExamRegistrationState.registrationAvailable);
    expect(value.registrationClosesAt, DateTime(2027, 2, 8));
    expect(value.fee, '3 EUR');
  });

  test('normalizes tuition items without retaining full payment references', () {
    const html =
        '''<table><tr><th>ID Cobrança</th><th>Descrição</th><th>Ano Letivo</th><th>Prestação</th><th>Valor</th><th>Por pagar</th><th>Vencimento</th><th>Estado</th><th>Referência Multibanco</th><th>Juros Mora</th></tr>
      <tr><td>fee-1</td><td>Propina</td><td>2026/2027</td><td>2ª Prestação</td><td>120,50 €</td><td>80,50 €</td><td>15/10/2026</td><td>Pendente</td><td>123 456 789</td><td>0,00 €</td></tr></table>''';
    final value = parser
        .parseTuitionCharges(
          html,
          sourceUrl: 'https://portal.isep.ipp.pt/payments',
        )
        .single;
    expect(value.id, 'fee-1');
    expect(value.amount, 120.5);
    expect(value.outstandingAmount, 80.5);
    expect(value.dueAt, DateTime(2026, 10, 15));
    expect(value.state, TuitionPaymentState.pending);
    expect(value.paymentReferenceAvailable, isTrue);
    expect(value.paymentReferenceHint, '•••• 6789');
    expect(value.toJson().values.join(' '), isNot(contains('123456789')));
  });

  test('imports future Portal payment-plan instalments', () {
    const html = '''<table id="tbPlanoPagamentosTotal">
      <tr><td></td><td>Prestação</td><td>Acumulado</td><td>Data Limite</td><td>Data Pagamento</td><td>Propina Paga</td><td>Juros de mora Pago</td><td>Em Dívida</td></tr>
      <tr><td>1ª Prestação</td><td>100,00 €</td><td>100,00 €</td><td>28/09/2026</td><td>27/09/2026</td><td>100,00 €</td><td>0,00 €</td><td>0,00 €</td></tr>
      <tr><td>2ª Prestação</td><td>100,00 €</td><td>200,00 €</td><td>28/10/2026</td><td></td><td>0,00 €</td><td>0,00 €</td><td>0,00 €</td></tr>
    </table>''';
    final values = const StrictIsepPortalParser().parseTuitionCharges(
      html,
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/propinas/pedidorefmb.aspx',
    );

    expect(values, hasLength(2));
    expect(values.first.state, TuitionPaymentState.paid);
    expect(values.last.state, TuitionPaymentState.pending);
    expect(values.last.id, 'plan:2 prestacao');
    expect(values.last.amount, 100);
    expect(values.last.outstandingAmount, isNull);
    expect(values.last.dueAt, DateTime(2026, 10, 28));
  });

  test('stable tuition identity survives due date change and detects overdue', () {
    const first =
        '''<table><tr><th>Descrição</th><th>Ano Letivo</th><th>Prestação</th><th>Vencimento</th><th>Estado</th></tr>
      <tr><td>Propina</td><td>2026/2027</td><td>1ª Prestação</td><td>10/10/2026</td><td>Pendente</td></tr></table>''';
    const moved =
        '''<table><tr><th>Descrição</th><th>Ano Letivo</th><th>Prestação</th><th>Vencimento</th><th>Estado</th></tr>
      <tr><td>Propina</td><td>2026/2027</td><td>1ª Prestação</td><td>20/10/2026</td><td>Pendente</td></tr></table>''';
    final firstCharge = parser
        .parseTuitionCharges(
          first,
          sourceUrl: 'https://portal.isep.ipp.pt/payments',
        )
        .single;
    final movedCharge = parser
        .parseTuitionCharges(
          moved,
          sourceUrl: 'https://portal.isep.ipp.pt/payments',
        )
        .single;
    expect(movedCharge.id, firstCharge.id);
    expect(firstCharge.isOverdueAt(DateTime(2026, 10, 11)), isTrue);
  });

  test('parses official notices, FUC context, and lesson summaries', () {
    const noticeHtml =
        '''<table><tr><th>ID</th><th>Assunto</th><th>Remetente</th><th>Data</th><th>Mensagem</th><th>Anexos</th></tr>
      <tr><td>n-1</td><td>Prazo</td><td>Secretaria</td><td>07/09/2026</td><td>Consulte o prazo.</td><td>aviso.pdf</td></tr></table>''';
    const fucHtml =
        '''<table><tr><th>ID</th><th>Sigla</th><th>UC</th><th>Ano Letivo</th><th>Docente Responsável</th><th>Objetivos</th><th>Programa</th><th>Metodologias</th><th>Regras Avaliação</th></tr>
      <tr><td>f-1</td><td>IA</td><td>Inteligência Artificial</td><td>2026/2027</td><td>Ana Silva</td><td>Pesquisar;Planear</td><td>A*;CSP</td><td>TP</td><td>Teste 60%;Projeto 40%</td></tr></table>''';
    const summaryHtml =
        '''<table><tr><th>ID</th><th>Sigla</th><th>UC</th><th>Data</th><th>Hora</th><th>Sumário</th><th>Docente</th></tr>
      <tr><td>s-1</td><td>IA</td><td>Inteligência Artificial</td><td>07/09/2026</td><td>10:00</td><td>Pesquisa A* e heurísticas.</td><td>Ana Silva</td></tr></table>''';
    expect(
      parser
          .parseNotifications(
            noticeHtml,
            sourceUrl: 'https://portal.isep.ipp.pt/notices',
          )
          .single
          .sender,
      'Secretaria',
    );
    expect(
      parser
          .parseFucProfiles(
            fucHtml,
            sourceUrl: 'https://portal.isep.ipp.pt/fuc',
          )
          .single
          .syllabus,
      ['A*', 'CSP'],
    );
    expect(
      parser
          .parseLessonSummaries(
            summaryHtml,
            sourceUrl: 'https://portal.isep.ipp.pt/summaries',
          )
          .single
          .text,
      contains('heurísticas'),
    );
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
    'authenticates and validates dashboard containing an account password field',
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
              final rawForm = options.data as String;
              final form = Uri.splitQueryString(rawForm);
              expect(form['__VIEWSTATE'], 'sanitized-state');
              expect(
                form['ctl00\$ContentPlaceHolderMain\$txtLoginISEP'],
                'student',
              );
              expect(
                options.headers['cookie'],
                contains('ASP.NET_SessionId=session'),
              );
              expect(options.headers['origin'], 'https://portal.isep.ipp.pt');
              expect(
                options.headers['referer'],
                'https://portal.isep.ipp.pt/intranet/',
              );
              expect(
                options.headers[Headers.contentTypeHeader],
                '${Headers.formUrlEncodedContentType}; charset=ISO-8859-1',
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
    'submits legacy Portal credentials using the page Latin-1 charset',
    () async {
      String? postedForm;
      final dio = Dio(
        BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') {
              postedForm = options.data as String;
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

      await IsepPortalClient(dio: dio).authenticate(
        const PortalCredentials(username: 'aluno', password: 'ação segura'),
      );

      expect(postedForm, contains('a%E7%E3o+segura'));
      expect(postedForm, isNot(contains('a%C3%A7%C3%A3o')));
    },
  );

  test('posts to the form action after the login page redirects', () async {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST') {
            expect(options.uri.path, '/intranet/permit/signin.aspx');
            handler.resolve(_htmlResponse(options, _dashboardHtml));
          } else if (options.uri.path == '/intranet/') {
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 302,
                headers: Headers.fromMap({
                  'location': ['permit/login.aspx'],
                }),
              ),
            );
          } else {
            handler.resolve(
              _htmlResponse(
                options,
                '<form action="signin.aspx"><input id="ContentPlaceHolderMain_txtLoginISEP"></form>',
              ),
            );
          }
        },
      ),
    );
    await IsepPortalClient(dio: dio).authenticate(
      const PortalCredentials(username: 'student', password: 'secret'),
    );
  });

  for (final failure in {
    'portal_login_incomplete':
        '<input id="ContentPlaceHolderMain_txtLoginISEP">',
  }.entries) {
    test('reports ${failure.key} without blaming credentials', () async {
      var posts = 0;
      final dio = Dio(
        BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') {
              posts++;
              handler.resolve(
                _htmlResponse(
                  options,
                  posts == 1 ? _dashboardHtml : failure.value,
                  headers: Headers.fromMap({
                    'set-cookie': ['session=old; Path=/'],
                  }),
                ),
              );
            } else {
              expect(options.headers['cookie'], isNull);
              handler.resolve(
                _htmlResponse(
                  options,
                  '<input id="ContentPlaceHolderMain_txtLoginISEP">',
                ),
              );
            }
          },
        ),
      );
      final client = IsepPortalClient(dio: dio);
      const credentials = PortalCredentials(
        username: 'student',
        password: 'secret',
      );
      await client.authenticate(credentials);
      await expectLater(
        client.authenticate(credentials),
        throwsA(
          isA<IntegrationException>().having(
            (e) => e.code,
            'code',
            failure.key,
          ),
        ),
      );
      expect(await client.validateSession(), isFalse);
    });
  }

  test(
    'decodes the live Portal Latin-1 dashboard before route matching',
    () async {
      var authenticated = false;
      final dio = Dio(
        BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') {
              authenticated = true;
              handler.resolve(
                _bytesResponse(
                  options,
                  '<span id="CurrentUser">Hugo</span>'
                  '<a href="academic/horario.aspx">Horário</a>',
                ),
              );
              return;
            }
            if (authenticated && options.path.contains('horario.aspx')) {
              handler.resolve(_htmlResponse(options, _fixture('timetable')));
              return;
            }
            handler.resolve(
              _bytesResponse(
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
        const PortalCredentials(username: '1234567', password: 'secret'),
      );
      expect(await client.getTimetable(), hasLength(1));
    },
  );

  test(
    'prefers and resolves the live timetable route from the dashboard',
    () async {
      final requestedPaths = <String>[];
      final dio = Dio(
        BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedPaths.add(options.uri.path);
            if (options.method == 'POST') {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 302,
                  headers: Headers.fromMap({
                    'location': ['/intranet/conta/AreaDeTrabalho.aspx'],
                  }),
                ),
              );
              return;
            }
            if (options.uri.path == '/intranet/conta/AreaDeTrabalho.aspx') {
              handler.resolve(
                _htmlResponse(
                  options,
                  '<span id="CurrentUser">Student</span>'
                  '<a href="../certidoes/certidao_horario.aspx">Horário PDF</a>'
                  '<a href="../ver_horario/ver_horario.aspx?user=42">Horário</a>',
                ),
              );
              return;
            }
            if (options.uri.path == '/intranet/ver_horario/ver_horario.aspx') {
              expect(options.uri.queryParameters['user'], '42');
              handler.resolve(
                _htmlResponse(options, _fixture('timetable_script')),
              );
              return;
            }
            handler.resolve(
              _htmlResponse(
                options,
                '<input id="ContentPlaceHolderMain_txtLoginISEP">'
                '<input type="password">',
              ),
            );
          },
        ),
      );

      final client = IsepPortalClient(dio: dio);
      await client.authenticate(
        const PortalCredentials(username: 'student', password: 'secret'),
      );
      final timetable = await client.getTimetable();

      expect(timetable, hasLength(1));
      expect(timetable.single.room, 'B301');
      expect(timetable.single.lecturer, 'SSN');
      expect(
        requestedPaths,
        contains('/intranet/ver_horario/ver_horario.aspx'),
      );
      expect(
        requestedPaths,
        isNot(contains('/intranet/certidoes/certidao_horario.aspx')),
      );
    },
  );

  test('loads the requested timetable week and four weeks forward', () async {
    var authenticated = false;
    var weekIndex = 0;
    final requestedDates = <String>[];
    final dio = Dio(
      BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          if (options.method == 'POST' && path == '/intranet/') {
            authenticated = true;
            handler.resolve(
              _htmlResponse(
                options,
                '<span id="CurrentUser">Student</span>'
                '<a href="ver_horario/ver_horario.aspx">Horário</a>',
              ),
            );
            return;
          }
          if (path.endsWith('/getCodeWeekByData')) {
            final body = jsonDecode(options.data as String) as Map;
            requestedDates.add(body['data'] as String);
            handler.resolve(
              _htmlResponse(options, jsonEncode({'d': 'week-$weekIndex'})),
            );
            return;
          }
          if (path.endsWith('/mudar_semana')) {
            final start = DateTime(
              2026,
              9,
              14,
            ).add(Duration(days: weekIndex * 7));
            final script =
                '''<script>function getEventData() { return { events: [{
              'start': new Date(${start.year},${start.month - 1},${start.day},9,10),
              'end': new Date(${start.year},${start.month - 1},${start.day},10,0),
              'title':'<table><tr><td><a title="Disciplina">UC$weekIndex</a></td></tr></table>',
              'body':'', 'footer':''
            }] }; }</script>''';
            weekIndex++;
            handler.resolve(_htmlResponse(options, jsonEncode({'d': script})));
            return;
          }
          if (authenticated &&
              path == '/intranet/ver_horario/ver_horario.aspx') {
            handler.resolve(
              _htmlResponse(
                options,
                '<input id="ContentPlaceHolderMain_hf_code_user" value="user">'
                '<input id="ContentPlaceHolderMain_hf_tipo_user" value="student">'
                '<input id="ContentPlaceHolderMain_hf_code_user_code" value="code">',
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
      const PortalCredentials(username: 'student', password: 'secret'),
    );

    final values = await client.getTimetable(
      from: DateTime(2026, 9, 16),
      weeks: 5,
    );

    expect(values, hasLength(5));
    expect(requestedDates, [
      'Mon Sep 14 2026',
      'Mon Sep 21 2026',
      'Mon Sep 28 2026',
      'Mon Oct 05 2026',
      'Mon Oct 12 2026',
    ]);
  });

  test(
    'loads current grades and history through Portal page methods',
    () async {
      final requestedMethods = <String>[];
      final dio = Dio(
        BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path.endsWith('/getPartialGradesEvent')) {
              requestedMethods.add('getPartialGradesEvent');
              expect(options.method, 'POST');
              expect(jsonDecode(options.data as String), {'cuser': '123456'});
              handler.resolve(
                _htmlResponse(
                  options,
                  jsonEncode({
                    'd': '''
                    <table>
                      <tr><th>Unidade Curricular</th><th>Elemento Avaliação</th><th>Classificação</th></tr>
                      <tr><td>Operating Systems</td><td>Project</td><td>16</td></tr>
                    </table>
                  ''',
                  }),
                  headers: Headers.fromMap({
                    Headers.contentTypeHeader: ['application/json'],
                  }),
                ),
              );
              return;
            }
            if (options.uri.path.endsWith('/getStudentFileEvent')) {
              requestedMethods.add('getStudentFileEvent');
              final latin1Json = latin1.encode(
                jsonEncode({
                  'd': '''
                    <table>
                      <tr><th>Unidade Curricular</th><th>Classificação</th><th>Ano Letivo</th><th>ECTS</th><th>Estado</th></tr>
                      <tr><td>Álgebra</td><td>14</td><td>2025/2026</td><td>6</td><td>Aprovado</td></tr>
                    </table>
                  ''',
                }),
              );
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: ResponseBody.fromBytes(latin1Json, 200),
                ),
              );
              return;
            }
            if (options.uri.path.endsWith('/areapessoal/estudante.aspx')) {
              handler.resolve(
                _htmlResponse(
                  options,
                  '<script>var dados = {cuser: "123456"};</script>',
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
                '<input id="ContentPlaceHolderMain_txtLoginISEP">'
                '<input type="password">',
              ),
            );
          },
        ),
      );

      final client = IsepPortalClient(dio: dio);
      await client.authenticate(
        const PortalCredentials(username: 'student', password: 'secret'),
      );

      expect((await client.getGrades()).single.value, 16);
      final history = (await client.getAcademicHistory()).single;
      expect(history.ects, 6);
      expect(history.subjectName, 'Álgebra');
      expect(requestedMethods, [
        'getPartialGradesEvent',
        'getStudentFileEvent',
      ]);
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

  test('loads student records through the live read-only endpoints', () async {
    var authenticated = false;
    final studentMethods = <String>[];
    final dio = Dio(
      BaseOptions(baseUrl: 'https://portal.isep.ipp.pt/intranet/'),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST' && options.uri.path == '/intranet/') {
            authenticated = true;
            handler.resolve(
              _htmlResponse(
                options,
                '<span id="CurrentUser">Student</span>'
                '<a href="/intranet/areapessoal/estudante.aspx?hist=true">Ficha Aluno</a>',
              ),
            );
            return;
          }
          if (options.method == 'POST' &&
              options.uri.path.contains('/estudante.aspx/')) {
            final method = options.uri.pathSegments.last;
            studentMethods.add(method);
            expect(jsonDecode(options.data as String), {'cuser': '123456'});
            final body = switch (method) {
              'getPartialGradesEvent' =>
                '<table><tr><th>Unidade Curricular</th><th>ECTS</th><th>Nota</th><th>Data</th></tr>'
                    '<tr><td>Bases de Dados</td><td>6</td><td>15</td><td>2026-07-01</td></tr></table>',
              'getDisciplinesEvent' =>
                '<table><tr><th>Unidade Curricular</th><th>ECTS</th><th>Ano Letivo</th><th>Estado</th></tr>'
                    '<tr><td>Bases de Dados</td><td>6</td><td>2025/2026</td><td>Inscrito</td></tr></table>',
              'getStudentFileEvent' =>
                '<table><tr><th>Unidade Curricular</th><th>ECTS</th><th>Nota</th><th>Ano Letivo</th><th>Estado</th></tr>'
                    '<tr><td>Bases de Dados</td><td>6</td><td>15</td><td>2025/2026</td><td>Aprovado</td></tr></table>',
              _ => throw StateError('Unexpected Portal method $method'),
            };
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {'d': body},
              ),
            );
            return;
          }
          if (authenticated &&
              options.uri.path.endsWith('/areapessoal/estudante.aspx')) {
            handler.resolve(
              _htmlResponse(
                options,
                '<script>var dados = {cuser: "123456"};</script>',
              ),
            );
            return;
          }
          if (authenticated &&
              options.uri.path.endsWith('/propinas/pedidorefmb.aspx')) {
            handler.resolve(
              _htmlResponse(
                options,
                '<table><tr><th>Data</th><th>Nº Documento</th><th>Artigo(s)</th><th>Valor Doc.</th><th>Valor Pendente</th><th>Estado</th></tr>'
                '<tr><td>2026-08-24</td><td>FT-1</td><td>Propina</td><td>69.70€</td><td>0.00€</td><td>Liquidada</td></tr></table>',
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
    final client = IsepPortalClient(
      dio: dio,
      parser: const StrictIsepPortalParser(),
    );
    await client.authenticate(
      const PortalCredentials(username: 'student', password: 'password'),
    );

    expect((await client.getEnrollment()).single.name, 'Bases de Dados');
    expect((await client.getGrades()).single.value, 15);
    expect((await client.getAcademicHistory()).single.ects, 6);
    expect((await client.getTuitionCharges()).single.outstandingAmount, 0);
    expect(studentMethods, [
      'getDisciplinesEvent',
      'getPartialGradesEvent',
      'getStudentFileEvent',
    ]);
  });
}

String _fixture(String name) =>
    File('test/fixtures/portal/$name.html').readAsStringSync();

const _dashboardHtml = '''
<html><body>
  <span id="CurrentUser">Student Example</span>
  <input type="password" name="accountPassword" style="display:none">
  <a href="academic/horario.aspx">Horário</a>
  <a href="/intranet/areapessoal/estudante.aspx">Ficha Aluno</a>
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

Response<List<int>> _bytesResponse(RequestOptions options, String body) =>
    Response<List<int>>(
      requestOptions: options,
      statusCode: 200,
      data: latin1.encode(body),
      headers: Headers.fromMap({
        Headers.contentTypeHeader: ['text/html; charset=iso-8859-1'],
      }),
    );
