import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

Future<void> seedAcademicQa(ClassSyncDatabase database) async {
  final now = DateTime.utc(2026, 9, 9);
  final values = [
    (
      AcademicSource.portal,
      AcademicRecordKind.tuitionCharge,
      'bad-year',
      'Ano Letivo : 2026/2027',
      <String, dynamic>{
        'title': 'Ano Letivo : 2026/2027',
        'amount': 20262027.0,
        'state': 'unknown',
      },
    ),
    (
      AcademicSource.portal,
      AcademicRecordKind.examRegistration,
      'bad-form',
      'Data da Liquidação (aaaa-mm-dd)',
      <String, dynamic>{
        'subjectName': 'Data da Liquidação (aaaa-mm-dd)',
        'state': 'unknown',
      },
    ),
    (
      AcademicSource.portal,
      AcademicRecordKind.examRegistration,
      'bad-address',
      'Morada EXAMPLE DTO',
      <String, dynamic>{
        'subjectName': 'Morada EXAMPLE DTO',
        'state': 'unknown',
      },
    ),
    (
      AcademicSource.portal,
      AcademicRecordKind.tuitionCharge,
      'valid-fee',
      'Propina',
      const TuitionCharge(
        id: 'valid-fee',
        title: 'Propina',
        state: TuitionPaymentState.pending,
        amount: 120.5,
        sourceUrl: 'https://portal.isep.ipp.pt/finance',
      ).toJson(),
    ),
    (
      AcademicSource.fuc,
      AcademicRecordKind.fucProfile,
      'valid-content',
      'DTO course notes',
      <String, dynamic>{
        'syllabus': ['DTO means Data Transfer Object.'],
        'sourceUrl': 'https://portal.isep.ipp.pt/fuc',
      },
    ),
  ];
  for (final value in values) {
    await database.upsertAcademicRecord(
      AcademicRecord(
        key: value.$3,
        source: value.$1,
        kind: value.$2,
        externalId: value.$3,
        title: value.$4,
        payload: value.$5,
        syncedAt: now,
      ),
    );
  }
}

Future<void> verifyAcademicTabs(WidgetTester tester) async {
  Future<void> select(String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  await select('Finance');
  await tester.pumpAndSettle();
  expect(find.text('Propina'), findsOneWidget);
  expect(find.textContaining('120,50'), findsWidgets);
  expect(find.textContaining('Ano Letivo :'), findsNothing);
  expect(tester.takeException(), isNull);
  await select('Grades & progress');
  expect(find.text('No progress data cached'), findsOneWidget);
  expect(find.textContaining('Data da Liquidação'), findsNothing);
  expect(find.textContaining('Morada EXAMPLE'), findsNothing);
  await select('Search & ask');
  await tester.enterText(
    find.byWidgetPredicate((widget) => widget is EditableText),
    'DTO',
  );
  await tester.tap(find.text('Search locally'));
  await tester.pumpAndSettle();
  expect(find.text('DTO course notes'), findsOneWidget);
  expect(find.textContaining('Morada EXAMPLE'), findsNothing);
  expect(find.textContaining('sourceUrl'), findsNothing);
  expect(tester.takeException(), isNull);
}
