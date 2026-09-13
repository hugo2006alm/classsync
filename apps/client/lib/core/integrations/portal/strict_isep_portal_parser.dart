import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../domain/academic/academic_hub_models.dart';
import '../../../domain/academic/portal_record_validation.dart';
import '../integration_exception.dart';
import 'isep_portal_client.dart';

/// Fail-closed wrapper around the legacy Portal table parser.
///
/// The ISEP Portal still uses WebForms layout tables. Those tables can contain
/// navigation labels and inline JavaScript whose text accidentally resembles
/// short data headers such as `UC`, `valor`, or `servico`. The base parser is
/// intentionally tolerant of header variations, so production parsing first
/// narrows the HTML to tables that have a plausible schema for the feature.
class StrictIsepPortalParser extends IsepPortalParser {
  const StrictIsepPortalParser();

  @override
  List<GradeComponent> parseGrades(
    String html, {
    required String sourceUrl,
    bool forceHistorical = false,
  }) {
    if (!forceHistorical && _hasBoundedPartialGradeData(html)) {
      final values = super.parseGrades(
        html,
        sourceUrl: sourceUrl,
        forceHistorical: false,
      );
      return _rejectMarkupNoise(
        values,
        (item) => '${item.subjectCode} ${item.subjectName} ${item.name}',
        'grades',
      );
    }
    final historyHtml = forceHistorical
        ? _latestDatedStudentFileSection(html)
        : html;
    final values = super.parseGrades(
      _filterTables(historyHtml, [
        _subjectHeaders,
        ['ects', 'nota', 'classificacao', 'componente', 'elemento avaliacao'],
      ]),
      sourceUrl: sourceUrl,
      forceHistorical: forceHistorical,
    );
    return _rejectMarkupNoise(
      values,
      (item) => '${item.subjectCode} ${item.subjectName} ${item.name}',
      forceHistorical ? 'academic history' : 'grades',
    );
  }

  static String _latestDatedStudentFileSection(String html) {
    final document = html_parser.parse(html);
    final accordion = document.querySelector('#accordionStudentFile');
    if (accordion == null) return html;
    final candidates = <({int year, Element section})>[];
    Element? heading;
    for (final child in accordion.children) {
      if (child.localName == 'h3') {
        heading = child;
        continue;
      }
      if (heading == null) continue;
      final match = RegExp(
        r'\b(\d{4})\s*[/\-]\s*\d{2,4}\b',
      ).firstMatch(heading.text);
      if (match == null) continue;
      candidates.add((year: int.parse(match.group(1)!), section: child));
    }
    if (candidates.isEmpty) return html;
    candidates.sort((a, b) => b.year.compareTo(a.year));
    return candidates.first.section.outerHtml;
  }

  static bool _hasBoundedPartialGradeData(String html) {
    final document = html_parser.parse(html);
    final links = document.querySelectorAll('a[href]').where((link) {
      final href = link.attributes['href'] ?? '';
      return RegExp(
        r'^\s*javascript:\s*detailsDialog\s*\(\s*\{',
        caseSensitive: false,
      ).hasMatch(href);
    }).toList();
    return links.isNotEmpty &&
        links.length <= 500 &&
        links.every((link) => (link.attributes['href'] ?? '').length <= 20000);
  }

  @override
  List<EnrollmentSubject> parseEnrollment(
    String html, {
    required String sourceUrl,
  }) {
    final document = html_parser.parse(html);
    final yearLink = document.querySelector('a[href^="#tabDisc"]');
    final panel = yearLink == null
        ? null
        : document.querySelector(yearLink.attributes['href']!);
    if (panel != null) {
      final subjects = panel.querySelectorAll(
        'a[href*="ver_edicoes_disciplina.aspx"]',
      );
      if (subjects.isNotEmpty) {
        return subjects.map((a) {
          final uri = Uri.parse(sourceUrl).resolve(a.attributes['href']!);
          final id = uri.queryParameters['id']!;
          final semester = a.parent?.querySelector('strong')?.text ?? '';
          return EnrollmentSubject(
            externalId: id,
            code: '',
            name: a.text.trim(),
            academicYear: yearLink!.text.trim(),
            semester: semester,
            sourceUrl: sourceUrl,
          );
        }).toList();
      }
    }
    final values = super.parseEnrollment(
      _filterTables(html, [_subjectHeaders, _enrollmentHeaders]),
      sourceUrl: sourceUrl,
    );
    return _rejectMarkupNoise(
      values,
      (item) => '${item.code} ${item.name}',
      'enrolment',
    );
  }

  @override
  List<ExamRegistration> parseExamRegistrations(
    String html, {
    required String sourceUrl,
  }) {
    final values = super.parseExamRegistrations(
      _filterTables(html, [_subjectHeaders, _examRegistrationHeaders]),
      sourceUrl: sourceUrl,
    );
    if (values.any((item) => !isValidPortalRegistration(item.toJson()))) {
      throw _invalidRows('exam registration');
    }
    return _rejectMarkupNoise(
      values,
      (item) => '${item.subjectCode} ${item.subjectName} ${item.examType}',
      'exam registration',
    );
  }

  @override
  List<FucProfile> parseFucProfiles(String html, {required String sourceUrl}) {
    final values = super.parseFucProfiles(
      _filterTables(html, [_subjectHeaders, _fucDetailHeaders]),
      sourceUrl: sourceUrl,
    );
    return _rejectMarkupNoise(
      values,
      (item) => '${item.subjectCode} ${item.subjectName}',
      'FUC details',
    );
  }

  @override
  List<TuitionCharge> parseTuitionCharges(
    String html, {
    required String sourceUrl,
  }) {
    final values = super.parseTuitionCharges(
      _filterTables(html, [_tuitionIdentityHeaders, _tuitionEvidenceHeaders]),
      sourceUrl: sourceUrl,
    );
    if (values.any((item) => !isValidPortalTuition(item.toJson()))) {
      throw _invalidRows('tuition and payments');
    }
    return _rejectMarkupNoise(
      values,
      (item) => item.title,
      'tuition and payments',
    );
  }

  static const _subjectHeaders = <String>[
    'codigo',
    'codigo uc',
    'sigla',
    'unidade curricular',
    'disciplina',
    'uc',
    'nome',
  ];

  static const _enrollmentHeaders = <String>[
    'ano letivo',
    'academic year',
    'semestre',
    'periodo',
    'ects',
    'creditos',
    'estado',
    'situacao',
  ];

  static const _examRegistrationHeaders = <String>[
    'epoca',
    'tipo',
    'avaliacao',
    'estado inscricao',
    'estado',
    'inscricao',
    'inicio inscricao',
    'abertura',
    'fim inscricao',
    'fecho',
    'data exame',
    'taxa',
    'valor',
    'emolumento',
    'inscrever',
    'acao',
  ];

  static const _fucDetailHeaders = <String>[
    'ano letivo',
    'versao',
    'docente responsavel',
    'responsavel',
    'docentes',
    'carga horaria',
    'horas contacto',
    'objetivos',
    'resultados aprendizagem',
    'programa',
    'conteudos',
    'bibliografia',
    'metodologias',
    'metodo avaliacao',
    'avaliacao',
  ];

  static const _tuitionIdentityHeaders = <String>[
    'artigo(s)',
    'nº documento',
    'tipo',
    'descricao',
    'designacao',
    'rubrica',
    'servico',
    'servicos',
    'encargo',
    'prestacao',
    'parcela',
    'documento',
    'numero documento',
  ];

  static const _tuitionEvidenceHeaders = <String>[
    'valor doc.',
    'valor pago',
    'valor pendente',
    'valor a pagar',
    'montante',
    'valor',
    'total',
    'em divida',
    'valor em divida',
    'por pagar',
    'saldo',
    'restante',
    'data limite',
    'data vencimento',
    'vencimento',
    'prazo pagamento',
    'referencia multibanco',
    'referencia pagamento',
    'referencia',
    'data pagamento',
    'pago em',
    'juros mora',
  ];

  static String _filterTables(
    String html,
    List<List<String>> requiredHeaderGroups,
  ) {
    final document = html_parser.parse(html);
    for (final element
        in document
            .querySelectorAll('script,style,noscript,template')
            .toList()) {
      element.remove();
    }

    final tables = document
        .querySelectorAll('table')
        .where((table) {
          final rows = _directRows(table);
          if (rows.length < 2) return false;
          final headers = _directCells(rows.first)
              .map((cell) => SubjectMapper.normalize(cell.text))
              .where((value) => value.isNotEmpty)
              .toList();
          if (headers.length < requiredHeaderGroups.length ||
              headers.any((value) => value.length > 120)) {
            return false;
          }
          return _matchesSchema(headers, requiredHeaderGroups);
        })
        .map((table) => table.outerHtml);

    // Preserve harmless page text so the base payments parser can still
    // recognise official empty-state messages such as "não existem dívidas".
    final pageText = (document.body?.text ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final escapedText = const HtmlEscape().convert(pageText);
    return '<!doctype html><html><body><p>$escapedText</p>${tables.join()}</body></html>';
  }

  static List<Element> _directRows(Element table) {
    final rows = <Element>[];
    for (final child in table.children) {
      if (child.localName == 'tr') {
        rows.add(child);
      } else if (child.localName == 'thead' ||
          child.localName == 'tbody' ||
          child.localName == 'tfoot') {
        rows.addAll(child.children.where((item) => item.localName == 'tr'));
      }
    }
    return rows;
  }

  static Iterable<Element> _directCells(Element row) => row.children.where(
    (item) => item.localName == 'th' || item.localName == 'td',
  );

  static bool _matchesSchema(
    List<String> headers,
    List<List<String>> requiredHeaderGroups,
  ) {
    final recognized = headers
        .where(
          (header) => requiredHeaderGroups
              .expand((group) => group)
              .any((alias) => _matchesHeader(header, alias)),
        )
        .toSet();
    if (recognized.length < 3) return false;
    final usedIndexes = <int>{};
    for (final group in requiredHeaderGroups) {
      var matchedIndex = -1;
      for (var index = 0; index < headers.length; index++) {
        if (usedIndexes.contains(index)) continue;
        if (group.any((alias) => _matchesHeader(headers[index], alias))) {
          matchedIndex = index;
          break;
        }
      }
      if (matchedIndex < 0) return false;
      usedIndexes.add(matchedIndex);
    }
    return true;
  }

  static bool _matchesHeader(String header, String alias) =>
      header == SubjectMapper.normalize(alias);

  static List<T> _rejectMarkupNoise<T>(
    List<T> values,
    String Function(T) searchableText,
    String feature,
  ) {
    if (values.isEmpty) return values;
    final clean = values
        .where((item) => !_looksLikeMarkupNoise(searchableText(item)))
        .toList();
    if (clean.length == values.length) return clean;
    throw IntegrationException(
      integration: 'ISEP Portal',
      code: 'portal_layout_changed',
      userMessage:
          'ISEP Portal $feature page format was not recognized. No partial data was saved.',
      retryable: false,
    );
  }

  static bool _looksLikeMarkupNoise(String value) {
    final lower = value.toLowerCase();
    return value.length > 240 ||
        lower.contains(r'$(') ||
        lower.contains('function') ||
        lower.contains('menulink') ||
        lower.contains('ui-icon-') ||
        lower.contains('border-style') ||
        lower.contains('contentplaceholdermain');
  }

  static IntegrationException _invalidRows(
    String feature,
  ) => IntegrationException(
    integration: 'ISEP Portal',
    code: 'portal_layout_changed',
    userMessage:
        'ISEP Portal $feature contained unrecognized records. No partial data was saved.',
    retryable: false,
  );
}
