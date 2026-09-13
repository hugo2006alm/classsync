import 'dart:async';

import 'package:collection/collection.dart';

import '../../domain/academic/academic_hub_models.dart';
import '../../domain/academic/academic_hub_actions.dart';
import '../../domain/academic/academic_models.dart';
import '../../domain/academic/portal_record_validation.dart';
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
    await _running;
    final cleanUsername = username.trim();
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
  Future<void> connectMoodle({
    required String username,
    required String password,
  }) async {
    final secret = password.isEmpty
        ? await _credentials.read(CredentialKey.portalPassword) ?? ''
        : password;
    String token;
    try {
      token = await _moodle.authenticate(username: username, password: secret);
      await _moodle.testConnection(token);
    } on IntegrationException catch (error) {
      throw AcademicActionFailure(error.userMessage);
    }
    await _credentials.write(CredentialKey.moodleToken, token);
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

  Future<AcademicSyncResult>? _running;
  int focusedSection = 0;
  final _updates = StreamController<AcademicRefreshState>.broadcast();
  AcademicRefreshState refreshState = const AcademicRefreshState();
  Stream<AcademicRefreshState> get refreshUpdates => _updates.stream;
  void dispose() => _updates.close();

  void _report({
    bool running = true,
    String? stage,
    List<String> errors = const [],
  }) {
    refreshState = AcademicRefreshState(
      running: running,
      stage: stage,
      errors: List.unmodifiable(errors),
    );
    if (!_updates.isClosed) _updates.add(refreshState);
  }

  Future<AcademicSyncResult> synchronize({
    bool force = true,
    Set<String>? onlyStages,
    DateTime? timetableFrom,
  }) async {
    final active = _running;
    if (active != null) {
      if (!force && onlyStages == null) return active;
      await active;
      return synchronize(
        force: force,
        onlyStages: onlyStages,
        timetableFrom: timetableFrom,
      );
    }
    final operation = _synchronize(
      force: force,
      onlyStages: onlyStages,
      timetableFrom: timetableFrom,
    );
    _running = operation;
    try {
      return await operation;
    } finally {
      if (identical(_running, operation)) _running = null;
      if (refreshState.running) {
        _report(
          running: false,
          errors: const [
            'Academic refresh could not complete. Try Refresh again.',
          ],
        );
      }
    }
  }

  Future<bool> _due(String key, Duration age, bool force) async {
    if (force) return true;
    if (key == 'timetable' &&
        await _database.readCursor('academic_timetable_window_v2') == null) {
      return true;
    }
    if (key == 'history' &&
        await _database.readCursor('academic_history_curriculum_v2') == null) {
      return true;
    }
    final last = await _database.readCursor('academic_success_$key');
    final attempt = await _database.readCursor('academic_attempt_$key');
    final now = DateTime.now().toUtc();
    if (attempt != null &&
        now.difference(attempt) < const Duration(minutes: 5)) {
      return false;
    }
    return last == null || now.difference(last) >= age;
  }

  Future<AcademicSyncResult> _synchronize({
    required bool force,
    required Set<String>? onlyStages,
    required DateTime? timetableFrom,
  }) async {
    _report();
    await repairPortalCache();
    final errors = <String>[];
    final sources = <AcademicSource>{};
    var saved = 0;
    final subjects = await _database.readActiveSubjects();
    final portalUser = await _credentials.read(CredentialKey.portalUsername);
    final portalPassword = await _credentials.read(
      CredentialKey.portalPassword,
    );
    final work = <Future<void>>[];
    final moodleToken = await _credentials.read(CredentialKey.moodleToken);
    if (moodleToken != null &&
        (onlyStages == null || onlyStages.contains('moodle'))) {
      sources.add(AcademicSource.moodle);
      work.add(() async {
        if (!await _due('moodle', const Duration(minutes: 30), force)) return;
        await _database.saveCursor(
          'academic_attempt_moodle',
          DateTime.now().toUtc(),
        );
        try {
          final count = await _syncMoodle(moodleToken, subjects);
          saved += count;
          await _database.saveCursor(
            'academic_success_moodle',
            DateTime.now().toUtc(),
          );
        } on IntegrationException catch (error) {
          errors.add('Moodle: ${error.userMessage}');
        } catch (_) {
          errors.add(
            'Moodle could not refresh. Cached data is still available.',
          );
        }
        _report(stage: 'Moodle', errors: errors);
      }());
    }
    final portalStages = onlyStages
        ?.where((stage) => stage != 'moodle')
        .toSet();
    if (portalUser != null &&
        portalPassword != null &&
        (onlyStages == null || portalStages!.isNotEmpty)) {
      sources.add(AcademicSource.portal);
      work.add(() async {
        final portalErrors = <String>[];
        try {
          final count = await _syncPortal(
            subjects,
            portalErrors,
            force: force,
            onlyStages: portalStages,
            timetableFrom: timetableFrom,
            credentials: PortalCredentials(
              username: portalUser,
              password: portalPassword,
            ),
          );
          saved += count;
        } on IntegrationException catch (error) {
          errors.add('Portal: ${error.userMessage}');
        } catch (_) {
          errors.add(
            'Portal could not refresh. Cached data is still available.',
          );
        }
        errors.addAll(portalErrors);
      }());
    }
    await Future.wait(work);
    _report(running: false, errors: errors);
    return AcademicSyncResult(saved: saved, sources: sources, errors: errors);
  }

  Future<void> repairPortalCache() async {
    final records = await _database.readAcademicRecords();
    for (final record in records) {
      if (isInvalidPortalRecord(record)) {
        try {
          await _notifications.cancelAcademicReminder(record.key);
        } catch (_) {
          // Keep the row for cancellation retry; UI/search exclude it meanwhile.
          continue;
        }
        await _database.transaction(() async {
          await _database.deleteAcademicRecord(record.key);
          await (_database.delete(
            _database.academicChangeRecords,
          )..where((row) => row.recordKey.equals(record.key))).go();
          final stage = switch (record.kind) {
            AcademicRecordKind.tuitionCharge => 'finance',
            AcademicRecordKind.examRegistration => 'exams',
            AcademicRecordKind.enrollment => 'enrollment',
            AcademicRecordKind.academicHistory => 'history',
            _ => null,
          };
          if (stage != null) {
            await (_database.delete(_database.syncCursors)..where(
                  (row) => row.source.isIn([
                    'academic_success_$stage',
                    'academic_attempt_$stage',
                  ]),
                ))
                .go();
          }
        });
      }
    }
  }

  Future<int> _syncPortal(
    List<AcademicSubject> subjects,
    List<String> errors, {
    required bool force,
    required Set<String>? onlyStages,
    required DateTime? timetableFrom,
    required PortalCredentials credentials,
  }) async {
    var saved = 0;
    final stages = <String, Future<void> Function()>{
      'enrollment': () async {
        try {
          final enrollment = (await _portal.getEnrollment())
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
      },
      'timetable': () async {
        try {
          final windowStart = _academicWeekStart(
            timetableFrom ?? DateTime.now(),
          );
          final windowEnd = windowStart.add(const Duration(days: 35));
          final slots =
              (await _portal.getTimetable(from: windowStart, weeks: 5))
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
          final previous = await _database.readAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.timetable,
          );
          final retained = previous.where((record) {
            final start = record.startsAt;
            return start == null ||
                start.isBefore(windowStart) ||
                !start.isBefore(windowEnd);
          });
          await _database.replaceAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.timetable,
            records: [...retained, ...records],
          );
          saved += records.length;
        } on IntegrationException catch (error) {
          errors.add(error.userMessage);
        }
      },
      'exams': () async {
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
        if (registrations.isNotEmpty) {
          final previousRegistrations = await _database.readAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.examRegistration,
          );
          final records = registrations.map((registration) {
            final subjectId = _mapSubject(
              registration.subjectCode,
              registration.subjectName,
              subjects,
            );
            return AcademicRecord(
              key: AcademicRecord.keyFor(
                AcademicSource.portal,
                AcademicRecordKind.examRegistration,
                registration.externalId,
              ),
              source: AcademicSource.portal,
              kind: AcademicRecordKind.examRegistration,
              externalId: registration.externalId,
              title: '${registration.examType} · ${registration.subjectName}',
              subjectId: subjectId,
              startsAt: registration.examAt ?? registration.registrationOpensAt,
              endsAt: registration.registrationClosesAt,
              payload: {...registration.toJson(), 'subjectId': subjectId},
              syncedAt: DateTime.now().toUtc(),
            );
          }).toList();
          await _database.replaceAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.examRegistration,
            records: records,
          );
          final incomingKeys = records.map((record) => record.key).toSet();
          for (final removed in previousRegistrations.where(
            (record) => !incomingKeys.contains(record.key),
          )) {
            await _notifications.cancelAcademicReminder(removed.key);
          }
          saved += records.length;
          for (final registration in records) {
            final closes = registration.endsAt;
            final reminderAt = closes?.subtract(const Duration(days: 1));
            if (closes != null &&
                closes.isAfter(DateTime.now()) &&
                reminderAt!.isAfter(DateTime.now()) &&
                registration.payload['state'] !=
                    ExamRegistrationState.registered.name) {
              await _notifications.scheduleAcademicReminder(
                id: registration.key,
                title: 'Exam registration closes: ${registration.title}',
                scheduledAt: reminderAt,
              );
            }
          }
        }
      },
      'grades': () async {
        final grades = <GradeComponent>[];
        try {
          grades.addAll(await _portal.getGrades());
        } on IntegrationException catch (error) {
          errors.add(error.userMessage);
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
      },
      'history': () async {
        try {
          final history = await _portal.getAcademicHistory();
          final records = history.map((item) {
            final subjectId = _mapSubject(
              item.subjectCode ?? '',
              item.subjectName,
              subjects,
            );
            return AcademicRecord(
              key: AcademicRecord.keyFor(
                AcademicSource.portal,
                AcademicRecordKind.academicHistory,
                item.externalId,
              ),
              source: AcademicSource.portal,
              kind: AcademicRecordKind.academicHistory,
              externalId: item.externalId,
              title: item.subjectName,
              subjectId: subjectId,
              payload: {...item.toJson(), 'subjectId': subjectId},
              syncedAt: DateTime.now().toUtc(),
            );
          }).toList();
          await _database.replaceAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.academicHistory,
            records: records,
          );
          saved += records.length;
        } on IntegrationException catch (error) {
          errors.add(error.userMessage);
        }
      },
      'formulas': () async {
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
      },
      'context': () async {
        try {
          final profiles = await _portal.getFucProfiles();
          final records = profiles.map((profile) {
            final subjectId = _mapSubject(
              profile.subjectCode,
              profile.subjectName,
              subjects,
            );
            return AcademicRecord(
              key: AcademicRecord.keyFor(
                AcademicSource.fuc,
                AcademicRecordKind.fucProfile,
                profile.id,
              ),
              source: AcademicSource.fuc,
              kind: AcademicRecordKind.fucProfile,
              externalId: profile.id,
              title: profile.subjectName,
              subjectId: subjectId,
              payload: {...profile.toJson(), 'subjectId': subjectId},
              syncedAt: DateTime.now().toUtc(),
            );
          }).toList();
          await _database.replaceAcademicRecords(
            source: AcademicSource.fuc,
            kind: AcademicRecordKind.fucProfile,
            records: records,
          );
          saved += records.length;
        } on IntegrationException catch (error) {
          errors.add(error.userMessage);
        }
      },
      'notices': () async {
        try {
          final previous = await _database.readAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.portalNotification,
          );
          final previousKeys = previous.map((item) => item.key).toSet();
          final notifications = await _portal.getNotifications();
          final records = notifications
              .map(
                (item) => AcademicRecord(
                  key: AcademicRecord.keyFor(
                    AcademicSource.portal,
                    AcademicRecordKind.portalNotification,
                    item.id,
                  ),
                  source: AcademicSource.portal,
                  kind: AcademicRecordKind.portalNotification,
                  externalId: item.id,
                  title: item.title,
                  startsAt: item.createdAt,
                  payload: item.toJson(),
                  syncedAt: DateTime.now().toUtc(),
                ),
              )
              .toList();
          await _database.replaceAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.portalNotification,
            records: records,
          );
          final settings = await _database.readSettings();
          if (previous.isNotEmpty &&
              settings.notificationsEnabled &&
              await _academicNotificationEnabled('portalNotification')) {
            for (final record in records.where(
              (item) => !previousKeys.contains(item.key),
            )) {
              await _notifications.showAcademicUpdate(
                id: record.key,
                title: 'ISEP Portal · ${record.title}',
                body: record.payload['message'] as String? ?? '',
              );
            }
          }
          saved += records.length;
        } on IntegrationException catch (error) {
          errors.add(error.userMessage);
        }
      },
      'finance': () async {
        try {
          final previous = await _database.readAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.tuitionCharge,
          );
          final previousByKey = {for (final item in previous) item.key: item};
          final charges = await _portal.getTuitionCharges();
          final records = charges.map((charge) {
            final title = [
              charge.title,
              if (charge.installment?.isNotEmpty == true) charge.installment!,
            ].join(' · ');
            return AcademicRecord(
              key: AcademicRecord.keyFor(
                AcademicSource.portal,
                AcademicRecordKind.tuitionCharge,
                charge.id,
              ),
              source: AcademicSource.portal,
              kind: AcademicRecordKind.tuitionCharge,
              externalId: charge.id,
              title: title,
              startsAt: charge.dueAt,
              payload: charge.toJson(),
              syncedAt: DateTime.now().toUtc(),
            );
          }).toList();
          await _replaceTuitionCharges(records);
          final savedCharges = await _database.readAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.tuitionCharge,
          );
          final settings = await _database.readSettings();
          final now = DateTime.now();
          for (final record in savedCharges) {
            final charge = TuitionCharge.fromJson(record.payload);
            final previousCharge = previousByKey[record.key] == null
                ? null
                : TuitionCharge.fromJson(previousByKey[record.key]!.payload);
            if (previousCharge != null &&
                !previousCharge.isOverdueAt(now) &&
                charge.isOverdueAt(now) &&
                charge.overdueReminder &&
                settings.notificationsEnabled) {
              await _notifications.showAcademicUpdate(
                id: record.key,
                title: 'Payment overdue · ${record.title}',
                body:
                    'Review this read-only Portal charge. ClassSync cannot make payments.',
                section: 5,
              );
            }
          }
          saved += records.length;
        } on IntegrationException catch (error) {
          errors.add(error.userMessage);
        }
      },
      'summaries': () async {
        try {
          final jobs = await _database.readJobs();
          final summaries = await _portal.getLessonSummaries();
          final records = summaries.map((item) {
            final subjectId = _mapSubject(
              item.subjectCode,
              item.subjectName,
              subjects,
            );
            final candidates =
                jobs.where((job) {
                  final sameSubject =
                      subjectId != null && job.subjectId == subjectId;
                  final deltaSeconds = job.meetingDate
                      .difference(item.date)
                      .inSeconds
                      .abs();
                  return sameSubject &&
                      deltaSeconds <= const Duration(hours: 12).inSeconds;
                }).toList()..sort(
                  (a, b) => a.meetingDate
                      .difference(item.date)
                      .inSeconds
                      .abs()
                      .compareTo(
                        b.meetingDate.difference(item.date).inSeconds.abs(),
                      ),
                );
            final match = candidates.firstOrNull;
            final matchConfidence = match == null
                ? 0.0
                : match.meetingDate.difference(item.date).inMinutes.abs() <= 120
                ? 0.95
                : 0.80;
            final generatedText = match?.summaryJson == null
                ? ''
                : LectureSummary.decode(
                    match!.summaryJson!,
                  ).toJson().toString();
            final officialTerms = SubjectMapper.normalize(
              item.text,
            ).split(' ').toSet();
            final generatedTerms = SubjectMapper.normalize(
              generatedText,
            ).split(' ').toSet();
            final overlap = officialTerms.isEmpty
                ? 0.0
                : officialTerms.intersection(generatedTerms).length /
                      officialTerms.length;
            return AcademicRecord(
              key: AcademicRecord.keyFor(
                AcademicSource.portal,
                AcademicRecordKind.lessonSummary,
                item.id,
              ),
              source: AcademicSource.portal,
              kind: AcademicRecordKind.lessonSummary,
              externalId: item.id,
              title: item.subjectName,
              subjectId: subjectId,
              startsAt: item.date,
              payload: {
                ...item.toJson(),
                'subjectId': subjectId,
                'matchedLectureId': match?.id,
                'matchConfidence': matchConfidence,
                'coverage': overlap,
                'coverageNeedsReview': match != null && overlap < 0.25,
              },
              syncedAt: DateTime.now().toUtc(),
            );
          }).toList();
          await _database.replaceAcademicRecords(
            source: AcademicSource.portal,
            kind: AcademicRecordKind.lessonSummary,
            records: records,
          );
          saved += records.length;
        } on IntegrationException catch (error) {
          errors.add(error.userMessage);
        }
      },
    };
    final pending = <String>[];
    for (final key in stages.keys) {
      if (onlyStages != null && !onlyStages.contains(key)) continue;
      if (await _due(key, academicRefreshAge(key), force)) pending.add(key);
    }
    if (pending.isEmpty) return 0;
    for (final key in pending) {
      await _database.saveCursor(
        'academic_attempt_$key',
        DateTime.now().toUtc(),
      );
    }
    _report(stage: 'Connecting to Portal', errors: errors);
    await _portal.authenticate(credentials);
    while (pending.isNotEmpty) {
      // Re-evaluate focus between requests. In-flight requests finish normally.
      final priorities = academicStagePriority(focusedSection);
      pending.sort(
        (a, b) => priorities.indexOf(a).compareTo(priorities.indexOf(b)),
      );
      final key = pending.removeAt(0);
      _report(stage: key, errors: errors);
      final before = errors.length;
      try {
        await stages[key]!();
      } catch (_) {
        errors.add(
          'Portal $key could not refresh. Cached data is still available.',
        );
      }
      if (errors.length == before) {
        await _database.saveCursor(
          'academic_success_$key',
          DateTime.now().toUtc(),
        );
        if (key == 'timetable') {
          await _database.saveCursor(
            'academic_timetable_window_v2',
            DateTime.now().toUtc(),
          );
        }
        if (key == 'history') {
          await _database.saveCursor(
            'academic_history_curriculum_v2',
            DateTime.now().toUtc(),
          );
        }
      } else {
        for (var i = before; i < errors.length; i++) {
          errors[i] = 'Portal $key: ${errors[i]}';
        }
      }
      _report(stage: key, errors: errors);
    }
    return saved;
  }

  Future<int> _syncMoodle(String token, List<AcademicSubject> subjects) async {
    final syncStarted = DateTime.now().toUtc();
    final since = await _database.readCursor('moodle_academic');
    final courseSubjects = <String, String?>{};
    var courseRecords = <AcademicRecord>[];
    Future<void> saveCourses(List<MoodleCourse> courses) async {
      final previousCourses = await _database.readAcademicRecords(
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.moodleCourse,
      );
      final previousMappings = {
        for (final record in previousCourses)
          if (record.subjectId != null) record.externalId: record.subjectId!,
      };
      courseRecords = courses.map((course) {
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

      await _database.saveCursor(
        'academic_success_courses',
        DateTime.now().toUtc(),
      );
    }

    final bundle = await _moodle.synchronize(
      token,
      since: since,
      onCourses: saveCourses,
    );
    await saveCourses(bundle.courses);

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

    final oldAnnouncements = await _database.readAcademicRecords(
      source: AcademicSource.moodle,
      kind: AcademicRecordKind.announcement,
    );
    final oldAnnouncementKeys = oldAnnouncements
        .map((item) => item.key)
        .toSet();
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
      final merged = {
        for (final record in oldAnnouncements) record.key: record,
      };
      for (final record in announcementRecords) {
        merged[record.key] = record;
      }
      await _database.replaceAcademicRecords(
        source: AcademicSource.moodle,
        kind: AcademicRecordKind.announcement,
        records: merged.values.toList(),
      );
    }
    final settings = await _database.readSettings();
    if (since != null &&
        oldAnnouncements.isNotEmpty &&
        settings.notificationsEnabled &&
        await _academicNotificationEnabled('moodleAnnouncement')) {
      for (final record in announcementRecords.where(
        (item) => !oldAnnouncementKeys.contains(item.key),
      )) {
        await _notifications.showAcademicUpdate(
          id: record.key,
          title: 'Moodle · ${record.title}',
          body: record.payload['preview'] as String? ?? '',
        );
      }
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
  Future<void> updateLectureTask(
    AcademicRecord record, {
    String? title,
    String? description,
    DateTime? dueAt,
    bool clearDueAt = false,
    LectureTaskStatus? status,
  }) async {
    final task = LectureTask.fromJson(record.payload).copyWith(
      title: title,
      description: description,
      dueAt: dueAt,
      clearDueAt: clearDueAt,
      status: status,
    );
    await _database.upsertAcademicRecord(
      AcademicRecord(
        key: record.key,
        source: record.source,
        kind: record.kind,
        externalId: record.externalId,
        title: task.title,
        subjectId: task.subjectId,
        startsAt: task.dueAt,
        payload: {
          ...task.toJson(),
          'userEdited':
              title != null ||
              description != null ||
              dueAt != null ||
              clearDueAt,
        },
        syncedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> markPortalNotificationRead(AcademicRecord record) =>
      _database.upsertAcademicRecord(
        record.copyWith(payload: {...record.payload, 'read': true}),
      );

  @override
  Future<void> setAcademicUpdateNotifications(String source, bool enabled) =>
      _database.upsertAcademicRecord(
        AcademicRecord(
          key: AcademicRecord.keyFor(
            AcademicSource.manual,
            AcademicRecordKind.reminderPreference,
            'updates:$source',
          ),
          source: AcademicSource.manual,
          kind: AcademicRecordKind.reminderPreference,
          externalId: 'updates:$source',
          title: '$source update notifications',
          payload: {'source': source, 'enabled': enabled},
          syncedAt: DateTime.now().toUtc(),
        ),
      );

  Future<bool> _academicNotificationEnabled(String source) async {
    final record = await _database.readAcademicRecord(
      AcademicRecord.keyFor(
        AcademicSource.manual,
        AcademicRecordKind.reminderPreference,
        'updates:$source',
      ),
    );
    return record?.payload['enabled'] as bool? ?? true;
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

  @override
  Future<void> setTuitionReminder(
    AcademicRecord record,
    int? minutes, {
    required bool overdueReminder,
  }) async {
    final charge = TuitionCharge.fromJson(record.payload).copyWith(
      reminderMinutes: minutes,
      clearReminder: minutes == null,
      overdueReminder: overdueReminder,
    );
    final updated = AcademicRecord(
      key: record.key,
      source: record.source,
      kind: record.kind,
      externalId: record.externalId,
      title: record.title,
      startsAt: charge.dueAt,
      payload: {...charge.toJson(), 'overdueReminderConfigured': true},
      syncedAt: DateTime.now().toUtc(),
    );
    await _database.upsertAcademicRecord(updated);
    if (minutes != null || overdueReminder) {
      await _notifications.requestPermissions();
    }
    await _scheduleTuitionReminder(updated.key, charge);
    final settings = await _database.readSettings();
    if (overdueReminder &&
        charge.isOverdueAt(DateTime.now()) &&
        settings.notificationsEnabled) {
      await _notifications.showAcademicUpdate(
        id: updated.key,
        title: 'Payment overdue · ${updated.title}',
        body:
            'Review this read-only Portal charge. ClassSync cannot make payments.',
        section: 5,
      );
    }
  }

  Future<void> _replaceTuitionCharges(List<AcademicRecord> records) async {
    final old = await _database.readAcademicRecords(
      source: AcademicSource.portal,
      kind: AcademicRecordKind.tuitionCharge,
    );
    final incomingKeys = records.map((item) => item.key).toSet();
    await _database.replaceAcademicRecords(
      source: AcademicSource.portal,
      kind: AcademicRecordKind.tuitionCharge,
      records: records,
    );
    for (final removed in old.where(
      (item) => !incomingKeys.contains(item.key),
    )) {
      await _cancelTuitionReminders(removed.key);
    }
    final saved = await _database.readAcademicRecords(
      source: AcademicSource.portal,
      kind: AcademicRecordKind.tuitionCharge,
    );
    for (final record in saved) {
      await _scheduleTuitionReminder(
        record.key,
        TuitionCharge.fromJson(record.payload),
      );
    }
  }

  Future<void> _scheduleTuitionReminder(
    String key,
    TuitionCharge charge,
  ) async {
    await _cancelTuitionReminders(key);
    final now = DateTime.now();
    if (!charge.isOpenAt(now) || charge.dueAt == null) {
      return;
    }
    if (charge.reminderMinutes != null) {
      final notifyAt = charge.dueAt!.subtract(
        Duration(minutes: charge.reminderMinutes!),
      );
      if (notifyAt.isAfter(now)) {
        await _notifications.scheduleAcademicReminder(
          id: '$key:due',
          title: 'Payment due · ${charge.title}',
          scheduledAt: notifyAt,
          section: 5,
        );
      }
    }
    if (charge.overdueReminder) {
      var dailyAt = DateTime(
        charge.dueAt!.year,
        charge.dueAt!.month,
        charge.dueAt!.day,
        9,
      );
      if (!dailyAt.isAfter(now)) {
        dailyAt = DateTime(now.year, now.month, now.day, 9);
        if (!dailyAt.isAfter(now)) {
          dailyAt = dailyAt.add(const Duration(days: 1));
        }
      }
      await _notifications.scheduleAcademicReminder(
        id: '$key:daily',
        title: 'Payment still due · ${charge.title}',
        scheduledAt: dailyAt,
        section: 5,
        repeatDaily: true,
      );
    }
  }

  Future<void> _cancelTuitionReminders(String key) async {
    await _notifications.cancelAcademicReminder(key);
    await _notifications.cancelAcademicReminder('$key:due');
    await _notifications.cancelAcademicReminder('$key:daily');
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

class AcademicRefreshState {
  const AcademicRefreshState({
    this.running = false,
    this.stage,
    this.errors = const [],
  });
  final bool running;
  final String? stage;
  final List<String> errors;
}

Duration academicRefreshAge(String stage) => switch (stage) {
  'timetable' || 'exams' || 'notices' => const Duration(minutes: 30),
  'grades' || 'finance' => const Duration(hours: 6),
  _ => const Duration(hours: 24),
};

List<String> academicStagePriority(int section) {
  const baseline = [
    'timetable',
    'exams',
    'notices',
    'enrollment',
    'grades',
    'finance',
    'history',
    'formulas',
    'context',
    'summaries',
  ];
  final focused = switch (section) {
    1 => ['moodle'],
    2 => ['exams'],
    3 => ['notices', 'context', 'summaries'],
    4 => ['grades', 'history', 'enrollment', 'formulas'],
    5 => ['finance'],
    _ => ['timetable', 'exams'],
  };
  return [...focused, ...baseline.where((key) => !focused.contains(key))];
}

Set<String> academicStagesForSection(int section) => switch (section) {
  0 => {'timetable'},
  1 => <String>{},
  2 => {'exams', 'moodle'},
  3 => {'notices', 'context', 'summaries', 'moodle'},
  4 => {'grades', 'history', 'enrollment', 'formulas'},
  5 => {'finance'},
  _ => <String>{},
};

DateTime _academicWeekStart(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  return local.subtract(Duration(days: local.weekday - DateTime.monday));
}
