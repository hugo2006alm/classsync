import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/portal/strict_isep_portal_parser.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = StrictIsepPortalParser();

  test('rejects finance form labels even under plausible column headers', () {
    expect(
      () => parser.parseTuitionCharges('''<table>
      <tr><th>Descrição</th><th>Valor</th><th>Prestação</th></tr>
      <tr><td>Ano Letivo : 2026/2027</td><td>2026/2027</td><td></td></tr>
      <tr><td>Anual</td><td></td><td></td></tr>
      </table>''', sourceUrl: 'https://portal.isep.ipp.pt/intranet/finance'),
      throwsA(isA<IntegrationException>()),
    );
  });

  test('academic year is not a monetary amount; unpaid is not paid', () {
    const html =
        '''<table><tr><th>Descrição</th><th>Valor</th><th>Vencimento</th><th>Estado</th></tr>
      <tr><td>Propina</td><td>2026/2027</td><td>15/10/2026</td><td>Por pagar</td></tr></table>''';
    final charge = parser
        .parseTuitionCharges(
          html,
          sourceUrl: 'https://portal.isep.ipp.pt/payments',
        )
        .single;
    expect(charge.amount, isNull);
    expect(charge.state, TuitionPaymentState.pending);
  });

  test('rejects payment form labels as exam registration subjects', () {
    expect(
      () => parser.parseExamRegistrations('''<table>
      <tr><th>UC</th><th>Tipo</th><th>Estado</th></tr>
      <tr><td>Data da Liquidação (aaaa-mm-dd)</td><td></td><td></td></tr>
      </table>''', sourceUrl: 'https://portal.isep.ipp.pt/intranet/exams'),
      throwsA(isA<IntegrationException>()),
    );
  });

  test(
    'imports student finance grid without conflating document and pending amounts',
    () {
      final values = parser.parseTuitionCharges(
        '''<div class="AspNet-GridView"><table>
      <thead><tr><td>Data</td><td>Documento</td><td>Nº Documento</td><td>Nº Recibo</td><td>Artigo(s)</td><td>Valor Doc.</td><td>Valor Pago</td><td>Valor Pendente</td><td>Estado</td></tr></thead>
      <tbody><tr><td>2026-08-24 18:04</td><td>Fatura</td><td>FT-TEST-1</td><td>RC-TEST-1</td><td>Seguro Escolar; Taxa de Inscrição</td><td>30.00€</td><td>30.00€</td><td>0.00€</td><td>Liquidada</td></tr>
      <tr><td>2026-08-24 18:04</td><td>Fatura</td><td>FT-TEST-2</td><td></td><td>Propina</td><td>69.70€</td><td>0.00€</td><td>69.70€</td><td>Pendente</td></tr></tbody>
      </table></div>''',
        sourceUrl:
            'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
      );
      expect(values, hasLength(2));
      expect(values.first.amount, 30);
      expect(values.first.outstandingAmount, 0);
      expect(values.first.state, TuitionPaymentState.paid);
      expect(values.last.outstandingAmount, 69.7);
      expect(values.last.id, 'FT-TEST-2');
    },
  );

  test('student grades without subject codes retain distinct identities', () {
    final values = parser.parseGrades(
      '''<table><tr><td><table>
      <thead><tr><th>Unidade Curricular</th><td>ECTS</td><td>Nota</td><td>Data</td><td>TN</td><td>EE</td></tr></thead>
      <tbody><tr><td>Subject A</td><td>6</td><td>15</td><td>2026-07-01</td><td></td><td></td></tr>
      <tr><td>Subject B</td><td>5</td><td>14</td><td>2026-07-02</td><td></td><td></td></tr></tbody>
      </table></td></tr></table>''',
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
      forceHistorical: true,
    );
    expect(values, hasLength(2));
    expect(values.map((e) => e.externalId).toSet(), hasLength(2));
    expect(values.fold<double>(0, (sum, item) => sum + item.ects!), 11);
    expect(values.every((item) => item.academicYear == '2025/2026'), isTrue);
  });

  test('uses latest dated student-file curriculum and ignores unscoped rows', () {
    const table =
        '''<table><tr><th>Unidade Curricular</th><th>ECTS</th><th>Nota</th><th>Data</th><th>TN</th><th>EE</th></tr>
      <tr><td>Subject A</td><td>6</td><td>15</td><td>2025-07-01</td><td></td><td></td></tr></table>''';
    final values = parser.parseGrades(
      '''<div id="accordionStudentFile">
        <h3>Previous curriculum</h3><div>$table</div>
        <h3>Course plan 2025/2026</h3><div>
          <table><tr><th>Unidade Curricular</th><th>ECTS</th><th>Nota</th><th>Data</th><th>TN</th><th>EE</th></tr>
          <tr><td>Subject B</td><td>6</td><td>16</td><td>2026-07-01</td><td></td><td></td></tr></table>
        </div>
      </div>''',
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
      forceHistorical: true,
    );

    expect(values, hasLength(1));
    expect(values.single.subjectName, 'Subject B');
    expect(values.single.ects, 6);
  });

  test('parses bounded current grades from Portal detail objects', () {
    final values = parser.parseGrades(
      '''<table><tr><th>Sigla</th><td>Unidade Curricular</td><td>Avaliação Contínua</td></tr>
      <tr><td>SUBJ</td><td>Subject A</td><td><a href='javascript: detailsDialog({uc:"Subject A", pl:"2026/2027 (1º Semestre)", te:"Contínua", trs:[{nct:"Project", g:"16.5", d:"2026-10-01", d_ad:"2026-10-02"}], def:1});'>Details</a></td></tr></table>''',
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
    );

    expect(values, hasLength(1));
    expect(values.single.subjectCode, 'SUBJ');
    expect(values.single.subjectName, 'Subject A');
    expect(values.single.name, 'Project');
    expect(values.single.value, 16.5);
    expect(values.single.academicYear, '2026/2027');
  });

  test('imports only current enrollment from the returned year tabs', () {
    final values = parser.parseEnrollment(
      '''<ul><li><a href="#tabDisc41">2026/2027</a></li><li><a href="#tabDisc40">2025/2026</a></li></ul>
      <div id="tabDisc41"><table><tr><td><strong>1º Semestre</strong><br><a href="../educacao/ver_edicoes_disciplina.aspx?id=123">Subject A</a></td></tr></table></div>
      <div id="tabDisc40"><a href="../educacao/ver_edicoes_disciplina.aspx?id=456">Old subject</a></div>''',
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
    );
    expect(values, hasLength(1));
    expect(values.single.name, 'Subject A');
    expect(values.single.academicYear, '2026/2027');
  });

  test('rejects two-column service navigation even with exact headers', () {
    expect(
      () => parser.parseTuitionCharges(
        '<table><tr><td>Serviços</td><td>Valor</td></tr>'
        '<tr><td>Cacifos</td><td>20262027</td></tr></table>',
        sourceUrl: 'https://portal.isep.ipp.pt/intranet/payments',
      ),
      throwsA(isA<IntegrationException>()),
    );
  });

  test('keeps valid exam registration tables', () {
    const html = '''
      <table>
        <tr><th>ID</th><th>Sigla</th><th>Unidade Curricular</th><th>Época</th><th>Estado Inscrição</th></tr>
        <tr><td>exam-1</td><td>BDAD</td><td>Bases de Dados</td><td>Normal</td><td>Inscrito</td></tr>
      </table>
    ''';

    final values = parser.parseExamRegistrations(
      html,
      sourceUrl: 'https://portal.isep.ipp.pt/intranet/exams',
    );

    expect(values, hasLength(1));
    expect(values.single.subjectCode, 'BDAD');
    expect(values.single.state, ExamRegistrationState.registered);
  });

  test('parses live WebForms registration grid below its title row', () {
    const html = '''
      <table id="ContentPlaceHolderMain_gvExames">
        <tr><td colspan="7">Inscrições em exames — 2026/2027</td></tr>
        <tr><th>Cód. UC</th><th>Designação UC</th><th>Época de exame</th><th>Situação da inscrição</th><th>Data limite de inscrição</th><th>Data do exame</th><th>Emolumentos</th></tr>
        <tr><td>BDAD</td><td>Bases de Dados</td><td>Época de Recurso</td><td>Inscrição efetuada</td><td>10/02/2027</td><td>12/02/2027</td><td>3 EUR</td></tr>
      </table>
    ''';

    final value = parser
        .parseExamRegistrations(
          html,
          sourceUrl: 'https://portal.isep.ipp.pt/intranet/exams',
        )
        .single;

    expect(value.subjectCode, 'BDAD');
    expect(value.subjectName, 'Bases de Dados');
    expect(value.examType, 'Época de Recurso');
    expect(value.state, ExamRegistrationState.registered);
    expect(value.registrationClosesAt, DateTime(2027, 2, 10));
    expect(value.examAt, DateTime(2027, 2, 12));
    expect(value.fee, '3 EUR');
  });

  test('accepts explicit no-registration-period Portal message', () {
    final values = parser.parseExamRegistrations(
      '<div>Neste momento não existe nenhum período de inscrição em exames.</div>',
      sourceUrl: 'https://portal.isep.ipp.pt/intranet/exams',
    );

    expect(values, isEmpty);
  });

  test('rejects repeated exam-season navigation as a registration', () {
    const html = '''
      <table>
        <tr><th>UC</th><th>Época</th><th>Estado</th></tr>
        <tr><td>Época de Recurso Época Normal Fora de Época Época Especial de Setembro</td><td>Época de Recurso Época Normal</td><td></td></tr>
      </table>
    ''';

    expect(
      () => parser.parseExamRegistrations(
        html,
        sourceUrl: 'https://portal.isep.ipp.pt/intranet/exams',
      ),
      throwsA(isA<IntegrationException>()),
    );
  });

  test('parses absences against the complete planned class total', () {
    const html = '''
      <table>
        <tr><th>Sigla</th><th>Unidade Curricular</th><th>Faltas</th><th>Aulas previstas</th><th>Faltas justificadas</th></tr>
        <tr><td>BDAD</td><td>Bases de Dados</td><td>3</td><td>40</td><td>1</td></tr>
      </table>
    ''';

    final value = parser
        .parseAbsences(
          html,
          sourceUrl:
              'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
        )
        .single;

    expect(value.absences, 3);
    expect(value.totalPlannedClasses, 40);
    expect(value.percentage, 7.5);
    expect(value.excusedAbsences, 1);
  });

  test(
    'parses the live attendance service grammar without inventing totals',
    () {
      final values = parser.parseAttendanceData(
        {
          'PeriodosLetivos': [
            {
              'Name': 'First semester',
              'UCs': [
                {
                  'CDE': 85433,
                  'Name': 'Programming',
                  'FaltasEmHoras': false,
                  'TiposAula': [
                    {
                      'Sigla': 'TP',
                      'ResumoFaltas': {'Numero': 2, 'TotalPresencas': 8},
                    },
                    {
                      'Sigla': 'PL',
                      'ResumoFaltas': {'Numero': 1, 'TotalPresencas': 4},
                    },
                    {
                      'Sigla': 'T',
                      'ResumoFaltas': {'Numero': 4, 'TotalPresencas': 8},
                    },
                  ],
                },
              ],
            },
          ],
        },
        academicYear: '2026/2027',
        sourceUrl:
            'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
      );

      expect(values.single.subjectCode, '85433');
      expect(values.single.absences, 7);
      expect(values.single.tpPlAbsences, 3);
      expect(values.single.totalPlannedClasses, isNull);
      expect(values.single.percentage, isNull);
    },
  );

  test('parses school calendar periods and date ranges', () {
    const html = '''
      <table>
        <tr><th>Atividade</th><th>Início</th><th>Fim</th><th>Categoria</th></tr>
        <tr><td>Aulas do primeiro semestre</td><td>14/09/2026</td><td>19/12/2026</td><td>Período letivo</td></tr>
      </table>
    ''';

    final value = parser
        .parseSchoolCalendar(
          html,
          sourceUrl:
              'https://portal.isep.ipp.pt/intranet/educacao/ver_calendario_escolar.aspx',
        )
        .single;

    expect(value.title, 'Aulas do primeiro semestre');
    expect(value.start, DateTime(2026, 9, 14));
    expect(value.end, DateTime(2026, 12, 19));
    expect(value.category, 'Período letivo');
  });

  test('parses grouped rows from the live school-calendar grid', () {
    const html = '''
      <table>
        <tr><td>Atividade académica</td><td>Data Início</td><td>Data Fim</td></tr>
        <tr><td rowspan="2">Teaching period</td><td>14/09/2026</td><td>19/12/2026</td></tr>
        <tr><td>04/01/2027</td><td>23/01/2027</td></tr>
      </table>
    ''';

    final values = parser.parseSchoolCalendar(
      html,
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/educacao/ver_calendario_escolar.aspx',
    );

    expect(values, hasLength(2));
    expect(values.every((item) => item.title == 'Teaching period'), isTrue);
  });

  test('rejects WebForms layout and script text as exam registrations', () {
    const html = r'''
      <table id="portal-layout">
        <tr>
          <td><script>$("#UcSearch2_btnPesq").button({ icons: { primary: "ui-icon-search" } });</script>Cursos Departamentos Serviços Gestão Qualidade Legislação</td>
          <td>Ano Letivo: *</td>
        </tr>
        <tr><td>2025-2026 2024-2025</td><td>Calendário: *</td></tr>
        <tr><td>Curso: * $(function () { $("#tabs").tabs(); });</td><td>ação</td></tr>
      </table>
    ''';

    expect(
      () => parser.parseExamRegistrations(
        html,
        sourceUrl: 'https://portal.isep.ipp.pt/intranet/exams',
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

  test('keeps valid tuition tables and amounts', () {
    const html = '''
      <table>
        <tr><th>Descrição</th><th>Valor</th><th>Vencimento</th><th>Estado</th></tr>
        <tr><td>Propina</td><td>120,50 €</td><td>15/10/2026</td><td>Pendente</td></tr>
      </table>
    ''';

    final values = parser.parseTuitionCharges(
      html,
      sourceUrl: 'https://portal.isep.ipp.pt/intranet/payments',
    );

    expect(values, hasLength(1));
    expect(values.single.title, 'Propina');
    expect(values.single.amount, 120.5);
  });

  test('rejects Portal menu tables instead of inventing huge charges', () {
    const html = r'''
      <table id="menu-layout">
        <tr>
          <td><script>$.menuLink("MenuPAGAMENTOS", $("#menuPagamentos"), "PAGAMENTOS", "", "", "_self", "");</script>Serviços Gestão Qualidade Legislação</td>
          <td>Valor</td>
        </tr>
        <tr><td>ref • • • • ação</td><td>20 262 027,00 €</td></tr>
      </table>
    ''';

    expect(
      () => parser.parseTuitionCharges(
        html,
        sourceUrl: 'https://portal.isep.ipp.pt/intranet/payments',
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

  test('rejects the whole result when valid and noisy rows are mixed', () {
    const html =
        r'''\n      <table>\n        <tr><th>Descrição</th><th>Valor</th><th>Vencimento</th></tr>\n        <tr><td>Propina</td><td>120,50 €</td><td>15/10/2026</td></tr>\n        <tr><td>$(function () { MenuLink("PAGAMENTOS"); })</td><td>20 262 027,00 €</td><td></td></tr>\n      </table>\n    ''';

    expect(
      () => parser.parseTuitionCharges(
        html,
        sourceUrl: 'https://portal.isep.ipp.pt/intranet/payments',
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
}
