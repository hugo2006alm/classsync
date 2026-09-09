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
    this.registrationOpensAt,
    this.registrationClosesAt,
    this.examAt,
    this.fee,
  });

  final String externalId;
  final String subjectCode;
  final String subjectName;
  final String examType;
  final ExamRegistrationState state;
  final String sourceUrl;
  final DateTime? registrationOpensAt;
  final DateTime? registrationClosesAt;
  final DateTime? examAt;
  final String? fee;

  Map<String, dynamic> toJson() => {
    'externalId': externalId,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'examType': examType,
    'state': state.name,
    'sourceUrl': sourceUrl,
    'registrationOpensAt': registrationOpensAt?.toIso8601String(),
    'registrationClosesAt': registrationClosesAt?.toIso8601String(),
    'examAt': examAt?.toIso8601String(),
    'fee': fee,
  };
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
  Future<List<FucProfile>> getFucProfiles();
  Future<List<PortalNotification>> getNotifications();
  Future<List<OfficialLessonSummary>> getLessonSummaries();
  Future<List<TuitionCharge>> getTuitionCharges();
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
              headers: const {
                'accept': 'text/html,application/xhtml+xml',
                'accept-language': 'pt-PT,pt;q=0.9,en;q=0.7',
                'user-agent':
                    'Mozilla/5.0 ClassSync/0.3 (ISEP Portal read-only client)',
              },
            ),
          ),
      _parser = parser ?? const IsepPortalParser();

  final Dio _dio;
  final IsepPortalParser _parser;
  final Map<String, String> _cookies = {};
  Document? _dashboard;
  Uri? _dashboardUrl;
  final Map<String, PortalDocument> _pageCache = {};

  @override
  Future<PortalProfile> authenticate(PortalCredentials credentials) async {
    // A connection test must authenticate the supplied account, never reuse a
    // previous account's dashboard or cookies after a failed attempt.
    _cookies.clear();
    _pageCache.clear();
    _dashboard = null;
    _dashboardUrl = null;
    try {
      // `/` resolves to host root and loses WebForms fields when redirected.
      // `./` targets the real form action at `/intranet/`.
      final login = await _request('./');
      final state = _hiddenFields(login.document);
      final action = login.document.querySelector('form')?.attributes['action'];
      final response = await _request(
        login.url.resolve(action ?? '').toString(),
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
          code: 'portal_login_incomplete',
          userMessage:
              'ISEP Portal returned its sign-in page without completing login. '
              'If these credentials work in your browser, ClassSync may not '
              'support that sign-in flow yet.',
          retryable: false,
        );
      }
      if (response.url.path.toLowerCase().endsWith('/guest.aspx')) {
        throw const IntegrationException(
          integration: 'ISEP Portal',
          code: 'portal_guest_session',
          userMessage:
              'ISEP Portal opened a guest session instead of your account. '
              'Sign in to Portal in your browser, then reconnect.',
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
    if (_hasStudentPage) {
      final page = await _studentData('getDisciplinesEvent');
      return _parser.parseEnrollment(page.html, sourceUrl: page.url);
    }
    final page = await _featurePage(const [
      'unidades curriculares',
      'disciplinas inscritas',
      'inscrições',
    ]);
    return _parser.parseEnrollment(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<TimetableSlot>> getTimetable() async {
    final page = await _featurePage(const ['horario', 'ver horario']);
    return _parser.parseTimetable(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<EvaluationEvent>> getExams() async {
    if (_hasStudentPage) {
      final slots = await getTimetable();
      return slots
          .where((slot) => slot.exceptional)
          .map(
            (slot) => EvaluationEvent(
              externalId: slot.externalId,
              title: '${slot.lessonType} · ${slot.subjectName}',
              type: slot.lessonType ?? 'Exam',
              subjectCode: slot.subjectCode,
              subjectName: slot.subjectName,
              start: slot.start,
              end: slot.end,
              location: slot.room,
              registrationState: ExamRegistrationState.unknown,
              provenance: [
                AcademicProvenance(
                  source: AcademicSource.portal,
                  externalId: slot.externalId,
                  url: slot.sourceUrl,
                ),
              ],
            ),
          )
          .toList();
    }
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
    if (_hasStudentPage) {
      final page = await _studentData('getStudentFileEvent');
      return _parser.parseGrades(page.html, sourceUrl: page.url);
    }
    final page = await _featurePage(const [
      'classificações parciais',
      'classificações',
      'notas',
    ]);
    return _parser.parseGrades(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<GradeComponent>> getAcademicHistory() async {
    if (_hasStudentPage) {
      final page = await _studentData('getStudentFileEvent');
      return _parser.parseGrades(
        page.html,
        sourceUrl: page.url,
        forceHistorical: true,
      );
    }
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

  @override
  Future<List<FucProfile>> getFucProfiles() async {
    final page = await _featurePage(const [
      'ficha de unidade curricular',
      'fuc',
    ]);
    return _parser.parseFucProfiles(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<PortalNotification>> getNotifications() async {
    final page = await _featurePage(const [
      'notificações eletrónicas',
      'notificacoes eletronicas',
      'notificações',
    ]);
    return _parser.parseNotifications(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<OfficialLessonSummary>> getLessonSummaries() async {
    final page = await _featurePage(const ['sumários', 'sumarios']);
    return _parser.parseLessonSummaries(page.html, sourceUrl: page.url);
  }

  @override
  Future<List<TuitionCharge>> getTuitionCharges() async {
    if (_hasStudentPage) {
      final page = await _studentData('getDividas');
      return _parser.parseTuitionCharges(page.html, sourceUrl: page.url);
    }
    final page = await _featurePage(const [
      'situação financeira',
      'situacao financeira',
      'propinas',
      'pagamentos',
      'emolumentos',
    ]);
    return _parser.parseTuitionCharges(page.html, sourceUrl: page.url);
  }

  bool get _hasStudentPage =>
      _dashboard
          ?.querySelectorAll('a[href]')
          .any(
            (a) => (a.attributes['href'] ?? '').contains(
              '/areapessoal/estudante.aspx',
            ),
          ) ??
      false;

  Future<PortalDocument> _studentData(String method) async {
    const allowed = {
      'getDividas',
      'getStudentFileEvent',
      'getDisciplinesEvent',
    };
    if (!allowed.contains(method)) throw ArgumentError.value(method);
    final cached = _pageCache[method];
    if (cached != null) return cached;
    final page = await _featurePage(const ['ficha aluno', 'dados do aluno']);
    final match = RegExp(r'''cuser:\s*["'](\d+)["']''').firstMatch(page.html);
    if (match == null) {
      throw const IntegrationException(
        integration: 'ISEP Portal',
        code: 'portal_layout_changed',
        userMessage:
            'Portal student record did not expose its read-only data identity.',
        retryable: false,
      );
    }
    final pageUri = Uri.parse(page.url);
    final url = _portalUri('${pageUri.origin}${pageUri.path}/$method');
    try {
      final response = await _dio.post<dynamic>(
        url.toString(),
        data: jsonEncode({'cuser': match.group(1)}),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: {
            'cookie': _cookies.entries
                .map((e) => '${e.key}=${e.value}')
                .join('; '),
            'referer': page.url,
          },
        ),
      );
      final bytes = await readBoundedResponse(response.data, response.headers);
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map || data['d'] is! String) throw const FormatException();
      return _pageCache[method] = PortalDocument(
        url: page.url,
        html: data['d'] as String,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('ISEP Portal', error);
    } on FormatException {
      throw const IntegrationException(
        integration: 'ISEP Portal',
        code: 'portal_layout_changed',
        userMessage: 'Portal returned an invalid student record response.',
        retryable: false,
      );
    }
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
    final links = dashboard.querySelectorAll('a[href]');
    Element? chosen;
    for (final label in normalizedLabels) {
      for (final element in links) {
        final names = [
          element.text,
          element.attributes['title'] ?? '',
          element.querySelector('img')?.attributes['alt'] ?? '',
        ].map(_normalize);
        if (names.contains(label)) {
          chosen = element;
          break;
        }
      }
      if (chosen != null) break;
    }
    // Only human-readable labels may provide a fallback. Matching URL fragments
    // selected declarations and unrelated payment menus before the real page.
    final link =
        chosen ??
        links.firstWhere(
          (element) => normalizedLabels.any(
            (label) =>
                label.length > 5 && _normalize(element.text).contains(label),
          ),
          orElse: () => Element.tag('a'),
        );
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
      final resolved = _portalUri(
        (_dashboardUrl ?? Uri.parse(_dio.options.baseUrl))
            .resolve(href)
            .toString(),
      );
      if (_pageCache[resolved.toString()] case final cached?) return cached;
      final response = await _request(resolved.toString());
      if (_isLoginPage(response.document)) {
        throw const IntegrationException(
          integration: 'ISEP Portal',
          code: 'session_expired',
          userMessage: 'ISEP Portal session expired. Reconnect it.',
          retryable: false,
        );
      }
      return _pageCache[resolved.toString()] = PortalDocument(
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
        data: requestData == null ? null : _encodeLegacyForm(requestData),
        options: Options(
          method: requestMethod,
          responseType: ResponseType.stream,
          contentType: requestData == null
              ? null
              : '${Headers.formUrlEncodedContentType}; charset=ISO-8859-1',
          headers: _cookies.isEmpty
              ? {
                  if (requestData != null) ...{
                    'origin': '${url.scheme}://${url.host}',
                    'referer': url.toString(),
                  },
                }
              : {
                  'cookie': _cookies.entries
                      .map((item) => '${item.key}=${item.value}')
                      .join('; '),
                  if (requestData != null) ...{
                    'origin': '${url.scheme}://${url.host}',
                    'referer': url.toString(),
                  },
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
        final contentType = response.headers
            .value(Headers.contentTypeHeader)
            ?.toLowerCase();
        final body = contentType?.contains('iso-8859-1') == true
            ? latin1.decode(bytes, allowInvalid: true)
            : utf8.decode(bytes, allowMalformed: true);
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

  static String _encodeLegacyForm(Map<String, String> fields) => fields.entries
      .map(
        (entry) =>
            '${_encodeLegacyComponent(entry.key)}=${_encodeLegacyComponent(entry.value)}',
      )
      .join('&');

  static String _encodeLegacyComponent(String value) {
    final result = StringBuffer();
    for (final byte in latin1.encode(value)) {
      final unreserved =
          (byte >= 0x41 && byte <= 0x5a) ||
          (byte >= 0x61 && byte <= 0x7a) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2a ||
          byte == 0x2d ||
          byte == 0x2e ||
          byte == 0x5f;
      if (unreserved) {
        result.writeCharCode(byte);
      } else if (byte == 0x20) {
        result.write('+');
      } else {
        result.write(
          '%${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}',
        );
      }
    }
    return result.toString();
  }

  static Map<String, String> _hiddenFields(Document document) => {
    for (final input in document.querySelectorAll('input[type="hidden"][name]'))
      input.attributes['name']!: input.attributes['value'] ?? '',
  };

  // The authenticated account dashboard also has password controls. Only the
  // actual sign-in controls identify an unauthenticated response.
  static bool _isLoginPage(Document document) =>
      document.querySelector('#ContentPlaceHolderMain_txtLoginISEP') != null ||
      document.querySelector(
            'input[name="ctl00\$ContentPlaceHolderMain\$txtLoginISEP"], '
            'input[name="ctl00\$ContentPlaceHolderMain\$txtPasswordISEP"]',
          ) !=
          null;
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
          status: _value(row, const ['estado', 'situacao']).ifEmpty('current'),
          ects: _number(_value(row, const ['ects', 'creditos'])),
          courseContext: _nullable(
            _value(row, const ['curso', 'plano estudos', 'ramo']),
          ),
        ),
      );
    }
    return _requireParsed(result, 'enrolment');
  }

  List<TimetableSlot> parseTimetable(String html, {required String sourceUrl}) {
    final document = html_parser.parse(html);
    final result = <TimetableSlot>[];
    // Portal serializes calendar records as JS literals. Parse the bounded
    // data grammar only; never evaluate code supplied by the remote page.
    for (final script in document.querySelectorAll('script')) {
      final source = script.text;
      if (!source.contains('function getEventData()')) continue;
      final events = RegExp(
        r'events\s*:\s*\[([\s\S]*?)\]\s*[,}]',
      ).firstMatch(source);
      if (events == null) continue;
      final entries = RegExp(
        r'\{([\s\S]*?)\}\s*,?',
      ).allMatches(events.group(1)!);
      if (entries.length > 500) return _requireParsed([], 'timetable');
      for (final entry in entries) {
        final value = entry.group(1)!;
        DateTime? date(String key) {
          final match = RegExp(
            "['\"]$key['\"]\\s*:\\s*new Date\\((\\d{4}),\\s*(\\d{1,2}),\\s*(\\d{1,2}),\\s*(\\d{1,2}),\\s*(\\d{1,2})\\)",
          ).firstMatch(value);
          if (match == null) return null;
          final parts = [
            for (var i = 1; i <= 5; i++) int.parse(match.group(i)!),
          ];
          final parsed = DateTime(
            parts[0],
            parts[1] + 1,
            parts[2],
            parts[3],
            parts[4],
          );
          return parsed.month == parts[1] + 1 &&
                  parsed.day == parts[2] &&
                  parsed.hour == parts[3] &&
                  parsed.minute == parts[4]
              ? parsed
              : null;
        }

        String literal(String key) {
          final match = RegExp(
            "['\"]$key['\"]\\s*:\\s*'((?:\\\\.|[^'\\\\])*)'",
          ).firstMatch(value);
          return (match?.group(1) ?? '')
              .replaceAll(r"\'", "'")
              .replaceAll(r'\n', ' ')
              .replaceAll(r'\\', r'\');
        }

        final start = date('start');
        final end = date('end');
        final title = html_parser.parseFragment(literal('title'));
        final body = html_parser.parseFragment(literal('body'));
        final cells = title.querySelectorAll('td');
        final subject = cells.length >= 2
            ? cells.last.text.trim()
            : title.text!.trim();
        if (start == null ||
            end == null ||
            !end.isAfter(start) ||
            subject.isEmpty) {
          return _requireParsed([], 'timetable');
        }
        final type = title.querySelector('label')?.text.trim();
        final season = body.querySelector('label')?.text.trim();
        final rooms = body
            .querySelectorAll('a[href]')
            .where(
              (a) =>
                  Uri.tryParse(
                    a.attributes['href']!,
                  )?.queryParameters.containsKey('room') ==
                  true,
            )
            .map((a) => a.text.trim())
            .where((text) => text.isNotEmpty)
            .toSet();
        result.add(
          TimetableSlot(
            externalId: '$subject:${start.toIso8601String()}:${type ?? ''}',
            subjectCode: subject,
            subjectName: subject,
            start: start,
            end: end,
            lessonType: [?type, ?season].join(' · '),
            room: rooms.isEmpty ? null : rooms.join(' · '),
            sourceUrl: sourceUrl,
            exceptional: type == 'Exame',
          ),
        );
      }
      if (entries.isEmpty) return const [];
    }
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
        _value(row, const ['estado inscricao', 'estado', 'inscricao']),
      );
      result.add(
        ExamRegistration(
          externalId: _examIdentity(row, code: code, name: name, type: type),
          subjectCode: code,
          subjectName: name,
          examType: type,
          state: state,
          sourceUrl: sourceUrl,
          registrationOpensAt: _dateTime(
            _value(row, const ['inicio inscricao', 'abertura']),
            _value(row, const ['hora abertura']),
          ),
          registrationClosesAt: _dateTime(
            _value(row, const ['fim inscricao', 'fecho', 'limite inscricao']),
            _value(row, const ['hora fecho']),
          ),
          examAt: _dateTime(
            _value(row, const ['data exame', 'data']),
            _value(row, const ['hora exame', 'hora']),
          ),
          fee: _nullable(_value(row, const ['taxa', 'valor', 'emolumento'])),
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
      final rawStatus = _value(row, const [
        'estado',
        'resultado final',
        'situacao',
      ]);
      final parsedEcts = _number(_value(row, const ['ects', 'creditos']));
      if ((name.isEmpty && code.isEmpty) ||
          (value == null &&
              (!forceHistorical ||
                  (rawStatus.isEmpty && parsedEcts == null)))) {
        continue;
      }
      final academicYear = _nullable(_value(row, const ['ano letivo', 'ano']));
      final status = _normalize(rawStatus);
      final isHistorical =
          forceHistorical ||
          row.keys.any((key) => key.contains('ects')) ||
          status.contains('aprov');
      final isFinal =
          isHistorical ||
          _normalize(component).contains('final') ||
          status.contains('definitiv');
      final id = _value(row, const ['id']).ifEmpty(
        '${code.ifEmpty(_normalize(name))}:${academicYear ?? ''}:${_normalize(component)}',
      );
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
          ects: parsedEcts,
          academicStatus: _nullable(rawStatus),
          courseContext: _nullable(
            _value(row, const ['curso', 'plano estudos', 'ramo']),
          ),
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

  List<FucProfile> parseFucProfiles(String html, {required String sourceUrl}) {
    final result = <FucProfile>[];
    for (final row in _tableRows(html)) {
      final name = _value(row, const [
        'unidade curricular',
        'disciplina',
        'uc',
      ]);
      final code = _value(row, const ['codigo', 'sigla', 'codigo uc']);
      if (name.isEmpty && code.isEmpty) continue;
      final year = _value(row, const ['ano letivo', 'ano', 'versao']);
      final id = _value(row, const [
        'id',
        'codigo uc',
      ]).ifEmpty('${_normalize(code.ifEmpty(name))}:${_normalize(year)}');
      result.add(
        FucProfile(
          id: id,
          subjectCode: code,
          subjectName: name.ifEmpty(code),
          academicYear: year,
          responsibleLecturer: _nullable(
            _value(row, const ['docente responsavel', 'responsavel']),
          ),
          lecturers: _splitList(
            _value(row, const ['outros docentes', 'docentes']),
          ),
          workload: _nullable(
            _value(row, const ['carga horaria', 'horas contacto', 'horas']),
          ),
          objectives: _splitList(
            _value(row, const [
              'objetivos',
              'resultados aprendizagem',
              'competencias',
            ]),
          ),
          syllabus: _splitList(
            _value(row, const ['programa', 'conteudos', 'syllabus']),
          ),
          bibliography: _splitList(_value(row, const ['bibliografia'])),
          methodologies: _splitList(
            _value(row, const ['metodologias', 'metodos ensino']),
          ),
          evaluationRules: _splitList(
            _value(row, const [
              'metodo avaliacao',
              'avaliacao',
              'regras avaliacao',
            ]),
          ),
          sourceUrl: sourceUrl,
        ),
      );
    }
    return _requireParsed(_dedupe(result, (item) => item.id), 'FUC details');
  }

  List<PortalNotification> parseNotifications(
    String html, {
    required String sourceUrl,
  }) {
    final result = <PortalNotification>[];
    for (final row in _tableRows(html)) {
      final title = _value(row, const ['assunto', 'titulo', 'notificacao']);
      final message = _value(row, const ['mensagem', 'conteudo', 'texto']);
      final created = _dateTime(
        _value(row, const ['data', 'enviado em']),
        _value(row, const ['hora']),
      );
      if ((title.isEmpty && message.isEmpty) || created == null) continue;
      final sender = _value(row, const ['remetente', 'emissor', 'de']);
      final id = _value(row, const ['id']).ifEmpty(
        '${created.toIso8601String()}:${_normalize(title.ifEmpty(message))}',
      );
      result.add(
        PortalNotification(
          id: id,
          title: title.ifEmpty('Portal notification'),
          sender: sender,
          createdAt: created,
          message: message,
          attachments: _splitList(_value(row, const ['anexos', 'ficheiros'])),
          sourceUrl: sourceUrl,
        ),
      );
    }
    return _requireParsed(_dedupe(result, (item) => item.id), 'notifications');
  }

  List<OfficialLessonSummary> parseLessonSummaries(
    String html, {
    required String sourceUrl,
  }) {
    final result = <OfficialLessonSummary>[];
    for (final row in _tableRows(html)) {
      final name = _value(row, const [
        'unidade curricular',
        'disciplina',
        'uc',
      ]);
      final code = _value(row, const ['codigo', 'sigla', 'codigo uc']);
      final text = _value(row, const ['sumario', 'conteudo', 'descricao']);
      final date = _dateTime(
        _value(row, const ['data', 'dia']),
        _value(row, const ['hora', 'inicio']),
      );
      if ((name.isEmpty && code.isEmpty) || text.isEmpty || date == null) {
        continue;
      }
      final id = _value(row, const [
        'id',
      ]).ifEmpty('${_normalize(code.ifEmpty(name))}:${date.toIso8601String()}');
      result.add(
        OfficialLessonSummary(
          id: id,
          subjectCode: code,
          subjectName: name.ifEmpty(code),
          date: date,
          text: text,
          className: _nullable(_value(row, const ['turma', 'classe'])),
          lessonType: _nullable(_value(row, const ['tipo', 'tipo aula'])),
          lecturer: _nullable(_value(row, const ['docente', 'professor'])),
          sourceUrl: sourceUrl,
        ),
      );
    }
    return _requireParsed(
      _dedupe(result, (item) => item.id),
      'lesson summaries',
    );
  }

  List<TuitionCharge> parseTuitionCharges(
    String html, {
    required String sourceUrl,
  }) {
    final result = <TuitionCharge>[];
    for (final row in _tableRows(html)) {
      final title = _value(row, const [
        'artigo(s)',
        'tipo',
        'descricao',
        'designacao',
        'rubrica',
        'servico',
        'encargo',
      ]);
      final academicYear = _nullable(
        _value(row, const ['ano letivo', 'ano academico', 'ano']),
      );
      final installment = _nullable(
        _value(row, const [
          'prestacao',
          'parcela',
          'numero prestacao',
          'n prestacao',
        ]),
      );
      final dueAt = _dateTime(
        _value(row, const [
          'data limite',
          'data vencimento',
          'vencimento',
          'prazo pagamento',
          'limite pagamento',
        ]),
        _value(row, const ['hora limite', 'hora vencimento']),
      );
      final status = _paymentState(
        _value(row, const ['estado', 'situacao', 'status']),
      );
      final amount = _money(
        _value(row, const [
          'valor doc.',
          'valor a pagar',
          'montante',
          'valor',
          'total',
        ]),
      );
      final outstanding = _money(
        _value(row, const [
          'valor pendente',
          'em divida',
          'valor em divida',
          'por pagar',
          'saldo',
          'restante',
        ]),
      );
      final rawReference = _value(row, const [
        'referencia multibanco',
        'referencia pagamento',
        'referencia',
      ]);
      final lateInterest = _value(row, const [
        'juros mora',
        'juros',
        'mora',
        'em atraso',
      ]);
      if (title.isEmpty &&
          academicYear == null &&
          installment == null &&
          dueAt == null) {
        continue;
      }
      final explicitId = _value(row, const [
        'nº documento',
        'id pagamento',
        'id cobranca',
        'id',
        'numero documento',
        'documento',
      ]);
      final id = explicitId.ifEmpty(
        _financialIdentity(
          title: title,
          academicYear: academicYear,
          installment: installment,
        ),
      );
      result.add(
        TuitionCharge(
          id: id,
          title: title.ifEmpty('Portal charge'),
          state: status,
          sourceUrl: sourceUrl,
          academicYear: academicYear,
          installment: installment,
          amount: amount,
          outstandingAmount: outstanding,
          dueAt: dueAt,
          paidAt: _dateTime(
            _value(row, const [
              'data pagamento',
              'pago em',
              'data liquidacao',
              'liquidado em',
            ]),
            _value(row, const ['hora pagamento', 'hora liquidacao']),
          ),
          hasLateInterest:
              _money(lateInterest) != null ||
              _normalize(lateInterest).contains('sim') ||
              _normalize(lateInterest).contains('atraso'),
          paymentReferenceAvailable: rawReference.isNotEmpty,
          paymentReferenceHint: _maskedReference(rawReference),
        ),
      );
    }
    final values = _dedupe(result, (item) => item.id);
    if (values.isNotEmpty) return values;
    final normalizedPage = _normalize(html);
    if (normalizedPage.contains('nao existem pagamentos') ||
        normalizedPage.contains('nao existem dividas') ||
        normalizedPage.contains('sem valores a pagamento')) {
      return const [];
    }
    return _requireParsed(values, 'tuition and payments');
  }

  static List<Map<String, String>> _tableRows(String html) {
    final document = html_parser.parse(html);
    for (final node in document.querySelectorAll(
      'script,style,noscript,template',
    )) {
      node.remove();
    }
    final result = <Map<String, String>>[];
    for (final table in document.querySelectorAll('table')) {
      final rows = table.querySelectorAll('tr').where((row) {
        Element? parent = row.parent;
        while (parent != null && parent.localName != 'table') {
          parent = parent.parent;
        }
        return parent == table;
      }).toList();
      if (rows.length < 2) continue;
      var headers = rows.first.children
          .where((cell) => cell.localName == 'th' || cell.localName == 'td')
          .map((cell) => _normalize(cell.text))
          .toList();
      if (headers.every((value) => value.isEmpty)) continue;
      for (final row in rows.skip(1)) {
        final cells = row.children
            .where((cell) => cell.localName == 'td')
            .toList();
        if (cells.any((cell) => cell.querySelector('table') != null)) continue;
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
        if (entry.key == alias) {
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

  static double? _money(String value) {
    var compact = value
        .replaceAll(RegExp(r'€|\bEUR\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^-?\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?$').hasMatch(compact)) {
      compact = compact.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^-?\d+(?:,\d{1,2})?$').hasMatch(compact)) {
      compact = compact.replaceAll(',', '.');
    } else if (!RegExp(r'^-?\d+\.\d{1,2}$').hasMatch(compact)) {
      return null;
    }
    return double.tryParse(compact);
  }

  static TuitionPaymentState _paymentState(String value) {
    final normalized = _normalize(value);
    if (normalized.contains('anulad') || normalized.contains('cancel')) {
      return TuitionPaymentState.cancelled;
    }
    if (normalized.contains('atras') || normalized.contains('vencid')) {
      return TuitionPaymentState.overdue;
    }
    if (normalized.contains('parcial')) return TuitionPaymentState.partial;
    if (normalized.contains('pend') ||
        normalized.contains('abert') ||
        normalized.contains('por pagar') ||
        normalized.contains('nao pag') ||
        normalized.contains('nao liquid') ||
        normalized.contains('pagamento')) {
      return TuitionPaymentState.pending;
    }
    if (normalized.contains('liquid') ||
        normalized.contains('pago') ||
        normalized.contains('paga') ||
        normalized.contains('regulariz')) {
      return TuitionPaymentState.paid;
    }
    return TuitionPaymentState.unknown;
  }

  static String _financialIdentity({
    required String title,
    required String? academicYear,
    required String? installment,
  }) => [
    _normalize(title),
    _normalize(academicYear ?? ''),
    _normalize(installment ?? 'single'),
  ].join(':');

  static String? _maskedReference(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return null;
    final suffix = compact.length <= 4
        ? compact
        : compact.substring(compact.length - 4);
    return '•••• $suffix';
  }

  static List<String> _splitList(String value) => value
      .split(RegExp(r'(?:\r?\n|;|\s[•·]\s)'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

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
    if (normalized.contains('agend') || normalized.contains('marcad')) {
      return ExamRegistrationState.scheduled;
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
