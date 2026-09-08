import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/portal/strict_isep_portal_parser.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = StrictIsepPortalParser();

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
