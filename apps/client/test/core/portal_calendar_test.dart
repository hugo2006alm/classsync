import 'package:classsync/core/integrations/portal/isep_portal_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'imports embedded special-season calendar without executing JavaScript',
    () {
      const html = '''<script>function getEventData() { return { events: [{
      'id':1,
      'start': new Date(2026,8,8,9,30),
      'end': new Date(2026,8,8,12,0),
      'title':'<table><tr><td><label title="Exame">Exame</label></td><td>TEST</td></tr></table>',
      'body':'<table><tr><td><label title="Época Especial de Setembro">Época Especial de Setembro</label></td></tr></table><a href="?room=1">B102</a><a href="?room=2">B104</a>',
      readOnly: true
    }] }; }</script>''';
      final slots = const IsepPortalParser().parseTimetable(
        html,
        sourceUrl:
            'https://portal.isep.ipp.pt/intranet/ver_horario/ver_horario.aspx?user=1',
      );
      expect(slots, hasLength(1));
      expect(slots.single.start, DateTime(2026, 9, 8, 9, 30));
      expect(slots.single.end, DateTime(2026, 9, 8, 12));
      expect(slots.single.subjectCode, 'TEST');
      expect(slots.single.room, 'B102 · B104');
      expect(slots.single.lessonType, contains('Especial'));
    },
  );
}
