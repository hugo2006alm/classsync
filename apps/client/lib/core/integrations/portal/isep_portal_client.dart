import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';

import '../../../domain/academic/academic_hub_models.dart';
import '../bounded_response.dart';
import '../integration_exception.dart';

class PortalCredentials {
  const PortalCredentials({required this.username, required this.password});
  final String username;
  final String password;
}

class PortalProfile {
  const PortalProfile({required this.displayName, this.studentNumber});
  final String displayName;
  final String? studentNumber;
}

class PortalDocument {
  const PortalDocument({required this.url, required this.html});
  final String url;
  final String html;
}

class ExamRegistration {
  const ExamRegistration({
    required this.externalId,
    required this.subjectCode,
    required this.subjectName,
    required this.examType,
    required this.state,
    required this.sourceUrl,
  });

  final String externalId;
  final String subjectCode;
  final String subjectName;
  final String examType;
  final ExamRegistrationState state;
  final String sourceUrl;
}

abstract interface class PortalAdapter {
  Future<PortalProfile> authenticate(PortalCredentials credentials);
  Future<bool> validateSession();
  Future<List<EnrollmentSubject>> getEnrollment();
  Future<List<GradeComponent>> getAcademicHistory();
  Future<List<TimetableSlot>> getTimetable();
  Future<List<EvaluationEvent>> getExams();
  Future<List<ExamRegistration>> getExamRegistrations();
  Future<List<GradeComponent>> getGrades();
  Future<List<AssessmentFormula>> getFucFormulas();
}

class IsepPortalClient implements PortalAdapter {
  IsepPortalClient({Dio? dio, IsepPortalParser? parser})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://portal.isep.ipp.pt/intranet/',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 30),
              responseType: ResponseType.plain,
              headers: const {'accept': 'text/html,application/xhtml+xml'},
            ),
          ),
      _parser = parser ?? const IsepPortalParser();

  final Dio _dio;
  final IsepPortalParser _parser;
  final Map<String, String> _cookies = {};
  Document? _dashboard;
  Uri? _dashboardUrl;

  @override
  Future<PortalProfile> authenticate(PortalCredentials credentials) async {
    try {
      // `/` resolves to host root and loses WebForms fields when redirected.
      // `./` targets the real form action at `/intranet/`.
      final login = await _request('./');
      final state = _hiddenFields(login.document);
      final response = await _request(
        './',
        method: 'POST',
        data: {
          ...state,
          'ctl00\$ContentPlaceHolderMain\$txtLoginISEP': credentials.username,
          'ctl00\$ContentPlaceHolderMain\$txtPasswordISEP':
              credentials.password,
          'ctl00\$ContentPlaceHolderMain\$btLoginISEP.x': '1',
          'ctl00\$ContentPlaceHolderMain\$btLoginISEP.y': '1',
        },
      );
      if (_isLoginPage(response.document)) {
        throw const IntegrationException(
          integration: 'ISEP Portal',
          code: 'invalid_credentials',
          userMessage: 'ISEP Portal rejected the username or password.',
          retryable: false,
        );
      }
      _dashboard = response.document;
      _dashboardUrl = response.url;
      return _parser.parseProfile(response.document);
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ISEP Portal', error);
    }
  }

  @override
  Future<bool> validateSession() async {
    if (_cookies.isEmpty || _dashboardUrl == null) return false;
    try {
      final response = await _request(_dashboardUrl.toString());
      if (_isLoginPage(response.document)) return false;
      _dashboard = response.document;
      _dashboardUrl = response.url;
      return true;
    } on DioException {
      return false;
    }
  }

  @override
  Future<List<EnrollmentSubject>> getEnrollment() async {
    final page = await _featurePage(const [
      'unidades curriculares',
      'disciplinas inscritas',
      'inscrições',
    ]);
    return _parser.parseEnrollment(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<TimetableSlot>> getTimetable() async {
    final page = await _featurePage(const ['horário', 'horario']);
    return _parser.parseTimetable(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<EvaluationEvent>> getExams() async {
    final page = await _featurePage(const ['calendário de exames', 'exames']);
    return _parser.parseExams(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<ExamRegistration>> getExamRegistrations() async {
    final page = await _featurePage(const [
      'inscrição em exames',
      'inscrições em exames',
    ]);
    return _parser.parseExamRegistrations(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<GradeComponent>> getGrades() async {
    final page = await _featurePage(const [
      'classificações parciais',
      'classificações',
      'notas',
    ]);
    return _parser.parseGrades(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<GradeComponent>> getAcademicHistory() async {
    final page = await _featurePage(const [
      'histórico académico',
      'registo académico',
      'histórico',
    ]);
    return _parser.parseGrades(
      page.html,
      sourceUrl: page.url,
      forceHistorical: true,
    );
  }

  @override
  Future<List<AssessmentFormula>> getFucFormulas() async {
    final page = await _featurePage(const [
      'ficha de unidade curricular',
      'fuc',
      'metodo de avaliacao',
      'método de avaliação',
    ]);
    return _parser.parseFucFormulas(page.html, sourceUrl: page.url);
  }

  Future<PortalDocument> _featurePage(List<String> labels) async {
    final dashboard = _dashboard;
    if (dashboard == null) {
      throw const IntegrationException(
        integration: 'ISEP Portal',
        code: 'session_missing',
        userMessage: 'Connect ISEP Portal before synchronizing academic data.',
        retryable: false,
      );
    }
    final normalizedLabels = labels.map(_normalize).toList();
    final link = dashboard.querySelectorAll('a[href]').firstWhere((element) {
      final haystack = _normalize(
        '${element.text} ${element.attributes['title'] ?? ''} ${element.attributes['href'] ?? ''}',
      );
      return normalizedLabels.any(haystack.contains);
    }, orElse: () => Element.tag('a'));
    final href = link.attributes['href'];
    if (href == null || href.isEmpty) {
      throw IntegrationException(
        integration: 'ISEP Portal',
        code: 'portal_route_missing',
        userMessage:
            'ISEP Portal did not expose the ${labels.first} page for this account.',
        retryable: false,
      );
    }
    try {
      final response = await _request(href);
      if (_isLoginPage(response.document)) {
        throw const IntegrationException(
          integration: 'ISEP Portal',
          code: 'session_expired',
          userMessage: 'ISEP Portal session expired. Reconnect it.',
          retryable: false,
        );
      }
      return PortalDocument(
        url: response.url.toString(),
        html: response.document.outerHtml,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ISEP Portal', error);
    }
  }

  Future<_PortalResponse> _request(
    String path, {
    String method = 'GET',
    Map<String, String>? data,
  }) async {
    final attempts = method == 'GET' ? 3 : 1;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await _requestOnce(path, method: method, data: data);
      } on DioException {
        if (attempt == attempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
    throw StateError('Portal retry loop completed unexpectedly.');
  }

  Future<_PortalResponse> _requestOnce(
    String path, {
    required String method,
    Map<String, String>? data,
  }) async {
    var url = _portalUri(path);
    var requestMethod = method;
    Map<String, String>? requestData = data;
    for (var redirect = 0; redirect <= 5; redirect++) {
      final response = await _dio.request<dynamic>(
        url.toString(),
        data: requestData,
        options: Options(
          method: requestMethod,
          responseType: ResponseType.stream,
          contentType: requestData == null
              ? null
              : Headers.formUrlEncodedContentType,
          headers: _cookies.isEmpty
              ? null
              : {
                  'cookie': _cookies.entries
                      .map((item) => '${item.key}=${item.value}')
                      .join('; '),
                },
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      _captureCookies(response.headers.map['set-cookie'] ?? const []);
      final status = response.statusCode ?? 0;
      if (status >= 300) {
        final location = response.headers.value('location');
        if (location == null || redirect == 5) {
          throw const IntegrationException(
            integration: 'ISEP Portal',
            code: 'invalid_redirect',
            userMessage: 'ISEP Portal returned an unsafe or invalid redirect.',
            retryable: false,
          );
        }
        url = _portalUri(url.resolve(location).toString());
        if (status == 301 || status == 302 || status == 303) {
          requestMethod = 'GET';
          requestData = null;
        }
        continue;
      }
      try {
        final bytes = await readBoundedResponse(
          response.data,
          response.headers,
        );
        final body = utf8.decode(bytes, allowMalformed: true);
        return _PortalResponse(url: url, document: html_parser.parse(body));
      } on IntegrationPayloadTooLarge {
        throw const IntegrationException(
          integration: 'ISEP Portal',
          code: 'response_too_large',
          userMessage:
              'ISEP Portal returned more data than ClassSync can safely process.',
          retryable: false,
        );
      }
    }
    throw StateError('Portal redirect loop completed unexpectedly.');
  }

  Uri _portalUri(String path) {
    final base = Uri.parse(_dio.options.baseUrl);
    final uri = base.resolve(path);
    if (uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'portal.isep.ipp.pt' ||
        (uri.hasPort && uri.port != 443)) {
      throw const IntegrationException(
        integration: 'ISEP Portal',
        code: 'unsafe_portal_url',
        userMessage:
            'ISEP Portal exposed a link outside its trusted HTTPS host.',
        retryable: false,
      );
    }
    return uri;
  }

  void _captureCookies(List<String> headers) {
    for (final header in headers) {
      final pair = header.split(';').first;
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  static Map<String, String> _hiddenFields(Document document) => {
    for (final input in document.querySelectorAll('input[type="hidden"][name]'))
      input.attributes['name']!: input.attributes['value'] ?? '',
  };

  static bool _isLoginPage(Document document) =>
      document.querySelector('input[type="password"]') != null ||
      document.querySelector('#ContentPlaceHolderMain_txtLoginISEP') != null;
}

class _PortalResponse {
  const _PortalResponse({required this.url, required this.document});
  final Uri url;
  final Document document;
}

class IsepPortalParser {
  const IsepPortalParser();

  PortalProfile parseProfile(Document document) {
    Element? candidate;
    for (final element in document.querySelectorAll('[id], [class]')) {
      final marker = _normalize(
        '${element.attributes['id'] ?? ''} ${element.attributes['class'] ?? ''}',
      );
      if (marker.contains('user') || marker.contains('utilizador')) {
        candidate = element;
        break;
      }
    }
    final name = candidate?.text.trim();
    final body = document.body?.text ?? '';
    final number = RegExp(r'\b(?:1\d|2\d)\d{5,8}\b').firstMatch(body)?.group(0);
    return PortalProfile(
      displayName: name == null || name.isEmpty ? 'ISEP student' : name,
      studentNumber: number,
    );
  }

  List<EnrollmentSubject> parseEnrollment(
    String html, {
    required String sourceUrl,
  }) {
    final rows = _tableRows(html);
    final result = <EnrollmentSubject>[];
    for (final row in rows) {
      final name = _value(row, const [
        'unidade curricular',
        'disciplina',
        'uc',
        'nome',
      ]);
      final code = _value(row, const ['codigo', 'sigla', 'cod']);
      if (name.isEmpty || _looksLikeHeader(name)) continue;
      final year = _value(row, const ['ano letivo', 'ano', 'academic year']);
      final semester = _value(row, const ['semestre', 'periodo']);
      final id = _value(row, const [
        'id',
        'codigo uc',
      ]).ifEmpty(code).ifEmpty(name);
      result.add(
        EnrollmentSubject(
          externalId: id,
          code: code,
          name: name,
          academicYear: year,
          semester: semester,
          sourceUrl: sourceUrl,
        ),
      );
    }
    return _requireParsed(result, 'enrolment');
  }

  List<TimetableSlot> parseTimetable(String html, {required String sourceUrl}) {
    final document = html_parser.parse(html);
    final result = <TimetableSlot>[];
    for (final element in document.querySelectorAll('[data-start][data-end]')) {
      final start = DateTime.tryParse(element.attributes['data-start'] ?? '');
      final end = DateTime.tryParse(element.attributes['data-end'] ?? '');
      if (start == null || end == null || !end.isAfter(start)) continue;
      final code = element.attributes['data-subject-code'] ?? '';
      final name = element.attributes['data-subject'] ?? element.text.trim();
      result.add(
        TimetableSlot(
          externalId:
              element.attributes['data-id'] ??
              '$code:${start.toIso8601String()}',
          subjectCode: code,
          subjectName: name,
          start: start,
          end: end,
          className: element.attributes['data-class'],
          lessonType: element.attributes['data-type'],
          room: element.attributes['data-room'],
          lecturer: element.attributes['data-lecturer'],
          sourceUrl: sourceUrl,
          exceptional: element.attributes['data-exceptional'] == 'true',
        ),
      );
    }
    for (final row in _tableRows(html)) {
      final name = _value(row, const [
        'unidade curricular',
        'disciplina',
        'uc',
      ]);
      final code = _value(row, const ['codigo', 'sigla', 'codigo uc']);
      final date = _value(row, const ['data', 'dia']);
      final start = _dateTime(
        date,
        _value(row, const ['inicio', 'hora inicio', 'das']),
      );
      final end = _dateTime(
        date,
        _value(row, const ['fim', 'hora fim', 'ate']),
      );
      if ((name.isEmpty && code.isEmpty) ||
          start == null ||
          end == null ||
          !end.isAfter(start)) {
        continue;
      }
      result.add(
        TimetableSlot(
          externalId: _value(row, const ['id']).ifEmpty(
            '$code:${start.toIso8601String()}:${_value(row, const ['tipo', 'tipo aula'])}',
          ),
          subjectCode: code,
          subjectName: name.ifEmpty(code),
          start: start,
          end: end,
          className: _nullable(_value(row, const ['turma', 'classe'])),
          lessonType: _nullable(_value(row, const ['tipo', 'tipo aula'])),
          room: _nullable(_value(row, const ['sala', 'local'])),
          lecturer: _nullable(_value(row, const ['docente', 'professor'])),
          sourceUrl: sourceUrl,
          exceptional:
              _normalize(_value(row, const ['excecional', 'excepcional'])) ==
              'sim',
        ),
      );
    }
    return _requireParsed(
      _dedupe(result, (item) => item.externalId),
      'timetable',
    );
  }

  List<EvaluationEvent> parseExams(String html, {required String sourceUrl}) {
    final result = <EvaluationEvent>[];
    for (final row in _tableRows(html)) {
      final name = _value(row, const [
        'unidade curricular',
        'disciplina',
        'uc',
      ]);
      final code = _value(row, const ['codigo', 'sigla', 'codigo uc']);
      final date = _value(row, const ['data', 'dia']);
      final start = _dateTime(
        date,
        _value(row, const ['inicio', 'hora inicio', 'hora']),
      );
      if ((name.isEmpty && code.isEmpty) || start == null) continue;
      final type = _value(row, const [
        'epoca',
        'tipo',
        'avaliacao',
      ]).ifEmpty('Exam');
      final id = _examIdentity(row, code: code, name: name, type: type);
      result.add(
        EvaluationEvent(
          externalId: id,
          title: '$type · ${name.ifEmpty(code)}',
          type: type,
          subjectCode: code,
          subjectName: name,
          start: start,
          end: _dateTime(date, _value(row, const ['fim', 'hora fim'])),
          location: _nullable(_value(row, const ['sala', 'local'])),
          // A schedule row is never proof that the connected student is
          // registered. Registration is joined from its authenticated flow.
          registrationState: ExamRegistrationState.unknown,
          provenance: [
            AcademicProvenance(
              source: AcademicSource.portal,
              externalId: id,
              url: sourceUrl,
            ),
          ],
        ),
      );
    }
    return _requireParsed(result, 'exam calendar');
  }

  List<ExamRegistration> parseExamRegistrations(
    String html, {
    required String sourceUrl,
  }) {
    final result = <ExamRegistration>[];
    for (final row in _tableRows(html)) {
      final name = _value(row, const [
        'unidade curricular',
        'disciplina',
        'uc',
      ]);
      final code = _value(row, const ['codigo', 'sigla', 'codigo uc']);
      if (name.isEmpty && code.isEmpty) continue;
      final type = _value(row, const [
        'epoca',
        'tipo',
        'avaliacao',
      ]).ifEmpty('Exam');
      final state = _registrationState(
        _value(row, const ['inscricao', 'estado inscricao', 'estado']),
      );
      result.add(
        ExamRegistration(
          externalId: _examIdentity(row, code: code, name: name, type: type),
          subjectCode: code,
          subjectName: name,
          examType: type,
          state: state,
          sourceUrl: sourceUrl,
        ),
      );
    }
    return _requireParsed(result, 'exam registration');
  }

  static String _examIdentity(
    Map<String, String> row, {
    required String code,
    required String name,
    required String type,
  }) {
    final explicit = _value(row, const ['id', 'id exame', 'codigo exame']);
    if (explicit.isNotEmpty) return explicit;
    final academicYear = _value(row, const ['ano letivo', 'ano']);
    return '${_normalize(code.ifEmpty(name))}:${_normalize(type)}:${_normalize(academicYear)}';
  }

  List<GradeComponent> parseGrades(
    String html, {
    required String sourceUrl,
    bool forceHistorical = false,
  }) {
    final result = <GradeComponent>[];
    for (final row in _tableRows(html)) {
      final name = _value(row, const [
        'unidade curricular',
        'disciplina',
        'uc',
      ]);
      final code = _value(row, const ['codigo', 'sigla', 'codigo uc']);
      final component = _value(row, const [
        'elemento avaliacao',
        'componente',
        'avaliacao',
        'tipo',
      ]).ifEmpty('Published grade');
      final value = _number(
        _value(row, const ['classificacao', 'nota', 'resultado', 'valor']),
      );
      if ((name.isEmpty && code.isEmpty) || value == null) continue;
      final academicYear = _nullable(_value(row, const ['ano letivo', 'ano']));
      final status = _normalize(
        _value(row, const ['estado', 'resultado final']),
      );
      final isHistorical =
          forceHistorical ||
          row.keys.any((key) => key.contains('ects')) ||
          status.contains('aprov');
      final isFinal =
          isHistorical ||
          _normalize(component).contains('final') ||
          status.contains('definitiv');
      final id = _value(row, const [
        'id',
      ]).ifEmpty('$code:${academicYear ?? ''}:${_normalize(component)}');
      result.add(
        GradeComponent(
          externalId: id,
          subjectCode: code,
          subjectName: name.ifEmpty(code),
          name: component,
          value: value,
          weight: _percent(
            _value(row, const ['peso', 'ponderacao', 'percentagem']),
          ),
          minimum: _number(_value(row, const ['minimo', 'nota minima'])),
          academicYear: academicYear,
          isFinal: isFinal,
          isHistorical: isHistorical,
          ects: _number(_value(row, const ['ects', 'creditos'])),
          source: GradeValueSource.officialPortal,
          sourceUrl: sourceUrl,
        ),
      );
    }
    return _requireParsed(
      result,
      forceHistorical ? 'academic history' : 'grades',
    );
  }

  List<AssessmentFormula> parseFucFormulas(
    String html, {
    required String sourceUrl,
  }) {
    final grouped = <String, List<GradeComponent>>{};
    final metadata = <String, Map<String, Object?>>{};
    for (final row in _tableRows(html)) {
      final name = _value(row, const [
        'unidade curricular',
        'disciplina',
        'uc',
      ]);
      final code = _value(row, const ['codigo', 'sigla', 'codigo uc']);
      final component = _value(row, const [
        'elemento avaliacao',
        'componente',
        'avaliacao',
      ]);
      final weight = _percent(
        _value(row, const ['peso', 'ponderacao', 'percentagem']),
      );
      if ((name.isEmpty && code.isEmpty) ||
          component.isEmpty ||
          weight == null) {
        continue;
      }
      final formulaLabel = _value(row, const [
        'formula',
        'alternativa',
        'regime',
      ]).ifEmpty('FUC evaluation method');
      final formulaKey = _value(row, const [
        'id formula',
        'formula id',
      ]).ifEmpty(formulaLabel);
      final id = '${_normalize(code.ifEmpty(name))}:${_normalize(formulaKey)}';
      (grouped[id] ??= []).add(
        GradeComponent(
          externalId: '$id:${_normalize(component)}',
          subjectCode: code,
          subjectName: name.ifEmpty(code),
          name: component,
          weight: weight,
          minimum: _number(
            _value(row, const ['minimo', 'nota minima', 'minimo componente']),
          ),
          source: GradeValueSource.fuc,
          confirmed: false,
          sourceUrl: sourceUrl,
        ),
      );
      metadata[id] = {
        'label': formulaLabel,
        'subjectCode': code,
        'subjectName': name.ifEmpty(code),
        'minimumFinalGrade':
            _number(_value(row, const ['nota minima final', 'minimo final'])) ??
            9.5,
      };
    }
    final result = grouped.entries.map((entry) {
      final values = metadata[entry.key]!;
      return AssessmentFormula(
        id: entry.key,
        label: values['label']! as String,
        subjectCode: values['subjectCode']! as String,
        subjectName: values['subjectName']! as String,
        components: entry.value,
        minimumFinalGrade: values['minimumFinalGrade']! as double,
        confirmed: false,
        source: GradeValueSource.fuc,
      );
    }).toList();
    return _requireParsed(result, 'FUC evaluation formula');
  }

  static List<Map<String, String>> _tableRows(String html) {
    final document = html_parser.parse(html);
    final result = <Map<String, String>>[];
    for (final table in document.querySelectorAll('table')) {
      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) continue;
      var headers = rows.first
          .querySelectorAll('th,td')
          .map((cell) => _normalize(cell.text))
          .toList();
      if (headers.every((value) => value.isEmpty)) continue;
      for (final row in rows.skip(1)) {
        final cells = row.querySelectorAll('td');
        if (cells.isEmpty) continue;
        if (cells.length > headers.length) {
          headers = [
            ...headers,
            for (var i = headers.length; i < cells.length; i++) 'column$i',
          ];
        }
        result.add({
          for (var i = 0; i < cells.length; i++)
            headers[i]: cells[i].text.replaceAll(RegExp(r'\s+'), ' ').trim(),
        });
      }
    }
    return result;
  }

  static String _value(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases.map(_normalize)) {
      for (final entry in row.entries) {
        if (entry.key == alias || entry.key.contains(alias)) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  static DateTime? _dateTime(String date, String time) {
    final normalizedDate = date.trim();
    final normalizedTime = time.trim().isEmpty ? '00:00' : time.trim();
    for (final pattern in const [
      'dd/MM/yyyy HH:mm',
      'dd-MM-yyyy HH:mm',
      'yyyy-MM-dd HH:mm',
    ]) {
      try {
        return DateFormat(
          pattern,
        ).parseStrict('$normalizedDate $normalizedTime');
      } on FormatException {
        // Try next known portal representation.
      }
    }
    return DateTime.tryParse(
      '$normalizedDate ${normalizedTime.isEmpty ? '00:00' : normalizedTime}',
    );
  }

  static double? _number(String value) =>
      double.tryParse(value.replaceAll('%', '').replaceAll(',', '.').trim());

  static double? _percent(String value) {
    final parsed = _number(value);
    if (parsed == null) return null;
    return parsed > 1 ? parsed / 100 : parsed;
  }

  static ExamRegistrationState _registrationState(String value) {
    final normalized = _normalize(value);
    if (normalized.contains('nao inscr')) {
      return ExamRegistrationState.notRegistered;
    }
    if (normalized.contains('inscrito')) {
      return ExamRegistrationState.registered;
    }
    if (normalized.contains('encerr')) {
      return ExamRegistrationState.registrationClosed;
    }
    if (normalized.contains('abert') || normalized.contains('disponivel')) {
      return ExamRegistrationState.registrationAvailable;
    }
    return ExamRegistrationState.unknown;
  }

  static List<T> _requireParsed<T>(List<T> values, String feature) {
    if (values.isNotEmpty) return values;
    throw IntegrationException(
      integration: 'ISEP Portal',
      code: 'portal_layout_changed',
      userMessage:
          'ISEP Portal $feature page format was not recognized. No partial data was saved.',
      retryable: false,
    );
  }

  static List<T> _dedupe<T>(Iterable<T> values, String Function(T) keyOf) {
    final seen = <String>{};
    return values.where((value) => seen.add(keyOf(value))).toList();
  }

  static bool _looksLikeHeader(String value) {
    final normalized = _normalize(value);
    return normalized == 'unidade curricular' || normalized == 'disciplina';
  }
}

String _normalize(String value) => SubjectMapper.normalize(value);
String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : trim();
}
