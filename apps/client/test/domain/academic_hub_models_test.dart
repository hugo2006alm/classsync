import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:classsync/domain/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('subject mapping', () {
    test(
      'maps deterministic alias and leaves ambiguous matches for review',
      () {
        final subjects = [
          _subject('db', 'Bases de Dados', aliases: const ['BDAD']),
          _subject('ai', 'Inteligência Artificial', aliases: const ['IA']),
        ];
        expect(
          SubjectMapper.match('BDAD', '', subjects).subject?.notionId,
          'db',
        );
        expect(
          SubjectMapper.match('', 'Bases de Dados', [
            ...subjects,
            _subject('db2', 'Bases de Dados'),
          ]).isAmbiguous,
          isTrue,
        );
      },
    );
  });

  group('timetable context', () {
    final start = DateTime(2026, 9, 14, 9);
    final slot = TimetableSlot(
      externalId: 'slot',
      subjectCode: 'BDAD',
      subjectName: 'Bases de Dados',
      subjectId: 'db',
      start: start,
      end: start.add(const Duration(minutes: 90)),
    );

    test('matches real overlap but not touching boundaries', () {
      expect(
        TimetableMatcher.match(
          meetingStart: start.add(const Duration(minutes: 20)),
          meetingEnd: start.add(const Duration(minutes: 80)),
          slots: [slot],
        ).subjectId,
        'db',
      );
      expect(
        TimetableMatcher.match(
          meetingStart: slot.end,
          meetingEnd: slot.end.add(const Duration(minutes: 20)),
          slots: [slot],
        ).slots,
        isEmpty,
      );
    });

    test('corroboration raises confidence and conflict requires review', () {
      final context = TimetableMatcher.match(
        meetingStart: start,
        meetingEnd: start.add(const Duration(minutes: 60)),
        slots: [slot],
      );
      final corroborated = TimetableMatcher.combine(
        _classification('db', 0.8),
        context,
        [_subject('db', 'Bases de Dados')],
      );
      expect(corroborated.decision, ClassificationDecision.match);
      expect(corroborated.confidence, closeTo(0.85, 0.0001));
      final conflict = TimetableMatcher.combine(
        _classification('ai', 0.98),
        context,
        [_subject('db', 'Bases de Dados'), _subject('ai', 'IA')],
      );
      expect(conflict.decision, ClassificationDecision.uncertain);
      expect(conflict.reasoningSummary.single, contains('conflicts'));
    });

    test('overlapping different subjects stays ambiguous', () {
      final result = TimetableMatcher.match(
        meetingStart: start,
        meetingEnd: start.add(const Duration(minutes: 30)),
        slots: [
          slot,
          TimetableSlot(
            externalId: 'other',
            subjectCode: 'IA',
            subjectName: 'IA',
            subjectId: 'ai',
            start: start,
            end: start.add(const Duration(hours: 1)),
          ),
        ],
      );
      expect(result.isAmbiguous, isTrue);
    });
  });

  test(
    'evaluation dedup retains provenance and never invents registration',
    () {
      final at = DateTime.utc(2027, 1, 18, 14, 30);
      final merged = EvaluationMerger.merge([
        EvaluationEvent(
          externalId: 'portal-1',
          title: 'Exam',
          type: 'Exam',
          subjectId: 'db',
          start: at,
          registrationState: ExamRegistrationState.unknown,
          provenance: const [
            AcademicProvenance(
              source: AcademicSource.portal,
              externalId: 'portal-1',
            ),
          ],
        ),
        EvaluationEvent(
          externalId: 'moodle-1',
          title: 'Exam notice',
          type: 'Exam',
          subjectId: 'db',
          start: at.add(const Duration(minutes: 5)),
          provenance: const [
            AcademicProvenance(
              source: AcademicSource.moodle,
              externalId: 'moodle-1',
            ),
          ],
        ),
      ]);
      expect(merged, hasLength(1));
      expect(merged.single.provenance, hasLength(2));
      expect(merged.single.registrationState, ExamRegistrationState.unknown);
    },
  );

  group('grade calculator', () {
    test('calculates remaining weighted grade at rounding boundary', () {
      final result = GradeCalculator.calculate(
        AssessmentFormula(
          id: 'continuous',
          label: 'Continuous',
          components: [
            _grade('Test 1', value: 12, weight: 0.4),
            _grade('Exam', weight: 0.6, minimum: 8),
          ],
        ),
        target: 14,
      );
      expect(result.currentAverage, closeTo(12, 0.00001));
      expect(result.requiredAverage, closeTo(15.333333, 0.00001));
      expect(result.possible, isTrue);
    });

    test('reports minimum blocker and impossible target', () {
      final blocked = GradeCalculator.calculate(
        AssessmentFormula(
          id: 'blocked',
          label: 'Blocked',
          components: [
            _grade('Lab', value: 7.99, weight: 0.5, minimum: 8),
            _grade('Exam', weight: 0.5),
          ],
        ),
        target: 9.5,
      );
      expect(blocked.possible, isFalse);
      expect(blocked.blockers, isNotEmpty);
      final impossible = GradeCalculator.calculate(
        AssessmentFormula(
          id: 'impossible',
          label: 'Impossible',
          components: [
            _grade('Test', value: 0, weight: 0.8),
            _grade('Exam', weight: 0.2),
          ],
        ),
        target: 9.5,
      );
      expect(impossible.requiredAverage, 47.5);
      expect(impossible.possible, isFalse);
    });

    test('alternative formulas exclude unconfirmed FUC inference', () {
      final best = GradeCalculator.bestAlternative([
        AssessmentFormula(
          id: 'inferred',
          label: 'Inferred',
          confirmed: false,
          source: GradeValueSource.fuc,
          components: [_grade('Exam', weight: 1)],
        ),
        AssessmentFormula(
          id: 'confirmed',
          label: 'Confirmed',
          components: [_grade('Exam', weight: 1)],
        ),
      ], target: 10);
      expect(best?.key.id, 'confirmed');
    });
  });
}

AcademicSubject _subject(
  String id,
  String name, {
  List<String> aliases = const [],
}) => AcademicSubject(
  notionId: id,
  name: name,
  year: '3',
  semester: '1',
  status: 'In progress',
  aliases: aliases,
  lastSyncedAt: DateTime.utc(2026),
);

ClassificationResult _classification(String id, double confidence) =>
    ClassificationResult(
      decision: ClassificationDecision.match,
      subjectId: id,
      subjectName: id,
      confidence: confidence,
      candidates: const [],
      reasoningSummary: const [],
    );

GradeComponent _grade(
  String name, {
  double? value,
  double? weight,
  double? minimum,
}) => GradeComponent(
  externalId: name,
  subjectName: 'Bases de Dados',
  name: name,
  value: value,
  weight: weight,
  minimum: minimum,
  source: GradeValueSource.manual,
);
