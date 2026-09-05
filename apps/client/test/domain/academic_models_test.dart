import 'package:classsync/domain/academic/academic_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives one active semester from active subjects', () {
    final subjects = [
      _subject('AI', 'In progress'),
      _subject('Graphics', 'In progress'),
      _subject('Old class', 'Done'),
    ];

    final semester = AcademicSemester.derive(subjects);

    expect(semester?.label, '3º Ano · 1º Semestre');
  });

  test('does not claim one semester when active subjects differ', () {
    final subjects = [
      _subject('AI', 'In progress'),
      AcademicSubject(
        notionId: 'other',
        name: 'Other',
        year: '2º Ano',
        semester: '2º Semestre',
        status: 'In progress',
        lastSyncedAt: DateTime.utc(2026),
      ),
    ];

    expect(AcademicSemester.derive(subjects), isNull);
  });
}

AcademicSubject _subject(String name, String status) => AcademicSubject(
  notionId: name,
  name: name,
  year: '3º Ano',
  semester: '1º Semestre',
  status: status,
  lastSyncedAt: DateTime.utc(2026),
);
