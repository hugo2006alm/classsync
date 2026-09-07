import '../../domain/academic/academic_hub_models.dart';
import '../../domain/academic/academic_hub_actions.dart';
import '../../domain/academic/academic_models.dart';
import '../database/classsync_database.dart';
import '../integrations/integration_exception.dart';
import '../integrations/moodle/moodle_client.dart';
import '../integrations/portal/isep_portal_client.dart';
import '../notifications/classsync_notification_service.dart';
import '../security/secure_credential_store.dart';
import '../security/trusted_url_launcher.dart';

class AcademicSyncResult {
  const AcademicSyncResult({
    required this.saved,
    required this.sources,
    required this.errors,
  });

  final int saved;
  final Set<AcademicSource> sources;
  final List<String> errors;
  bool get configured => sources.isNotEmpty;
}

class AcademicSyncService implements AcademicHubActions {
  AcademicSyncService({
    required ClassSyncDatabase database,
    required SecureCredentialStore credentials,
    required PortalAdapter portal,
    required MoodleClient moodle,
    required ClassSyncNotificationService notifications,
  }) : _database = database,
       _credentials = credentials,
       _portal = portal,
       _moodle = moodle,
       _notifications = notifications;

  final ClassSyncDatabase _database;
  final SecureCredentialStore _credentials;
  final PortalAdapter _portal;
  final MoodleClient _moodle;
  final ClassSyncNotificationService _notifications;

  @override
  Future<String> readPortalUsername() async =>
      await _credentials.read(CredentialKey.portalUsername) ?? '';

  @override
  Future<void> connectPortal({
    required String username,
    String? password,
  }) async {
    final enteredUsername = username.trim();
    final cleanUsername = enteredUsername.toLowerCase().endsWith('@isep.ipp.pt')
        ? enteredUsername.substring(0, enteredUsername.lastIndexOf('@'))
        : enteredUsername;
    final secret = password?.isNotEmpty == true
        ? password!
        : await _credentials.read(CredentialKey.portalPassword);
    if (cleanUsername.isEmpty || secret == null || secret.isEmpty) {
      throw const AcademicActionFailure(
        'Enter a Portal username and password.',
      );
    }
    try {
      await _portal.authenticate(
        PortalCredentials(username: cleanUsername, password: secret),
      );
    } on IntegrationException catch (error) {
      throw AcademicActionFailure(error.userMessage);
    }
    await _credentials.write(CredentialKey.portalUsername, cleanUsername);
    await _credentials.write(CredentialKey.portalPassword, secret);
  }

  @override
  Future<void> connectMoodle(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw const AcademicActionFailure('Enter a Moodle Web Services token.');
    }
    try {
      await _moodle.testConnection(cleanToken);
    } on IntegrationException catch (error) {
      throw AcademicActionFailure(error.userMessage);
    }
    await _credentials.write(CredentialKey.moodleToken, cleanToken);
  }

  @override
  Future<void> openSource(String url) async {
    final opened = await launchTrustedUrl(
      url,
      allowedHosts: const {'portal.isep.ipp.pt', 'moodle.isep.ipp.pt'},
    );
    if (!opened) {
      throw const AcademicActionFailure(
        'This academic source link is not trusted.',
      );
    }
  }

  Future<AcademicSyncResult> synchronize() async {
    final errors = <String>[];
    final sources = <AcademicSource>{};
    var saved = 0;
    final subjects = await _database.readActiveSubjects();
    final portalUser = await _credentials.read(CredentialKey.portalUsername);
    final portalPassword = await _credentials.read(
      CredentialKey.portalPassword,
    );
    if (portalUser != null && portalPassword != null) {
      sources.add(AcademicSource.portal);
      try {
        await _portal.authenticate(
          PortalCredentials(username: portalUser, password: portalPassword),
        );
        saved += await _syncPortal(subjects, errors);
      } on IntegrationException catch (error) {
        errors.add(error.userMessage);
      }
    }

    final moodleToken = await _credentials.read(CredentialKey.moodleToken);
    if (moodleToken != null) {
      sources.add(AcademicSource.moodle);
      try {
        saved += await _syncMoodle(moodleToken, subjects);
      } on IntegrationException catch (error) {
        errors.add(error.userMessage);
      }
    }
    return AcademicSyncResult(saved: saved, sources: sources, errors: errors);
  }

  Future<int> _syncPortal(
    List<AcademicSubject> subjects,
    List<String> errors,
  ) async {
    var saved = 0;
    List<EnrollmentSubject>? enrollment;
    try {
      enrollment = (await _portal.getEnrollment())
          .map(
            (item) => item.copyWith(
              subjectId: _mapSubject(item.code, item.name, subjects),
            ),
          )
          .toList();
      final records = enrollment.map(_enrollmentRecord).toList();
      await _database.replaceAcademicRecords(
        source: AcademicSource.portal,
        kind: AcademicRecordKind.enrollment,
        records: records,
      );
      saved += records.length;
    } on IntegrationException catch (error) {
      errors.add(error.userMessage);
    }

    try {
      final slots = (await _portal.getTimetable())
          .map(
            (item) => item.copyWith(
              subjectId: _mapSubject(
                item.subjectCode,
                item.subjectName,
                subjects,
              ),
            ),
          )
          .toList();
      final records = slots.map(_timetableRecord).toList();
      await _database.replaceAcademicRecords(
        source: AcademicSource.portal,
        kind: AcademicRecordKind.timetable,
        records: records,
      );
      saved += records.length;
    } on IntegrationException catch (error) {
      errors.add(error.userMessage);
    }

    final evaluations = <EvaluationEvent>[];
    final registrations = <ExamRegistration>[];
    try {
      evaluations.addAll(await _portal.getExams());
    } on IntegrationException catch (error) {
      errors.add(error.userMessage);
    }
    try {
      registrations.addAll(await _portal.getExamRegistrations());
    } on IntegrationException catch (error) {
      if (evaluations.isEmpty) errors.add(error.userMessage);
    }
    if (evaluations.isNotEmpty) {
      final mapped = evaluations.map((item) {
        final registration = _matchingRegistration(item, registrations);
        return item.copyWith(
          subjectId: _mapSubject(
            item.subjectCode ?? '',
            item.subjectName ?? '',
            subjects,
          ),
          registrationState: registration?.state,
        );
      }).toList();
      final records = mapped
          .map((item) => _evaluationRecord(item, AcademicSource.portal))
          .toList();
      await _replaceEvaluations(AcademicSource.portal, records);
      saved += records.length;
    }

    final grades = <GradeComponent>[];
    try {
      grades.addAll(await _portal.getGrades());
    } on IntegrationException catch (error) {
      errors.add(error.userMessage);
    }
    try {
      grades.addAll(await _portal.getAcademicHistory());
    } on IntegrationException catch (error) {
      if (grades.isEmpty) errors.add(error.userMessage);
    }
    if (grades.isNotEmpty) {
      final records = grades.map((item) {
        final subjectId = _mapSubject(
          item.subjectCode ?? '',
          item.subjectName,
          subjects,
        );
        final payload = {...item.toJson(), 'subjectId': subjectId};
        return AcademicRecord(
          key: AcademicRecord.keyFor(
            AcademicSource.portal,
            AcademicRecordKind.grade,
            item.externalId,
          ),
          source: AcademicSource.portal,
          kind: AcademicRecordKind.grade,
          externalId: item.externalId,
          title: '${item.subjectName} · ${item.name}',
          subjectId: subjectId,
          payload: payload,
          syncedAt: DateTime.now().toUtc(),
        );
      }).toList();
      await _database.replaceAcademicRecords(
        source: AcademicSource.portal,
        kind: AcademicRecordKind.grade,
        records: records,
      );
      saved += records.length;
    }

    try {
      final previous = await _database.readAcademicRecords(
        source: AcademicSource.fuc,
        kind: AcademicRecordKind.gradeFormula,
      );
      final previousById = {
        for (final record in previous)
          record.externalId: AssessmentFormula.fromJson(record.payload),
      };
      final formulas = (await _portal.getFucFormulas()).map((formula) {
        final mapped = formula.copyWith(
          subjectId: _mapSubject(
            formula.subjectCode ?? '',
            formula.subjectName ?? '',
            subjects,
          ),
        );
        final old = previousById[mapped.id];
        return old?.confirmed == true &&
                old?.structureFingerprint == mapped.structureFingerprint
            ? mapped.copyWith(confirmed: true)
            : mapped;
      }).toList();
      final records = formulas.map(_formulaRecord).toList();
      await _database.replaceAcademicRecords(
        source: AcademicSource.fuc,
        kind: AcademicRecordKind.gradeFormula,
        records: records,
      );
      saved += records.length;
    } on IntegrationException catch (error) {
      errors.add(error.userMessage);
    }
    return saved;
  }

  Future<int> _syncMoodle(String token, List<AcademicSubject> subjects) async {
    final syncStarted = DateTime.now().toUtc();
    final since = await _database.readCursor('moodle_academic');
    final bundle = await _moodle.synchronize(token, since: since);
    final previousCourses = await _database.readAcademicRecords(
      source: AcademicSource.moodle,
      kind: AcademicRecordKind.moodleCourse,
    );
    final previousMappings = {
      for (final record in previousCourses)
        if (record.subjectId != null) record.externalId: record.subjectId!,
    };
    final courseSubjects = <String, String?>{};
    final courseRecords = bundle.courses.map((course) {
      final match = SubjectMapper.match(
        course.shortName,
        course.name,
        subjects,
      );
      final subjectId =
          previousMappings[course.externalId] ?? match.subject?.notionId;
      courseSubjects[course.externalId] = subjectId;
      final payload = {
        ...course.toJson(),
        'subjectId': subjectId,
        'mappingCandidates': [
          for (final candidate in match.candidates)
            {'id': candidate.notionId, 'name': candidate.name},
        ],
        'mappingNeedsReview': subjectId == null,
      };
      return AcademicRecord(
        key: AcademicRecord.keyFor(
          AcademicSource.moodle,
          AcademicRecordKind.moodleCourse,
          course.externalId,
        ),
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.moodleCourse,
        externalId: course.externalId,
        title: course.name,
        subjectId: subjectId,
        payload: payload,
        syncedAt: DateTime.now().toUtc(),
      );
    }).toList();
    await _database.replaceAcademicRecords(
      source: AcademicSource.moodle,
      kind: AcademicRecordKind.moodleCourse,
      records: courseRecords,
    );

    final evaluationRecords = bundle.assignments.map((assignment) {
      final event = EvaluationEvent(
        externalId: assignment.externalId,
        title: assignment.name,
        type: 'Assignment',
        subjectId: courseSubjects[assignment.courseId],
        start: assignment.dueAt,
        registrationState: ExamRegistrationState.unknown,
        provenance: [
          AcademicProvenance(
            source: AcademicSource.moodle,
            externalId: assignment.externalId,
            url: assignment.url,
          ),
        ],
      );
      final payload = {
        ...event.toJson(),
        'courseId': assignment.courseId,
        'submissionState': assignment.submissionState,
      };
      return _evaluationRecord(event, AcademicSource.moodle, payload: payload);
    }).toList();
    if (since == null) {
      await _replaceEvaluations(AcademicSource.moodle, evaluationRecords);
    } else {
      final old = await _database.readAcademicRecords(
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.evaluation,
      );
      final merged = {for (final record in old) record.key: record};
      for (final record in evaluationRecords) {
        merged[record.key] = record;
      }
      await _replaceEvaluations(AcademicSource.moodle, merged.values.toList());
    }

    final announcementRecords = bundle.announcements.map((item) {
      final payload = {
        ...item.toJson(),
        'subjectId': courseSubjects[item.courseId],
      };
      return AcademicRecord(
        key: AcademicRecord.keyFor(
          AcademicSource.moodle,
          AcademicRecordKind.announcement,
          item.externalId,
        ),
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.announcement,
        externalId: item.externalId,
        title: item.title,
        subjectId: courseSubjects[item.courseId],
        startsAt: item.createdAt,
        payload: payload,
        syncedAt: DateTime.now().toUtc(),
      );
    }).toList();
    if (since == null) {
      await _database.replaceAcademicRecords(
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.announcement,
        records: announcementRecords,
      );
    } else {
      final old = await _database.readAcademicRecords(
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.announcement,
      );
      final merged = {for (final record in old) record.key: record};
      for (final record in announcementRecords) {
        merged[record.key] = record;
      }
      await _database.replaceAcademicRecords(
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.announcement,
        records: merged.values.toList(),
      );
    }
    await _database.saveCursor('moodle_academic', syncStarted);
    return courseRecords.length +
        evaluationRecords.length +
        announcementRecords.length;
  }

  @override
  Future<void> addManualEvaluation(EvaluationEvent event) => _database
      .upsertAcademicRecord(_evaluationRecord(event, AcademicSource.manual));

  @override
  Future<void> addManualGrade(GradeComponent component) =>
      _database.upsertAcademicRecord(
        AcademicRecord(
          key: AcademicRecord.keyFor(
            AcademicSource.manual,
            AcademicRecordKind.grade,
            component.externalId,
          ),
          source: AcademicSource.manual,
          kind: AcademicRecordKind.grade,
          externalId: component.externalId,
          title: '${component.subjectName} · ${component.name}',
          subjectId: component.subjectId,
          payload: component.toJson(),
          syncedAt: DateTime.now().toUtc(),
        ),
      );

  @override
  Future<void> confirmFormula(AcademicRecord record) async {
    final formula = AssessmentFormula.fromJson(record.payload);
    final confirmed = formula.copyWith(confirmed: true);
    await _database.upsertAcademicRecord(
      record.copyWith(payload: confirmed.toJson()),
    );
  }

  @override
  Future<void> setEvaluationTypeReminder(String type, int? minutes) async {
    final normalized = SubjectMapper.normalize(type);
    final key = AcademicRecord.keyFor(
      AcademicSource.manual,
      AcademicRecordKind.reminderPreference,
      normalized,
    );
    if (minutes == null) {
      await _database.deleteAcademicRecord(key);
    } else {
      await _database.upsertAcademicRecord(
        AcademicRecord(
          key: key,
          source: AcademicSource.manual,
          kind: AcademicRecordKind.reminderPreference,
          externalId: normalized,
          title: type,
          payload: {'type': type, 'minutes': minutes},
          syncedAt: DateTime.now().toUtc(),
        ),
      );
    }
    final records = await _database.readAcademicRecords(
      kind: AcademicRecordKind.evaluation,
    );
    for (final record in records) {
      final event = EvaluationEvent.fromJson(record.payload);
      if (SubjectMapper.normalize(event.type) == normalized) {
        await setEvaluationReminder(record, minutes);
      }
    }
  }

  @override
  Future<void> setMoodleCourseSubject(
    AcademicRecord course,
    AcademicSubject subject,
  ) async {
    final payload = {
      ...course.payload,
      'subjectId': subject.notionId,
      'mappingNeedsReview': false,
    };
    await _database.upsertAcademicRecord(
      course.copyWith(subjectId: subject.notionId, payload: payload),
    );
    for (final kind in const [
      AcademicRecordKind.evaluation,
      AcademicRecordKind.announcement,
    ]) {
      final records = await _database.readAcademicRecords(
        source: AcademicSource.moodle,
        kind: kind,
      );
      for (final record in records.where(
        (item) => item.payload['courseId'] == course.externalId,
      )) {
        await _database.upsertAcademicRecord(
          record.copyWith(
            subjectId: subject.notionId,
            payload: {...record.payload, 'subjectId': subject.notionId},
          ),
        );
      }
    }
  }

  @override
  Future<void> setEvaluationReminder(
    AcademicRecord record,
    int? minutes,
  ) async {
    final event = EvaluationEvent.fromJson(record.payload);
    final updated = event.copyWith(
      reminderMinutes: minutes,
      clearReminder: minutes == null,
    );
    await _database.upsertAcademicRecord(
      AcademicRecord(
        key: record.key,
        source: record.source,
        kind: record.kind,
        externalId: record.externalId,
        title: record.title,
        subjectId: record.subjectId,
        startsAt: record.startsAt,
        endsAt: record.endsAt,
        payload: updated.toJson(),
        syncedAt: DateTime.now().toUtc(),
      ),
    );
    if (minutes != null) await _notifications.requestPermissions();
    await _scheduleReminder(record.key, updated);
  }

  Future<void> _replaceEvaluations(
    AcademicSource source,
    List<AcademicRecord> records,
  ) async {
    final preferences = await _database.readAcademicRecords(
      source: AcademicSource.manual,
      kind: AcademicRecordKind.reminderPreference,
    );
    final defaultMinutes = {
      for (final record in preferences)
        record.externalId: record.payload['minutes'] as int,
    };
    final effectiveRecords = records.map((record) {
      final event = EvaluationEvent.fromJson(record.payload);
      if (event.reminderMinutes != null) return record;
      final minutes = defaultMinutes[SubjectMapper.normalize(event.type)];
      if (minutes == null) return record;
      return record.copyWith(
        payload: event.copyWith(reminderMinutes: minutes).toJson(),
      );
    }).toList();
    final old = await _database.readAcademicRecords(
      source: source,
      kind: AcademicRecordKind.evaluation,
    );
    final incomingKeys = effectiveRecords.map((item) => item.key).toSet();
    await _database.replaceAcademicRecords(
      source: source,
      kind: AcademicRecordKind.evaluation,
      records: effectiveRecords,
    );
    for (final removed in old.where(
      (item) => !incomingKeys.contains(item.key),
    )) {
      await _notifications.cancelAcademicReminder(removed.key);
    }
    final saved = await _database.readAcademicRecords(
      source: source,
      kind: AcademicRecordKind.evaluation,
    );
    for (final record in saved) {
      final event = EvaluationEvent.fromJson(record.payload);
      if (event.reminderMinutes != null) {
        await _scheduleReminder(record.key, event);
      }
    }
  }

  Future<void> _scheduleReminder(String key, EvaluationEvent event) async {
    await _notifications.cancelAcademicReminder(key);
    final minutes = event.reminderMinutes;
    if (minutes != null) {
      final notifyAt = event.start.subtract(Duration(minutes: minutes));
      if (notifyAt.isAfter(DateTime.now())) {
        await _notifications.scheduleAcademicReminder(
          id: key,
          title: event.title,
          scheduledAt: notifyAt,
        );
      }
    }
  }

  String? _mapSubject(
    String code,
    String name,
    Iterable<AcademicSubject> subjects,
  ) => SubjectMapper.match(code, name, subjects).subject?.notionId;

  ExamRegistration? _matchingRegistration(
    EvaluationEvent event,
    Iterable<ExamRegistration> registrations,
  ) {
    for (final registration in registrations) {
      if (registration.externalId == event.externalId) return registration;
    }
    final eventCode = SubjectMapper.normalize(event.subjectCode ?? '');
    final eventName = SubjectMapper.normalize(event.subjectName ?? '');
    final eventType = SubjectMapper.normalize(event.type);
    for (final registration in registrations) {
      final sameSubject =
          (eventCode.isNotEmpty &&
              SubjectMapper.normalize(registration.subjectCode) == eventCode) ||
          (eventName.isNotEmpty &&
              SubjectMapper.normalize(registration.subjectName) == eventName);
      if (sameSubject &&
          SubjectMapper.normalize(registration.examType) == eventType) {
        return registration;
      }
    }
    return null;
  }

  AcademicRecord _enrollmentRecord(EnrollmentSubject item) => AcademicRecord(
    key: AcademicRecord.keyFor(
      AcademicSource.portal,
      AcademicRecordKind.enrollment,
      item.externalId,
    ),
    source: AcademicSource.portal,
    kind: AcademicRecordKind.enrollment,
    externalId: item.externalId,
    title: item.name,
    subjectId: item.subjectId,
    payload: item.toJson(),
    syncedAt: DateTime.now().toUtc(),
  );

  AcademicRecord _timetableRecord(TimetableSlot item) => AcademicRecord(
    key: AcademicRecord.keyFor(
      AcademicSource.portal,
      AcademicRecordKind.timetable,
      item.externalId,
    ),
    source: AcademicSource.portal,
    kind: AcademicRecordKind.timetable,
    externalId: item.externalId,
    title: item.subjectName,
    subjectId: item.subjectId,
    startsAt: item.start,
    endsAt: item.end,
    payload: item.toJson(),
    syncedAt: DateTime.now().toUtc(),
  );

  AcademicRecord _evaluationRecord(
    EvaluationEvent item,
    AcademicSource source, {
    Map<String, dynamic>? payload,
  }) => AcademicRecord(
    key: AcademicRecord.keyFor(
      source,
      AcademicRecordKind.evaluation,
      item.externalId,
    ),
    source: source,
    kind: AcademicRecordKind.evaluation,
    externalId: item.externalId,
    title: item.title,
    subjectId: item.subjectId,
    startsAt: item.start,
    endsAt: item.end,
    payload: payload ?? item.toJson(),
    syncedAt: DateTime.now().toUtc(),
  );

  AcademicRecord _formulaRecord(AssessmentFormula formula) => AcademicRecord(
    key: AcademicRecord.keyFor(
      AcademicSource.fuc,
      AcademicRecordKind.gradeFormula,
      formula.id,
    ),
    source: AcademicSource.fuc,
    kind: AcademicRecordKind.gradeFormula,
    externalId: formula.id,
    title:
        '${formula.subjectName ?? formula.subjectCode ?? 'Subject'} · ${formula.label}',
    subjectId: formula.subjectId,
    payload: formula.toJson(),
    syncedAt: DateTime.now().toUtc(),
  );
}
