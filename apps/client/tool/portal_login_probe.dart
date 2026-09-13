import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:classsync/core/integrations/portal/isep_portal_client.dart';
import 'package:classsync/core/integrations/portal/strict_isep_portal_parser.dart';
import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/bounded_response.dart';

Future<void> main() async {
  final input = jsonDecode(stdin.readLineSync()!) as Map<String, dynamic>;
  final steps = <Object>[];
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://portal.isep.ipp.pt/intranet/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'accept': 'text/html,application/xhtml+xml',
        'accept-language': 'pt-PT,pt;q=0.9,en;q=0.7',
        'user-agent':
            'Mozilla/5.0 ClassSync/0.3 (ISEP Portal read-only client)',
      },
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) async {
        late final List<int> bytes;
        try {
          bytes = await readBoundedResponse(response.data, response.headers);
        } catch (_) {
          handler.reject(DioException(requestOptions: response.requestOptions));
          return;
        }
        final body = latin1.decode(bytes);
        final path = response.requestOptions.uri.path;
        var structureBody = body;
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map && decoded['d'] is String) {
            structureBody = decoded['d'] as String;
          }
        } catch (_) {
          // The structure reporter also accepts ordinary HTML responses.
        }
        steps.add({
          'method': response.requestOptions.method,
          'path': path,
          'status': response.statusCode,
          'redirectPath': Uri.tryParse(
            response.headers.value('location') ?? '',
          )?.path,
          'cookieNames': (response.headers['set-cookie'] ?? [])
              .map((c) => c.split('=').first)
              .toList(),
          'loginField': body.contains(
            'id="ContentPlaceHolderMain_txtLoginISEP"',
          ),
          'passwordField': body.contains('type="password"'),
          'scriptRedirect': RegExp(
            r'(?:location\s*=|location\.href\s*=|location\.replace\s*\()',
          ).hasMatch(body),
          'invalidLoginText': RegExp(
            r'(?:incorret|incorrect|inv.lid|falhou|errad)',
            caseSensitive: false,
          ).hasMatch(body.replaceAll(RegExp(r'<script[\s\S]*?</script>'), '')),
          if (RegExp(
            r'(?:horario|estudante|pagamentos|propinas|areadetrabalho)',
          ).hasMatch(path.toLowerCase()))
            'safeStructure': _safeStructure(structureBody),
          if (path.endsWith('/getPartialGradesEvent'))
            'safeGradeParse': _safeGradeParse(structureBody),
          if (path.endsWith('/getStudentFileEvent'))
            'safeGradeParse': _safeGradeParse(structureBody, historical: true),
          if (path.endsWith('/mudar_semana'))
            'safeTimetableParse': _safeTimetableParse(structureBody),
        });
        response.data = ResponseBody.fromBytes(
          bytes,
          response.statusCode!,
          headers: response.headers.map,
        );
        handler.next(response);
      },
    ),
  );
  try {
    final client = IsepPortalClient(
      dio: dio,
      parser: const StrictIsepPortalParser(),
    );
    await client.authenticate(
      PortalCredentials(
        username: input['username'] as String,
        password: input['password'] as String,
      ),
    );
    final sessionValid = await client.validateSession();
    final features = <String, Object>{};
    if (sessionValid) {
      features['timetable'] = await _probeFeature(() async {
        final values = await client.getTimetable(
          from: DateTime.now(),
          weeks: 5,
        );
        final starts = values.map((item) => item.start).toList()..sort();
        final weeklyCounts = <String, int>{};
        for (final item in values) {
          final monday = DateTime(
            item.start.year,
            item.start.month,
            item.start.day,
          ).subtract(Duration(days: item.start.weekday - DateTime.monday));
          final key = monday.toIso8601String().split('T').first;
          weeklyCounts[key] = (weeklyCounts[key] ?? 0) + 1;
        }
        return {
          'events': values.length,
          'withRoom': values.where((item) => item.room != null).length,
          'withTeacher': values.where((item) => item.lecturer != null).length,
          if (starts.isNotEmpty)
            'firstDate': starts.first.toIso8601String().split('T').first,
          if (starts.isNotEmpty)
            'lastDate': starts.last.toIso8601String().split('T').first,
          'weekdays': (values.map((item) => item.start.weekday).toSet().toList()
            ..sort()),
          'weeklyCounts': weeklyCounts,
        };
      });
      features['currentGrades'] = await _probeFeature(() async {
        final values = await client.getGrades();
        return {'records': values.length};
      });
      features['academicHistory'] = await _probeFeature(() async {
        final values = await client.getAcademicHistory();
        return {'records': values.length};
      });
      features['finance'] = await _probeFeature(() async {
        final values = await client.getTuitionCharges();
        return {'records': values.length};
      });
    }
    stdout.write(
      jsonEncode({
        'result': sessionValid ? 'success' : 'session_validation_failed',
        'features': features,
        'steps': steps,
      }),
    );
  } on IntegrationException catch (error) {
    stdout.write(jsonEncode({'result': error.code, 'steps': steps}));
  } catch (_) {
    stdout.write(jsonEncode({'result': 'probe_error', 'steps': steps}));
  }
}

Map<String, Object> _safeTimetableParse(String html) {
  try {
    final values = const IsepPortalParser().parseTimetable(
      html,
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/ver_horario/ver_horario.aspx',
    );
    final starts = values.map((item) => item.start).toList()..sort();
    return {
      'status': 'ok',
      'records': values.length,
      if (starts.isNotEmpty)
        'firstDate': starts.first.toIso8601String().split('T').first,
      if (starts.isNotEmpty)
        'lastDate': starts.last.toIso8601String().split('T').first,
    };
  } on IntegrationException catch (error) {
    return {'status': error.code};
  } catch (_) {
    return {'status': 'parse_error'};
  }
}

Map<String, Object> _safeGradeParse(String html, {bool historical = false}) {
  try {
    final values = const IsepPortalParser().parseGrades(
      html,
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
      forceHistorical: historical,
    );
    return {'status': 'ok', 'records': values.length};
  } on IntegrationException catch (error) {
    return {'status': error.code};
  } catch (_) {
    return {'status': 'parse_error'};
  }
}

Map<String, Object> _safeStructure(String html) {
  final document = html_parser.parse(html);
  const allowedLabels = [
    'segunda',
    'terça',
    'terca',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'sabado',
    'domingo',
    'hora',
    'horário',
    'horario',
    'sala',
    'docente',
    'professor',
    'turma',
    'unidade curricular',
    'disciplina',
    'classificação',
    'classificacao',
    'nota',
    'resultado',
    'avaliação',
    'avaliacao',
    'elemento',
    'tipo',
    'plano letivo',
    'plano de estudos',
    'época',
    'epoca',
    'semestre',
    'período',
    'periodo',
    'curso',
    'estado',
    'ano letivo',
    'ects',
    'créditos',
    'creditos',
    'valor',
    'vencimento',
    'referência',
    'referencia',
    'pagamento',
  ];
  return {
    'scriptIds': document
        .querySelectorAll('script[id]')
        .map((item) => item.id)
        .where((item) => item.isNotEmpty)
        .take(20)
        .toList(),
    'scriptSources': document
        .querySelectorAll('script[src]')
        .map((item) => Uri.tryParse(item.attributes['src'] ?? '')?.path ?? '')
        .where((item) => item.isNotEmpty)
        .take(30)
        .toList(),
    'scriptMarkers': {
      'events': RegExp(r'events\s*:').hasMatch(html),
      'getEventData': html.contains('getEventData'),
      'fullCalendar': html.toLowerCase().contains('calendar'),
    },
    'calendarShape': _calendarShape(document),
    'gradeGrammar': _gradeGrammarShape(document),
    'routePaths': _routePaths(html),
    'ajaxUrls': RegExp(r'''url\s*:\s*["']([^"']+)["']''', caseSensitive: false)
        .allMatches(html)
        .map((match) => match.group(1)!)
        .where((url) => url.toLowerCase().contains('.aspx/'))
        .toSet()
        .take(30)
        .toList(),
    'functionShapes': _functionShapes(html),
    'scriptShapes': _scriptShapes(document),
    'tables': document.querySelectorAll('table').take(30).map((table) {
      final rows = table.querySelectorAll('tr');
      return {
        'id': table.id,
        'class': table.className,
        'rowCount': rows.length,
        'rows': rows.take(20).map((row) {
          final cells = row.children
              .where((item) => item.localName == 'th' || item.localName == 'td')
              .toList();
          final normalized = row.text.toLowerCase();
          return {
            'cells': cells.length,
            'tags': cells.map((item) => item.localName).toList(),
            'classes': cells.map((item) => item.className).toList(),
            'colspans': cells
                .map((item) => item.attributes['colspan'] ?? '1')
                .toList(),
            'rowspans': cells
                .map((item) => item.attributes['rowspan'] ?? '1')
                .toList(),
            'links': cells
                .map((item) => item.querySelectorAll('a').length)
                .toList(),
            'allowedLabels': allowedLabels
                .where((label) => normalized.contains(label))
                .toList(),
          };
        }).toList(),
      };
    }).toList(),
    'controls': document
        .querySelectorAll('input, select, button')
        .map(
          (item) => {
            'tag': item.localName ?? '',
            'id': item.id,
            'name': item.attributes['name'] ?? '',
            'type': item.attributes['type'] ?? '',
          },
        )
        .where(
          (item) =>
              item['id']!.isNotEmpty ||
              item['name']!.isNotEmpty ||
              item['type']!.isNotEmpty,
        )
        .take(60)
        .toList(),
    'featureLinks': document
        .querySelectorAll('a[href]')
        .map((item) {
          final raw = item.attributes['href'] ?? '';
          final uri = Uri.tryParse(raw);
          final isPageLink =
              uri != null &&
              (uri.scheme.isEmpty || uri.scheme == 'https') &&
              RegExp(
                r'\.(?:aspx?|php)$',
                caseSensitive: false,
              ).hasMatch(uri.path);
          final path = isPageLink ? uri.path : '';
          final normalized = _normalize(
            '${item.text} ${item.attributes['title'] ?? ''} $path',
          );
          return {
            'path': path,
            'hrefShape': _safeActionShape(raw),
            'onclickShape': _safeActionShape(item.attributes['onclick'] ?? ''),
            'routes': _routePaths('$raw ${item.attributes['onclick'] ?? ''}'),
            'action': raw.toLowerCase().startsWith('javascript:')
                ? RegExp(
                        r'javascript:\s*([\w.]+)',
                        caseSensitive: false,
                      ).firstMatch(raw)?.group(1) ??
                      'javascript'
                : RegExp(r'^\s*([\w.]+)\s*\(')
                          .firstMatch(item.attributes['onclick'] ?? '')
                          ?.group(1) ??
                      '',
            'labels': const [
              'horario',
              'classific',
              'nota',
              'histor',
              'registo academico',
              'finance',
              'pagamento',
              'propina',
            ].where(normalized.contains).toList(),
          };
        })
        .where((item) => (item['labels']! as List<String>).isNotEmpty)
        .take(40)
        .toList(),
    'leafTables': document
        .querySelectorAll('table')
        .where((table) => table.querySelector('table') == null)
        .map((table) {
          final rows = table.querySelectorAll('tr');
          return {
            'id': table.id,
            'class': table.className,
            'rowCount': rows.length,
            'rows': rows.take(12).map((row) {
              final cells = row.children
                  .where(
                    (item) => item.localName == 'th' || item.localName == 'td',
                  )
                  .toList();
              return {
                'cells': cells.length,
                'labelsByCell': cells
                    .map(
                      (cell) => allowedLabels
                          .where(
                            (label) => _normalize(
                              cell.text,
                            ).contains(_normalize(label)),
                          )
                          .toList(),
                    )
                    .toList(),
              };
            }).toList(),
          };
        })
        .take(100)
        .toList(),
  };
}

Map<String, Object> _calendarShape(Document document) {
  final relevantScripts = document
      .querySelectorAll('script:not([src])')
      .map((script) => script.text)
      .where(
        (source) =>
            source.contains('getEventData') ||
            source.toLowerCase().contains('fullcalendar'),
      )
      .toList();
  final statements = relevantScripts
      .expand((source) => source.split(RegExp(r'[;\n]')))
      .map((statement) => statement.trim())
      .where(
        (statement) => RegExp(
          r'calendar|event|date|week|prev|next|goto|location|ajax|url',
          caseSensitive: false,
        ).hasMatch(statement),
      )
      .map(_safeActionShape)
      .where((statement) => statement.isNotEmpty)
      .take(80)
      .toList();
  final navigationLinks = document
      .querySelectorAll('a[href], button[onclick], input[onclick]')
      .map(
        (element) =>
            '${element.attributes['href'] ?? ''} ${element.attributes['onclick'] ?? ''}',
      )
      .where(
        (action) => RegExp(
          r'calendar|date|week|prev|next|horario|data|semana',
          caseSensitive: false,
        ).hasMatch(action),
      )
      .map(_safeActionShape)
      .take(40)
      .toList();
  final queryKeys = relevantScripts
      .expand(
        (source) => RegExp(
          r'[?&]([A-Za-z_]\w*)=',
        ).allMatches(source).map((match) => match.group(1)!),
      )
      .toSet()
      .toList();
  final eventKeys = relevantScripts
      .expand(
        (source) => RegExp(
          r'''(?:^|[,\{])\s*["']?([A-Za-z_]\w*)["']?\s*:''',
          multiLine: true,
        ).allMatches(source).map((match) => match.group(1)!),
      )
      .toSet()
      .toList();
  return {
    'statements': statements,
    'navigationLinks': navigationLinks,
    'queryKeys': queryKeys,
    'eventKeys': eventKeys,
    'eventGrammar': _eventGrammarShape(relevantScripts),
  };
}

Map<String, Object> _eventGrammarShape(List<String> scripts) {
  final entries = <String>[];
  for (final source in scripts) {
    final events = RegExp(
      r'events\s*:\s*\[([\s\S]*?)\]\s*[,}]',
    ).firstMatch(source);
    if (events == null) continue;
    entries.addAll(
      RegExp(
        r'\{([\s\S]*?)\}\s*,?',
      ).allMatches(events.group(1)!).map((match) => match.group(1)!),
    );
  }

  String quoteStyle(String value, String key) {
    final match = RegExp("['\"]$key['\"]\\s*:\\s*(['\"])").firstMatch(value);
    return switch (match?.group(1)) {
      "'" => 'single',
      '"' => 'double',
      _ => 'missing',
    };
  }

  bool hasDate(String value, String key) => RegExp(
    "['\"]$key['\"]\\s*:\\s*new Date\\(\\d{4},\\s*\\d{1,2},\\s*\\d{1,2},\\s*\\d{1,2},\\s*\\d{1,2}\\)",
  ).hasMatch(value);

  DateTime? date(String value, String key) {
    final match = RegExp(
      "['\"]$key['\"]\\s*:\\s*new Date\\((\\d{4}),\\s*(\\d{1,2}),\\s*(\\d{1,2}),\\s*(\\d{1,2}),\\s*(\\d{1,2})\\)",
    ).firstMatch(value);
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
    return DateTime(parts[0], parts[1] + 1, parts[2], parts[3], parts[4]);
  }

  bool exactDate(String value, String key) {
    final match = RegExp(
      "['\"]$key['\"]\\s*:\\s*new Date\\((\\d{4}),\\s*(\\d{1,2}),\\s*(\\d{1,2}),\\s*(\\d{1,2}),\\s*(\\d{1,2})\\)",
    ).firstMatch(value);
    if (match == null) return false;
    final parts = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
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
        parsed.minute == parts[4];
  }

  String literal(String value, String key) {
    final match = RegExp(
      "['\"]$key['\"]\\s*:\\s*'((?:\\\\.|[^'\\\\])*)'",
    ).firstMatch(value);
    return (match?.group(1) ?? '')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\\', r'\');
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  final shapes = entries.indexed.map((indexed) {
    final (index, value) = indexed;
    final title = html_parser.parseFragment(literal(value, 'title'));
    final body = html_parser.parseFragment(literal(value, 'body'));
    final footer = html_parser.parseFragment(literal(value, 'footer'));
    final subjectLinks = [title, body, footer]
        .expand((fragment) => fragment.querySelectorAll('a[title]'))
        .where((link) {
          final label = compact(link.attributes['title'] ?? '').toLowerCase();
          return label.contains('disciplina') ||
              label.contains('unidade curricular');
        })
        .toList();
    final start = date(value, 'start');
    final end = date(value, 'end');
    final fallbackSubject = title
        .querySelectorAll('td')
        .where((cell) => cell.querySelector('label') == null)
        .map((cell) => compact(cell.text))
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    var individualParse = 'ok';
    try {
      const IsepPortalParser().parseTimetable(
        '<script>function getEventData(){return {events:[{$value}]};}</script>',
        sourceUrl: 'https://portal.isep.ipp.pt/intranet/ver_horario/',
      );
    } on IntegrationException catch (error) {
      individualParse = error.code;
    } catch (_) {
      individualParse = 'parse_error';
    }
    return {
      'index': index,
      'individualParse': individualParse,
      'start': hasDate(value, 'start'),
      'end': hasDate(value, 'end'),
      'startExact': exactDate(value, 'start'),
      'endExact': exactDate(value, 'end'),
      'durationMinutes': start == null || end == null
          ? null
          : end.difference(start).inMinutes,
      'titleQuote': quoteStyle(value, 'title'),
      'bodyQuote': quoteStyle(value, 'body'),
      'footerQuote': quoteStyle(value, 'footer'),
      'titleChars': compact(title.text ?? '').length,
      'fallbackSubjectChars': fallbackSubject.length,
      'subjectLinkChars': subjectLinks.isEmpty
          ? null
          : compact(subjectLinks.first.text).length,
      'subjectLink': RegExp(
        r'''title\s*=\s*["'](?:disciplina|unidade curricular)["']''',
        caseSensitive: false,
      ).hasMatch(value),
      'td': RegExp(r'<td\b', caseSensitive: false).allMatches(value).length,
      'label': RegExp(
        r'<label\b',
        caseSensitive: false,
      ).allMatches(value).length,
      'links': RegExp(r'<a\b', caseSensitive: false).allMatches(value).length,
    };
  }).toList();
  return {'entries': entries.length, 'shapes': shapes};
}

Map<String, Object> _gradeGrammarShape(Document document) {
  final detailLinks = document.querySelectorAll('a[href]').where((link) {
    final href = link.attributes['href'] ?? '';
    return RegExp(
      r'^\s*javascript:\s*detailsDialog\s*\(\s*\{',
      caseSensitive: false,
    ).hasMatch(href);
  }).toList();
  var withSubject = 0;
  var withComponents = 0;
  var componentObjects = 0;
  var numericGrades = 0;
  for (final link in detailLinks) {
    final href = link.attributes['href'] ?? '';
    if (RegExp(r'''(?:^|[,\{])\s*uc\s*:\s*["']''').hasMatch(href)) {
      withSubject++;
    }
    final components = RegExp(
      r'\btrs\s*:\s*\[([\s\S]*?)\]\s*,',
    ).firstMatch(href)?.group(1);
    if (components == null) continue;
    withComponents++;
    final objects = RegExp(r'\{([^{}]*)\}').allMatches(components).toList();
    componentObjects += objects.length;
    numericGrades += objects.where((object) {
      final body = object.group(1)!;
      return RegExp(
        r'''(?:^|[,\{])\s*g\s*:\s*["']\s*-?\d+(?:[.,]\d+)?\s*["']''',
      ).hasMatch(body);
    }).length;
  }

  var historyTables = 0;
  var historyRows = 0;
  var numericHistoryGrades = 0;
  var numericHistoryEcts = 0;
  for (final table in document.querySelectorAll('table')) {
    if (table.querySelector('table') != null) continue;
    final rows = table.querySelectorAll('tr');
    if (rows.length < 2) continue;
    final headers = rows.first.children
        .where((cell) => cell.localName == 'th' || cell.localName == 'td')
        .map((cell) => _normalize(cell.text).trim())
        .toList();
    final subjectIndex = headers.indexOf('unidade curricular');
    final gradeIndex = headers.indexOf('nota');
    final ectsIndex = headers.indexWhere((header) => header.contains('ects'));
    if (subjectIndex < 0 || gradeIndex < 0 || ectsIndex < 0) continue;
    historyTables++;
    for (final row in rows.skip(1)) {
      final cells = row.children
          .where((cell) => cell.localName == 'th' || cell.localName == 'td')
          .toList();
      if (cells.length <=
          [
            subjectIndex,
            gradeIndex,
            ectsIndex,
          ].reduce((left, right) => left > right ? left : right)) {
        continue;
      }
      if (cells[subjectIndex].text.trim().isEmpty) continue;
      historyRows++;
      if (double.tryParse(cells[gradeIndex].text.trim().replaceAll(',', '.')) !=
          null) {
        numericHistoryGrades++;
      }
      if (double.tryParse(cells[ectsIndex].text.trim().replaceAll(',', '.')) !=
          null) {
        numericHistoryEcts++;
      }
    }
  }
  return {
    'detailLinks': detailLinks.length,
    'detailLinksWithSubject': withSubject,
    'detailLinksWithComponents': withComponents,
    'componentObjects': componentObjects,
    'numericComponentGrades': numericGrades,
    'historyTables': historyTables,
    'historyRows': historyRows,
    'numericHistoryGrades': numericHistoryGrades,
    'numericHistoryEcts': numericHistoryEcts,
  };
}

String _safeActionShape(String value) {
  if (value.isEmpty) return '';
  return value
      .replaceAll(RegExp(r"'[^']*'"), "'string'")
      .replaceAll(RegExp(r'"[^"]*"'), '"string"')
      .replaceAll(RegExp(r'\b\d+\b'), '#')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _routePaths(String value) => RegExp(
  r'''[A-Za-z0-9_./-]+\.(?:aspx|asp)''',
  caseSensitive: false,
).allMatches(value).map((match) => match.group(0)!).toSet().take(20).toList();

List<Map<String, Object>> _scriptShapes(Document document) {
  const names = [
    'getStudentFile',
    'getDisciplines',
    'getUserDebits',
    'getPartialGrades',
  ];
  final result = <Map<String, Object>>[];
  for (final script in document.querySelectorAll('script:not([src])')) {
    final source = script.text;
    for (final name in names) {
      final index = source.indexOf(name);
      if (index < 0) continue;
      final end = (index + 2200).clamp(0, source.length);
      final excerpt = source.substring(index, end);
      result.add({
        'name': name,
        'routes': _routePaths(excerpt),
        'shape': _safeActionShape(excerpt),
      });
    }
  }
  return result.take(12).toList();
}

List<Map<String, Object>> _functionShapes(String html) {
  const names = [
    'getStudentFile',
    'getDisciplines',
    'getUserDebits',
    'getPartialGrades',
  ];
  final result = <Map<String, Object>>[];
  for (final name in names) {
    final definition = RegExp(
      'function\\s+$name\\s*\\(([^)]*)\\)\\s*\\{([\\s\\S]{0,6000}?)\\n\\}',
      caseSensitive: false,
    ).firstMatch(html);
    final body = definition?.group(2) ?? '';
    final routes =
        RegExp(
              r'''[A-Za-z0-9_./-]+\.(?:aspx|asp)(?:\?[A-Za-z0-9_=&%+.-]*)?''',
              caseSensitive: false,
            )
            .allMatches(body)
            .map((match) => match.group(0)!)
            .map((route) => Uri.tryParse(route)?.path ?? route.split('?').first)
            .toSet()
            .take(20)
            .toList();
    final calls = RegExp(r'\b([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*\(')
        .allMatches(body)
        .map((match) => match.group(1)!)
        .where(
          (call) => !const {
            'if',
            'for',
            'while',
            'switch',
            'function',
          }.contains(call),
        )
        .toSet()
        .take(30)
        .toList();
    final invocations = html_parser
        .parse(html)
        .querySelectorAll('a[href]')
        .map((link) => link.attributes['href'] ?? '')
        .where(
          (href) => RegExp(
            'javascript:\\s*$name\\s*\\(',
            caseSensitive: false,
          ).hasMatch(href),
        )
        .map((href) {
          final args = RegExp(r'\((.*)\)').firstMatch(href)?.group(1) ?? '';
          final values = args.trim().isEmpty
              ? const <String>[]
              : args.split(',');
          return {
            'argumentCount': values.length,
            'argumentTypes': values
                .map(
                  (value) =>
                      value.trimLeft().startsWith("'") ||
                          value.trimLeft().startsWith('"')
                      ? 'string'
                      : RegExp(r'^\s*\d+\s*$').hasMatch(value)
                      ? 'number'
                      : 'expression',
                )
                .toList(),
          };
        })
        .take(10)
        .toList();
    result.add({
      'name': name,
      'found': definition != null,
      'parameters': (definition?.group(1) ?? '')
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'routes': routes,
      'calls': calls,
      'invocations': invocations,
    });
  }
  return result;
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[áàâãä]'), 'a')
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[íìîï]'), 'i')
    .replaceAll(RegExp(r'[óòôõö]'), 'o')
    .replaceAll(RegExp(r'[úùûü]'), 'u')
    .replaceAll('ç', 'c');

Future<Object> _probeFeature(
  Future<Map<String, Object>> Function() read,
) async {
  try {
    return {'status': 'ok', ...await read()};
  } on IntegrationException catch (error) {
    return {'status': error.code};
  } catch (_) {
    return {'status': 'probe_error'};
  }
}
