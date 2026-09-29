import 'package:classsync/core/academic/academic_research_service.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/integrations/gemini/gemini_client.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClassSyncDatabase database;
  late AcademicResearchService service;

  setUp(() async {
    database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
    service = AcademicResearchService(
      database: database,
      credentials: SecureCredentialStore(),
      gemini: GeminiClient(),
    );
  });

  tearDown(() => database.close());

  test('search excludes cached Portal form noise and JSON metadata', () async {
    await database.upsertAcademicRecord(
      AcademicRecord(
        key: 'bad',
        source: AcademicSource.portal,
        kind: AcademicRecordKind.examRegistration,
        externalId: 'bad',
        title: 'Morada EXAMPLE DTO',
        payload: {'subjectName': 'Morada EXAMPLE DTO', 'state': 'unknown'},
        syncedAt: DateTime.utc(2026),
      ),
    );
    expect(await service.search('DTO'), isEmpty);
  });

  test('keyword search indexes local records and respects filters', () async {
    await database.upsertAcademicRecord(
      AcademicRecord(
        key: 'fuc:ia',
        source: AcademicSource.fuc,
        kind: AcademicRecordKind.fucProfile,
        externalId: 'ia',
        title: 'Artificial Intelligence',
        subjectId: 'subject-ia',
        startsAt: DateTime.utc(2026, 9, 7),
        payload: {
          'syllabus': ['A star search with admissible heuristics'],
          'sourceUrl': 'https://portal.isep.ipp.pt/fuc',
        },
        syncedAt: DateTime.utc(2026, 9, 7),
      ),
    );
    expect(await service.search('admissible heuristics'), hasLength(1));
    final hit = (await service.search('admissible')).single;
    expect(hit.excerpt, isNot(contains('sourceUrl')));
    expect(hit.excerpt, isNot(contains('{')));
    expect(await service.search('sourceUrl'), isEmpty);
    expect(
      await service.search('admissible', subjectId: 'another-subject'),
      isEmpty,
    );
    expect(
      await service.search('admissible', kinds: {AcademicRecordKind.grade}),
      isEmpty,
    );
  });

  test('grounded ask does not call Gemini without evidence', () async {
    final answer = await service.ask('What was the project deadline?');
    expect(answer.insufficientEvidence, isTrue);
    expect(answer.citationIds, isEmpty);
  });

  test('disabled ISEP sources stay out of academic search', () async {
    for (final source in [AcademicSource.portal, AcademicSource.manual]) {
      await database.upsertAcademicRecord(
        AcademicRecord(
          key: source.name,
          source: source,
          kind: AcademicRecordKind.evaluation,
          externalId: source.name,
          title: 'Unique deadline ${source.name}',
          payload: const {},
          syncedAt: DateTime.utc(2026),
        ),
      );
    }
    final settings = await database.readSettings();
    await database.saveSettings(
      settings.copyWith(academicIntegrationsEnabled: false),
    );
    final hits = await service.search('unique deadline');
    expect(hits.map((hit) => hit.id), ['manual']);
  });
}
