import 'package:classsync/core/academic/academic_sync_service.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/integrations/moodle/moodle_client.dart';
import 'package:classsync/core/integrations/portal/isep_portal_client.dart';
import 'package:classsync/core/notifications/classsync_notification_service.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClassSyncDatabase database;
  late _MemoryCredentials credentials;
  late _FakePortal portal;
  late _FakeMoodle moodle;
  late _FakeNotifications notifications;
  late AcademicSyncService service;

  setUp(() async {
    database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
    await database.replaceSubjects([_subjectOne, _subjectTwo]);
    credentials = _MemoryCredentials({
      CredentialKey.portalUsername: 'student',
      CredentialKey.portalPassword: 'secret',
      CredentialKey.moodleToken: 'token',
    });
    portal = _FakePortal();
    moodle = _FakeMoodle();
    notifications = _FakeNotifications();
    service = AcademicSyncService(
      database: database,
      credentials: credentials,
      portal: portal,
      moodle: moodle,
      notifications: notifications,
    );
  });

  tearDown(() => database.close());

  test(
    'syncs, joins, maps, and incrementally merges academic sources',
    () async {
      final first = await service.synchronize();
      expect(first.errors, isEmpty);
      expect(first.sources, {AcademicSource.portal, AcademicSource.moodle});
      expect(portal.authenticated, isTrue);

      final evaluations = await database.readAcademicRecords(
        kind: AcademicRecordKind.evaluation,
      );
      final exam = evaluations.singleWhere(
        (item) => item.externalId == 'exam-1',
      );
      expect(
        EvaluationEvent.fromJson(exam.payload).registrationState,
        ExamRegistrationState.registered,
      );
      expect(
        evaluations
            .singleWhere((item) => item.externalId == 'assignment-1')
            .subjectId,
        _subjectOne.notionId,
      );
      final charge = (await database.readAcademicRecords(
        kind: AcademicRecordKind.tuitionCharge,
      )).single;
      expect(charge.payload['paymentReferenceAvailable'], isTrue);
      expect(charge.payload.values.join(' '), isNot(contains('123456789')));
      await service.setTuitionReminder(charge, 1440, overdueReminder: true);
      expect(notifications.scheduled, contains(charge.key));
      portal.tuitionCharges = [
        const TuitionCharge(
          id: 'fee-1',
          title: 'Tuition fee',
          state: TuitionPaymentState.paid,
          sourceUrl: 'https://portal.isep.ipp.pt/payments',
          installment: 'Installment 1',
          amount: 120.5,
          outstandingAmount: 0,
        ),
      ];
      await service.synchronize();
      expect(notifications.cancelled, contains(charge.key));

      final formulaRecord = (await database.readAcademicRecords(
        kind: AcademicRecordKind.gradeFormula,
      )).single;
      expect(
        AssessmentFormula.fromJson(formulaRecord.payload).confirmed,
        isFalse,
      );
      await service.confirmFormula(formulaRecord);
      expect(
        AssessmentFormula.fromJson(
          (await database.readAcademicRecord(formulaRecord.key))!.payload,
        ).confirmed,
        isTrue,
      );

      final course = (await database.readAcademicRecords(
        kind: AcademicRecordKind.moodleCourse,
      )).single;
      await service.setMoodleCourseSubject(course, _subjectTwo);
      expect(
        (await database.readAcademicRecord(course.key))!.subjectId,
        _subjectTwo.notionId,
      );
      expect(
        (await database.readAcademicRecords(
          source: AcademicSource.moodle,
          kind: AcademicRecordKind.evaluation,
        )).every((item) => item.subjectId == _subjectTwo.notionId),
        isTrue,
      );

      await service.setEvaluationTypeReminder('Exam', 60);
      expect(notifications.scheduled, contains(exam.key));
      await service.setEvaluationReminder(
        (await database.readAcademicRecord(exam.key))!,
        null,
      );
      expect(notifications.cancelled, contains(exam.key));

      await service.addManualEvaluation(
        EvaluationEvent(
          externalId: 'manual-event',
          title: 'Presentation',
          type: 'Presentation',
          subjectId: _subjectOne.notionId,
          start: DateTime.now().add(const Duration(days: 10)),
          provenance: const [
            AcademicProvenance(
              source: AcademicSource.manual,
              externalId: 'manual-event',
            ),
          ],
        ),
      );
      await service.addManualGrade(
        const GradeComponent(
          externalId: 'manual-grade',
          subjectName: 'Bases de Dados',
          subjectId: 'subject-1',
          name: 'Project',
          value: 16,
          weight: 0.6,
          source: GradeValueSource.manual,
        ),
      );

      moodle.incremental = true;
      await service.synchronize();
      expect(moodle.lastSince, isNotNull);
      final moodleEvents = await database.readAcademicRecords(
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.evaluation,
      );
      expect(
        moodleEvents.map((item) => item.externalId),
        containsAll(['assignment-1', 'assignment-2']),
      );
    },
  );

  test(
    'connection actions validate before replacing secure credentials',
    () async {
      await service.connectPortal(
        username: 'new-student',
        password: 'new-secret',
      );
      expect(credentials.values[CredentialKey.portalUsername], 'new-student');
      expect(credentials.values[CredentialKey.portalPassword], 'new-secret');
      expect(await service.readPortalUsername(), 'new-student');

      await service.connectPortal(
        username: '1234567@isep.ipp.pt',
        password: 'new-secret',
      );
      expect(
        credentials.values[CredentialKey.portalUsername],
        '1234567@isep.ipp.pt',
      );
      expect(portal.lastUsername, '1234567@isep.ipp.pt');

      await service.connectPortal(username: '1234567@isep.ipp.pt');
      expect(credentials.values[CredentialKey.portalPassword], 'new-secret');
      expect(portal.lastPassword, 'new-secret');

      await service.connectMoodle('new-token');
      expect(credentials.values[CredentialKey.moodleToken], 'new-token');
      expect(moodle.testedToken, 'new-token');
    },
  );
}

final _subjectOne = AcademicSubject(
  notionId: 'subject-1',
  name: 'Bases de Dados',
  year: '3º',
  semester: '1º Semestre',
  status: 'In progress',
  aliases: const ['BDAD'],
  lastSyncedAt: DateTime.utc(2026, 9, 1),
);

final _subjectTwo = AcademicSubject(
  notionId: 'subject-2',
  name: 'Sistemas Operativos',
  year: '3º',
  semester: '1º Semestre',
  status: 'In progress',
  aliases: const ['SO'],
  lastSyncedAt: DateTime.utc(2026, 9, 1),
);

class _MemoryCredentials extends SecureCredentialStore {
  _MemoryCredentials(this.values);

  final Map<CredentialKey, String> values;

  @override
  Future<String?> read(CredentialKey key) async => values[key];

  @override
  Future<void> write(CredentialKey key, String value) async {
    values[key] = value.trim();
  }
}

class _FakePortal implements PortalAdapter {
  bool authenticated = false;
  String? lastUsername;
  String? lastPassword;
  List<TuitionCharge> tuitionCharges = [
    TuitionCharge(
      id: 'fee-1',
      title: 'Tuition fee',
      state: TuitionPaymentState.pending,
      sourceUrl: 'https://portal.isep.ipp.pt/payments',
      installment: 'Installment 1',
      amount: 120.5,
      outstandingAmount: 120.5,
      dueAt: DateTime.now().add(const Duration(days: 8)),
      paymentReferenceAvailable: true,
      paymentReferenceHint: '•••• 6789',
    ),
  ];

  @override
  Future<PortalProfile> authenticate(PortalCredentials credentials) async {
    authenticated = true;
    lastUsername = credentials.username;
    lastPassword = credentials.password;
    return const PortalProfile(displayName: 'Student');
  }

  @override
  Future<bool> validateSession() async => authenticated;

  @override
  Future<List<EnrollmentSubject>> getEnrollment() async => const [
    EnrollmentSubject(
      externalId: 'enrollment-1',
      code: 'BDAD',
      name: 'Bases de Dados',
      academicYear: '2026/2027',
      semester: '1',
    ),
  ];

  @override
  Future<List<TimetableSlot>> getTimetable() async => [
    TimetableSlot(
      externalId: 'slot-1',
      subjectCode: 'BDAD',
      subjectName: 'Bases de Dados',
      start: DateTime.now().add(const Duration(days: 1)),
      end: DateTime.now().add(const Duration(days: 1, hours: 1)),
    ),
  ];

  @override
  Future<List<EvaluationEvent>> getExams() async => [
    EvaluationEvent(
      externalId: 'exam-1',
      title: 'Exam · Bases de Dados',
      type: 'Exam',
      subjectCode: 'BDAD',
      subjectName: 'Bases de Dados',
      start: DateTime.now().add(const Duration(days: 5)),
      provenance: const [
        AcademicProvenance(source: AcademicSource.portal, externalId: 'exam-1'),
      ],
    ),
  ];

  @override
  Future<List<ExamRegistration>> getExamRegistrations() async => const [
    ExamRegistration(
      externalId: 'exam-1',
      subjectCode: 'BDAD',
      subjectName: 'Bases de Dados',
      examType: 'Exam',
      state: ExamRegistrationState.registered,
      sourceUrl: 'https://portal.isep.ipp.pt/registration',
    ),
  ];

  @override
  Future<List<GradeComponent>> getGrades() async => const [
    GradeComponent(
      externalId: 'grade-1',
      subjectCode: 'BDAD',
      subjectName: 'Bases de Dados',
      name: 'Test',
      value: 14,
      weight: 0.4,
      source: GradeValueSource.officialPortal,
    ),
  ];

  @override
  Future<List<GradeComponent>> getAcademicHistory() async => const [
    GradeComponent(
      externalId: 'history-1',
      subjectCode: 'BDAD',
      subjectName: 'Bases de Dados',
      name: 'Final',
      value: 15,
      isFinal: true,
      isHistorical: true,
      ects: 6,
      source: GradeValueSource.officialPortal,
    ),
  ];

  @override
  Future<List<AssessmentFormula>> getFucFormulas() async => const [
    AssessmentFormula(
      id: 'bdad:continuous',
      label: 'Continuous',
      subjectCode: 'BDAD',
      subjectName: 'Bases de Dados',
      confirmed: false,
      source: GradeValueSource.fuc,
      components: [
        GradeComponent(
          externalId: 'formula-test',
          subjectName: 'Bases de Dados',
          name: 'Test',
          weight: 0.4,
          source: GradeValueSource.fuc,
          confirmed: false,
        ),
        GradeComponent(
          externalId: 'formula-project',
          subjectName: 'Bases de Dados',
          name: 'Project',
          weight: 0.6,
          source: GradeValueSource.fuc,
          confirmed: false,
        ),
      ],
    ),
  ];

  @override
  Future<List<FucProfile>> getFucProfiles() async => const [];

  @override
  Future<List<PortalNotification>> getNotifications() async => const [];

  @override
  Future<List<OfficialLessonSummary>> getLessonSummaries() async => const [];

  @override
  Future<List<TuitionCharge>> getTuitionCharges() async => tuitionCharges;
}

class _FakeMoodle extends MoodleClient {
  bool incremental = false;
  DateTime? lastSince;
  String? testedToken;

  @override
  Future<String> testConnection(String token) async {
    testedToken = token;
    return 'Moodle ISEP';
  }

  @override
  Future<MoodleSyncBundle> synchronize(String token, {DateTime? since}) async {
    lastSince = since;
    return MoodleSyncBundle(
      courses: const [
        MoodleCourse(
          externalId: 'course-1',
          name: 'Bases de Dados',
          shortName: 'BDAD',
          url: 'https://moodle.isep.ipp.pt/course/view.php?id=1',
        ),
      ],
      assignments: [
        MoodleAssignment(
          externalId: incremental ? 'assignment-2' : 'assignment-1',
          courseId: 'course-1',
          name: incremental ? 'Second project' : 'First project',
          dueAt: DateTime.now().add(const Duration(days: 7)),
          url: 'https://moodle.isep.ipp.pt/mod/assign/view.php?id=1',
        ),
      ],
      announcements: [
        MoodleAnnouncement(
          externalId: incremental ? 'news-2' : 'news-1',
          courseId: 'course-1',
          title: 'News',
          createdAt: DateTime.now(),
          url: 'https://moodle.isep.ipp.pt/mod/forum/discuss.php?d=1',
        ),
      ],
    );
  }
}

class _FakeNotifications extends ClassSyncNotificationService {
  final scheduled = <String>[];
  final cancelled = <String>[];
  final shown = <String>[];

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleAcademicReminder({
    required String id,
    required String title,
    required DateTime scheduledAt,
    int section = 2,
  }) async {
    scheduled.add(id);
  }

  @override
  Future<void> cancelAcademicReminder(String id) async {
    cancelled.add(id);
  }

  @override
  Future<void> showAcademicUpdate({
    required String id,
    required String title,
    required String body,
    int section = 4,
  }) async {
    shown.add(id);
  }
}
