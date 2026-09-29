import 'dart:async';

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
    'disabled ISEP sources make no requests and cancel imported reminders',
    () async {
      final now = DateTime.now().toUtc();
      await database.upsertAcademicRecord(
        AcademicRecord(
          key: 'portal-exam',
          source: AcademicSource.portal,
          kind: AcademicRecordKind.evaluation,
          externalId: 'portal-exam',
          title: 'Portal exam',
          payload: const {},
          syncedAt: now,
        ),
      );
      await database.upsertAcademicRecord(
        AcademicRecord(
          key: 'local-task',
          source: AcademicSource.manual,
          kind: AcademicRecordKind.lectureTask,
          externalId: 'local-task',
          title: 'Local task',
          payload: const {},
          syncedAt: now,
        ),
      );
      final settings = await database.readSettings();
      await database.saveSettings(
        settings.copyWith(academicIntegrationsEnabled: false),
      );
      final result = await service.synchronize();
      expect(result.configured, isFalse);
      expect(portal.authenticationCount, 0);
      expect(moodle.synchronizationCount, 0);
      expect(notifications.cancelled, contains('portal-exam'));
      expect(notifications.cancelled, isNot(contains('local-task')));
      expect(await database.readAcademicRecord('portal-exam'), isNotNull);
    },
  );

  test(
    'cache repair preserves valid and user data and retries reminder cancellation',
    () async {
      final now = DateTime.now().toUtc();
      await database.saveCursor('academic_success_finance', now);
      await database.saveCursor('academic_attempt_finance', now);
      final bad = AcademicRecord(
        key: 'bad',
        source: AcademicSource.portal,
        kind: AcademicRecordKind.tuitionCharge,
        externalId: 'bad',
        title: 'Ano Letivo : 2026/2027',
        payload: {'title': 'Ano Letivo : 2026/2027', 'amount': 20262027.0},
        syncedAt: now,
      );
      await database.upsertAcademicRecord(bad);
      await database.upsertAcademicRecord(
        bad.copyWith(payload: {...bad.payload, 'reminderMinutesBefore': 60}),
      );
      for (final record in [
        AcademicRecord(
          key: 'valid',
          source: AcademicSource.portal,
          kind: AcademicRecordKind.tuitionCharge,
          externalId: 'valid',
          title: 'Propina',
          payload: const TuitionCharge(
            id: 'valid',
            title: 'Propina',
            state: TuitionPaymentState.paid,
            amount: 69.7,
            sourceUrl: 'https://portal.isep.ipp.pt/finance',
          ).toJson(),
          syncedAt: now,
        ),
        AcademicRecord(
          key: 'manual',
          source: AcademicSource.manual,
          kind: AcademicRecordKind.lectureTask,
          externalId: 'manual',
          title: 'Morada EXAMPLE DTO',
          payload: {'status': 'completed'},
          syncedAt: now,
        ),
        AcademicRecord(
          key: 'notice',
          source: AcademicSource.portal,
          kind: AcademicRecordKind.portalNotification,
          externalId: 'notice',
          title: 'Important notice ' * 30,
          payload: {'read': true},
          syncedAt: now,
        ),
      ]) {
        await database.upsertAcademicRecord(record);
      }
      notifications.failCancel = true;
      await service.repairPortalCache();
      expect(await database.readAcademicRecord('bad'), isNotNull);
      notifications.failCancel = false;
      await service.repairPortalCache();
      await service.repairPortalCache();
      expect(
        (await database.readAcademicRecords())
            .map((record) => record.key)
            .toSet(),
        {'valid', 'manual', 'notice'},
      );
      expect(
        (await database.readAcademicRecord('manual'))!.payload['status'],
        'completed',
      );
      expect((await database.watchAcademicChanges().first), isEmpty);
      expect(await database.readCursor('academic_success_finance'), isNull);
      expect(await database.readCursor('academic_attempt_finance'), isNull);
      expect(notifications.cancelled, ['bad']);
    },
  );

  test('task state changes are timestamped and sync immediately', () async {
    var syncCalls = 0;
    service = AcademicSyncService(
      database: database,
      credentials: credentials,
      portal: portal,
      moodle: moodle,
      notifications: notifications,
      synchronizeTasks: () async => syncCalls += 1,
    );
    final task = LectureTask(
      id: 'task-sync',
      title: 'Sync me',
      description: '',
      sourceLectureId: 'lecture-sync',
      sourceLectureTitle: 'Lecture',
      confidence: LectureActionConfidence.certain,
      supportingSegment: '',
      status: LectureTaskStatus.pending,
    );
    final record = AcademicRecord(
      key: AcademicRecord.keyFor(
        AcademicSource.manual,
        AcademicRecordKind.lectureTask,
        task.id,
      ),
      source: AcademicSource.manual,
      kind: AcademicRecordKind.lectureTask,
      externalId: task.id,
      title: task.title,
      payload: task.toJson(),
      syncedAt: DateTime.utc(2026, 9, 21),
    );
    await database.upsertAcademicRecord(record);

    await service.updateLectureTask(
      record,
      status: LectureTaskStatus.dismissed,
    );

    final saved = await database.readAcademicRecord(record.key);
    expect(saved!.payload['status'], 'dismissed');
    expect(
      DateTime.tryParse(saved.payload['statusUpdatedAt'] as String),
      isNotNull,
    );
    expect(syncCalls, 1);
  });

  test(
    'cleans screenshot-shaped cached noise even after v1 cleanup and offline',
    () async {
      credentials = _MemoryCredentials({});
      service = AcademicSyncService(
        database: database,
        credentials: credentials,
        portal: portal,
        moodle: moodle,
        notifications: notifications,
      );
      await database.saveCursor(
        'academic_markup_cleanup_v1',
        DateTime.now().toUtc(),
      );
      for (final entry in {
        'year': (AcademicRecordKind.tuitionCharge, 'Ano Letivo : 2026/2027'),
        'address': (AcademicRecordKind.examRegistration, 'Morada EXAMPLE DTO'),
        'form': (
          AcademicRecordKind.examRegistration,
          'Data da Liquidação (aaaa-mm-dd)',
        ),
      }.entries) {
        await database.upsertAcademicRecord(
          AcademicRecord(
            key: entry.key,
            source: AcademicSource.portal,
            kind: entry.value.$1,
            externalId: entry.key,
            title: entry.value.$2,
            payload: {
              'title': entry.value.$2,
              'state': 'unknown',
              'subjectName': entry.value.$2,
              if (entry.key == 'year') 'amount': 20262027.0,
            },
            syncedAt: DateTime.utc(2026),
          ),
        );
      }
      await service.synchronize();
      expect(await database.readAcademicRecords(), isEmpty);
      expect(notifications.cancelled, containsAll(['year', 'address', 'form']));
    },
  );

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
      expect(
        notifications.scheduled,
        containsAll(['${charge.key}:due', '${charge.key}:daily']),
      );
      expect(notifications.daily, contains('${charge.key}:daily'));
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
      expect(
        notifications.cancelled,
        containsAll([charge.key, '${charge.key}:due', '${charge.key}:daily']),
      );

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

      await service.connectMoodle(
        username: 'new-student',
        password: 'moodle-secret',
      );
      expect(credentials.values[CredentialKey.moodleToken], 'new-token');
      expect(moodle.testedToken, 'new-token');
      expect(moodle.authenticatedUsername, 'new-student');
      expect(moodle.authenticatedPassword, 'moodle-secret');

      await service.connectMoodle(username: 'new-student', password: '');
      expect(moodle.authenticatedPassword, 'new-secret');
    },
  );

  test(
    'automatic refresh reuses fresh stages and follows section priority',
    () async {
      await service.synchronize(force: false);
      expect(portal.authenticationCount, 1);
      expect(moodle.synchronizationCount, 1);

      await service.synchronize(force: false);
      expect(portal.authenticationCount, 1);
      expect(moodle.synchronizationCount, 1);
      expect(academicStagePriority(5).first, 'finance');
      expect(academicStagePriority(1).first, 'moodle');
      expect(academicRefreshAge('timetable'), const Duration(minutes: 30));
      expect(academicRefreshAge('grades'), const Duration(hours: 6));
    },
  );

  test('section refresh requests only its owning stages', () async {
    await service.synchronize(
      onlyStages: academicStagesForSection(0),
      timetableFrom: DateTime(2026, 10, 7),
    );

    expect(portal.authenticationCount, 1);
    expect(portal.requests, ['timetable']);
    expect(portal.timetableFrom, DateTime(2026, 10, 5));
    expect(portal.timetableWeeks, 5);
    expect(moodle.synchronizationCount, 0);
    expect(academicStagesForSection(1), isEmpty);
    expect(academicStagesForSection(4), {
      'grades',
      'history',
      'enrollment',
      'formulas',
    });
    expect(academicStagesForSection(5), {'finance'});
  });

  test('manual section reload runs after an in-flight refresh', () async {
    portal.timetableGate = Completer<void>();
    final timetable = service.synchronize(
      onlyStages: academicStagesForSection(0),
    );
    await portal.timetableStarted.future;

    final grades = service.synchronize(onlyStages: academicStagesForSection(4));
    portal.timetableGate!.complete();
    await timetable;
    await grades;

    expect(portal.authenticationCount, 2);
    final records = await database.readAcademicRecords();
    expect(
      records.where((record) => record.kind == AcademicRecordKind.grade),
      isNotEmpty,
    );
    expect(
      records.where(
        (record) => record.kind == AcademicRecordKind.academicHistory,
      ),
      isNotEmpty,
    );
  });
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
  int authenticationCount = 0;
  String? lastUsername;
  String? lastPassword;
  final requests = <String>[];
  final timetableStarted = Completer<void>();
  Completer<void>? timetableGate;
  DateTime? timetableFrom;
  int? timetableWeeks;
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
    authenticationCount++;
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
  Future<List<TimetableSlot>> getTimetable({
    DateTime? from,
    int weeks = 1,
  }) async {
    requests.add('timetable');
    timetableFrom = from;
    timetableWeeks = weeks;
    if (!timetableStarted.isCompleted) timetableStarted.complete();
    await timetableGate?.future;
    return [
      TimetableSlot(
        externalId: 'slot-1',
        subjectCode: 'BDAD',
        subjectName: 'Bases de Dados',
        start: DateTime.now().add(const Duration(days: 1)),
        end: DateTime.now().add(const Duration(days: 1, hours: 1)),
      ),
    ];
  }

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

  @override
  Future<List<AbsenceSummary>> getAbsences() async => const [
    AbsenceSummary(
      id: 'bdad:2026',
      subjectName: 'Bases de Dados',
      subjectCode: 'BDAD',
      absences: 2,
      totalPlannedClasses: 30,
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/areapessoal/estudante.aspx',
    ),
  ];

  @override
  Future<List<SchoolCalendarEntry>> getSchoolCalendar() async => [
    SchoolCalendarEntry(
      id: 'semester-1',
      title: 'First semester classes',
      start: DateTime(2026, 9, 14),
      end: DateTime(2026, 12, 19),
      sourceUrl:
          'https://portal.isep.ipp.pt/intranet/educacao/ver_calendario_escolar.aspx',
    ),
  ];
}

class _FakeMoodle extends MoodleClient {
  bool incremental = false;
  int synchronizationCount = 0;
  DateTime? lastSince;
  String? testedToken;
  String? authenticatedUsername;
  String? authenticatedPassword;

  @override
  Future<String> authenticate({
    required String username,
    required String password,
  }) async {
    authenticatedUsername = username;
    authenticatedPassword = password;
    return 'new-token';
  }

  @override
  Future<String> testConnection(String token) async {
    testedToken = token;
    return 'Moodle ISEP';
  }

  @override
  Future<MoodleSyncBundle> synchronize(
    String token, {
    DateTime? since,
    Future<void> Function(List<MoodleCourse>)? onCourses,
  }) async {
    synchronizationCount++;
    lastSince = since;
    const courses = [
      MoodleCourse(
        externalId: 'course-1',
        name: 'Bases de Dados',
        shortName: 'BDAD',
        url: 'https://moodle.isep.ipp.pt/course/view.php?id=1',
      ),
    ];
    await onCourses?.call(courses);
    return MoodleSyncBundle(
      courses: courses,
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
  bool failCancel = false;
  final scheduled = <String>[];
  final daily = <String>[];
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
    bool repeatDaily = false,
  }) async {
    scheduled.add(id);
    if (repeatDaily) daily.add(id);
  }

  @override
  Future<void> cancelAcademicReminder(String id) async {
    if (failCancel) throw StateError('Notification service unavailable');
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
