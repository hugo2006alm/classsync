import 'package:classsync/domain/academic/academic_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes abbreviated academic years for display', () {
    expect(_subject('one', year: '3º').semesterLabel, '3º Ano · 1º Semestre');
    expect(_subject('two', year: '3').semesterLabel, '3º Ano · 1º Semestre');
    expect(
      _subject('three', year: '3º Ano').semesterLabel,
      '3º Ano · 1º Semestre',
    );
  });

  test('derives one active semester from active subjects', () {
    final subjects = [
      _subject('AI', status: 'In progress'),
      _subject('Graphics', status: 'In progress'),
      _subject('Old class', status: 'Done'),
    ];

    final semester = AcademicSemester.derive(subjects);

    expect(semester?.label, '3º Ano · 1º Semestre');
  });

  test('does not claim one semester when active subjects differ', () {
    final subjects = [
      _subject('AI', status: 'In progress'),
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

AcademicSubject _subject(
  String name, {
  String status = 'In progress',
  String year = '3º Ano',
}) => AcademicSubject(
  notionId: name,
  name: name,
  year: year,
  semester: '1º Semestre',
  status: status,
  lastSyncedAt: DateTime.utc(2026),
);
