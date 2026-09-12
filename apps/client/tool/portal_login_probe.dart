import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:classsync/core/integrations/portal/isep_portal_client.dart';
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
            'safeStructure': _safeStructure(body),
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
    final client = IsepPortalClient(dio: dio);
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
        final values = await client.getTimetable();
        return {
          'events': values.length,
          'withRoom': values.where((item) => item.room != null).length,
          'withTeacher': values.where((item) => item.lecturer != null).length,
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
          final path = uri?.path ?? '';
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
