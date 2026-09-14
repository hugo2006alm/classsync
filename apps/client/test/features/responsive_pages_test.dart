import 'dart:async';

import 'package:classsync/app/theme/classsync_theme.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/providers.dart';
import 'package:classsync/core/integrations/notion/notion_client.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:classsync/domain/settings/app_settings.dart';
import 'package:classsync/domain/settings/fireflies_connection.dart';
import 'package:classsync/domain/sync/sync_models.dart';
import 'package:classsync/features/classes/class_detail_screen.dart';
import 'package:classsync/features/classes/classes_screen.dart';
import 'package:classsync/features/academic/academic_screen.dart';
import 'package:classsync/features/overview/overview_screen.dart';
import 'package:classsync/features/library/library_screen.dart';
import 'package:classsync/features/settings/settings_screen.dart';
import 'package:classsync/features/sync/job_detail_screen.dart';
import 'package:classsync/features/sync/sync_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClassSyncDatabase database;

  setUp(() async {
    database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
  });

  tearDown(() => database.close());

  testWidgets('phone overview metric cards do not overflow', (tester) async {
    _usePhoneViewport(tester);
    await database.replaceSubjects([_subject]);

    await tester.pumpWidget(
      _app(database, const OverviewScreen(), subjects: [_subject]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active classes'), findsWidgets);
    expect(find.text('3º Ano · 1º Semestre'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('overview greets the configured account name', (tester) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(
      _app(
        database,
        const OverviewScreen(),
        settings: AppSettings.defaults.copyWith(displayName: 'Hugo'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(', Hugo'), findsOneWidget);
    expect(find.textContaining(', ClassSync'), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('phone academic hub keeps all sections reachable', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      _app(database, const AcademicScreen(), subjects: [_subject]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Timetable'), findsWidgets);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Search & ask'), findsNothing);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Evaluations'), findsOneWidget);
    expect(find.text('Grades & progress'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Updates'), findsNothing);
    expect(find.text('Course context'), findsNothing);
    final timetableChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Timetable'),
    );
    expect(timetableChip.showCheckmark, isFalse);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('phone timetable defaults to agenda and can switch to table', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await _saveTimetable(database);

    await tester.pumpWidget(
      _app(
        database,
        const AcademicScreen(),
        subjects: [_subject],
        credentialStore: _PortalCredentialStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Room B301'), findsOneWidget);
    expect(find.textContaining('Teacher Jane Teacher'), findsOneWidget);
    expect(find.text('TIME'), findsNothing);
    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('09:10–10:00'), findsOneWidget);
    expect(find.text('10:10–11:00'), findsOneWidget);
    expect(find.textContaining('Room B301'), findsNWidgets(2));
    expect(find.textContaining('Teacher Jane Teacher'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('desktop timetable is a horizontally scrollable time-day grid', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await _saveTimetable(database);

    await tester.pumpWidget(
      _app(
        database,
        const AcademicScreen(),
        subjects: [_subject],
        credentialStore: _PortalCredentialStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('09:10–10:00'), findsOneWidget);
    expect(find.text('10:10–11:00'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(Table),
        matching: find.byType(SingleChildScrollView),
      ),
      findsWidgets,
    );
    expect(find.byTooltip('Reload Timetable only'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reload'), findsOneWidget);
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('Operating Systems'), findsNWidgets(2));
    expect(find.text('09:10–10:00'), findsOneWidget);
    expect(find.text('10:10–11:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('grades and progress show current and previous Portal results', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await _saveGrade(
      database,
      const GradeComponent(
        externalId: 'current-grade',
        subjectName: 'Operating Systems',
        subjectId: 'subject-1',
        name: 'Current project',
        value: 16,
        source: GradeValueSource.officialPortal,
      ),
      AcademicRecordKind.grade,
    );
    await _saveGrade(
      database,
      const GradeComponent(
        externalId: 'previous-grade',
        subjectName: 'Operating Systems',
        subjectId: 'subject-1',
        name: 'Final result',
        value: 14,
        academicYear: '2025/2026',
        isFinal: true,
        isHistorical: true,
        ects: 6,
        source: GradeValueSource.officialPortal,
      ),
      AcademicRecordKind.academicHistory,
    );

    await tester.pumpWidget(
      _app(
        database,
        const AcademicScreen(initialSection: 4),
        subjects: [_subject],
        credentialStore: _PortalCredentialStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current project'), findsOneWidget);
    expect(find.text('Official history'), findsOneWidget);
    expect(find.text('2025/2026 · Final result'), findsOneWidget);
    expect(find.textContaining('6.0 ECTS confirmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('phone sync header gives title and actions their own rows', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(_app(database, const SyncScreen()));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('Sync').first);
    final importButton = tester.getRect(find.text('Import transcript'));
    expect(title.width, greaterThan(100));
    expect(importButton.top, greaterThan(title.bottom));
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('Gemini choices use two named model dropdowns', (tester) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(_app(database, const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI & summaries'));
    await tester.pumpAndSettle();
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Identify classes with AI automatically'), findsOneWidget);
    expect(
      find.byKey(
        ValueKey(
          'classification-model:${AppSettings.defaults.classificationModel}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey('summary-model:${AppSettings.defaults.summaryModel}'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('phone transcript opens in a full-screen dialog', (tester) async {
    _usePhoneViewport(tester);
    await database.discoverJob(
      id: 'transcript-job',
      firefliesId: 'meeting-transcript',
      title: 'Full lecture',
      meetingDate: DateTime.utc(2026, 9, 14),
    );
    await database.saveTranscript(
      'transcript-job',
      LectureTranscript(
        firefliesId: 'meeting-transcript',
        title: 'Full lecture',
        date: DateTime.utc(2026, 9, 14),
        sentences: const [
          TranscriptSentence(text: 'The complete transcript is visible here.'),
        ],
      ),
    );

    await tester.pumpWidget(
      _app(database, const JobDetailScreen(jobId: 'transcript-job')),
    );
    await tester.pumpAndSettle();
    final maximize = find.byTooltip('Open full transcript');
    await tester.ensureVisible(maximize);
    await tester.tap(maximize);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.textContaining('complete transcript is visible'),
      findsOneWidget,
    );
    expect(find.byTooltip('Close transcript'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('credential tiles stay neutral until secure storage responds', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final credentials = _ControlledCredentialStore();

    await tester.pumpWidget(
      _app(database, const SettingsScreen(), credentialStore: credentials),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connections'));
    await tester.pumpAndSettle();
    expect(find.text('Checking secure storage…'), findsNWidgets(5));
    credentials.complete(CredentialKey.firefliesApiKey, false);
    credentials.complete(CredentialKey.geminiApiKey, true);
    credentials.complete(CredentialKey.notionToken, true);
    credentials.complete(CredentialKey.portalUsername, true);
    credentials.complete(CredentialKey.portalPassword, true);
    credentials.complete(CredentialKey.moodleToken, true);
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsNWidgets(4));
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('ClassSync Relay'), findsNothing);
    expect(find.textContaining('Device API token'), findsNothing);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('Fireflies settings identify every named source', (tester) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(
      _app(
        database,
        const SettingsScreen(),
        credentialStore: _NamedCredentialStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connections'));
    await tester.pumpAndSettle();

    expect(find.text('2 sources'), findsOneWidget);
    expect(find.text('Hugo · Ana'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('adding Fireflies source never asks for Device API token', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      _app(
        database,
        const SettingsScreen(),
        credentialStore: _NamedCredentialStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connections'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Manage Fireflies sources'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add Fireflies source'));
    await tester.pumpAndSettle();

    expect(find.text('Fireflies API key'), findsOneWidget);
    expect(find.text('Polling · Enabled'), findsOneWidget);
    expect(find.textContaining('Device API token'), findsNothing);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('Android automation page hides Windows-only startup setting', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(
      _app(database, const SettingsScreen(), platform: TargetPlatform.android),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();

    expect(find.text('Background mobile sync'), findsOneWidget);
    expect(find.text('Launch with Windows'), findsNothing);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('Windows automation page hides Android-only background setting', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(
      _app(database, const SettingsScreen(), platform: TargetPlatform.windows),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();

    expect(find.text('Launch with Windows'), findsOneWidget);
    expect(find.text('Background mobile sync'), findsNothing);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('class detail renders an informative empty state on phone', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await database.replaceSubjects([_subject]);

    await tester.pumpWidget(
      _app(
        database,
        const ClassDetailScreen(subjectId: 'subject-1'),
        subjects: [_subject],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operating Systems'), findsOneWidget);
    expect(find.text('3º Ano · 1º Semestre · In progress'), findsOneWidget);
    expect(find.text('No summaries for this class'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('done class loads newest Notion summaries without local jobs', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final done = _copySubject(
      id: 'done-subject',
      name: 'Completed systems',
      status: 'Done',
    );
    final notionSummaries = [
      NotionSummaryRecord(
        id: 'older',
        title: 'Older lecture',
        date: DateTime(2026, 8, 20),
        subjectIds: const ['done-subject'],
        url: 'https://www.notion.so/older',
      ),
      NotionSummaryRecord(
        id: 'newer',
        title: 'Newest lecture',
        date: DateTime(2026, 9, 7),
        subjectIds: const ['done-subject'],
        url: 'https://www.notion.so/newer',
      ),
    ];

    await tester.pumpWidget(
      _app(
        database,
        const ClassDetailScreen(subjectId: 'done-subject'),
        subjects: [done],
        subjectSummaries: notionSummaries,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Newest lecture'), findsOneWidget);
    expect(find.text('Older lecture'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Newest lecture')).dy,
      lessThan(tester.getTopLeft(find.text('Older lecture')).dy),
    );
    expect(find.textContaining('Notion'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('classes keep future and previous subjects in compact drawers', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final future = _copySubject(
      id: 'future',
      name: 'Future systems',
      status: 'Not Done',
    );
    final previous = _copySubject(
      id: 'previous',
      name: 'Past systems',
      status: 'Done',
    );
    await tester.pumpWidget(
      _app(
        database,
        const ClassesScreen(),
        subjects: [_subject, future, previous],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Future classes'), findsOneWidget);
    expect(find.text('Previous classes'), findsOneWidget);
    expect(find.text('Future systems'), findsNothing);
    await tester.tap(find.text('Future classes'));
    await tester.pumpAndSettle();
    expect(find.text('Future systems'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('Notion library groups summaries without duplicating Ano', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final library = NotionLibraryData(
      subjects: {_subject.notionId: _subject},
      summaries: [
        NotionSummaryRecord(
          id: 'summary-1',
          title: 'Process scheduling',
          date: DateTime(2026, 9, 6),
          subjectIds: const ['subject-1'],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(database, const LibraryScreen(), library: library),
    );
    await tester.pumpAndSettle();

    expect(find.text('3º Ano · 1º Semestre'), findsOneWidget);
    expect(find.text('Process scheduling'), findsOneWidget);
    await tester.tap(find.text('Operating Systems'));
    await tester.pumpAndSettle();
    expect(find.text('Process scheduling'), findsNothing);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('library detail exposes previous and next lecture navigation', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final library = NotionLibraryData(
      subjects: {_subject.notionId: _subject},
      summaries: [
        NotionSummaryRecord(
          id: 'older',
          title: 'Older lecture',
          date: DateTime(2026, 9, 1),
          subjectIds: const ['subject-1'],
        ),
        NotionSummaryRecord(
          id: 'newer',
          title: 'Newer lecture',
          date: DateTime(2026, 9, 2),
          subjectIds: const ['subject-1'],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        database,
        const LibraryDetailScreen(pageId: 'older', title: 'Older lecture'),
        library: library,
        notionBlocks: const [],
      ),
    );
    await tester.pumpAndSettle();

    final previous = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Previous'),
    );
    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 900);
  addTearDown(tester.view.reset);
}

Future<void> _saveTimetable(ClassSyncDatabase database) async {
  final monday = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday - DateTime.monday),
  );
  final start = DateTime(monday.year, monday.month, monday.day, 9, 10);
  final slots = [
    for (final weekOffset in [0, 7])
      TimetableSlot(
        externalId: 'slot-live-format-$weekOffset',
        subjectCode: 'SO',
        subjectName: 'Operating Systems',
        subjectId: _subject.notionId,
        start: start.add(Duration(days: weekOffset)),
        end: start.add(Duration(days: weekOffset, hours: 1, minutes: 50)),
        className: '3DA',
        lessonType: 'TP',
        room: 'B301',
        lecturer: 'Jane Teacher',
      ),
  ];
  for (final slot in slots) {
    await database.upsertAcademicRecord(
      AcademicRecord(
        key: AcademicRecord.keyFor(
          AcademicSource.portal,
          AcademicRecordKind.timetable,
          slot.externalId,
        ),
        source: AcademicSource.portal,
        kind: AcademicRecordKind.timetable,
        externalId: slot.externalId,
        title: slot.subjectName,
        subjectId: slot.subjectId,
        startsAt: slot.start,
        endsAt: slot.end,
        payload: slot.toJson(),
        syncedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

Future<void> _saveGrade(
  ClassSyncDatabase database,
  GradeComponent grade,
  AcademicRecordKind kind,
) => database.upsertAcademicRecord(
  AcademicRecord(
    key: AcademicRecord.keyFor(AcademicSource.portal, kind, grade.externalId),
    source: AcademicSource.portal,
    kind: kind,
    externalId: grade.externalId,
    title: '${grade.subjectName} · ${grade.name}',
    subjectId: grade.subjectId,
    payload: grade.toJson(),
    syncedAt: DateTime.now().toUtc(),
  ),
);

Widget _app(
  ClassSyncDatabase database,
  Widget screen, {
  List<AcademicSubject> subjects = const [],
  SecureCredentialStore? credentialStore,
  TargetPlatform? platform,
  NotionLibraryData? library,
  List<NotionContentBlock>? notionBlocks,
  List<NotionSummaryRecord>? subjectSummaries,
  AppSettings settings = AppSettings.defaults,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    credentialStoreProvider.overrideWithValue(
      credentialStore ?? _ImmediateCredentialStore(),
    ),
    activeSubjectsProvider.overrideWith(
      (ref) => Stream<List<AcademicSubject>>.value(subjects),
    ),
    subjectsProvider.overrideWith(
      (ref) => Stream<List<AcademicSubject>>.value(subjects),
    ),
    syncJobsProvider.overrideWith(
      (ref) => Stream<List<SyncJob>>.value(const <SyncJob>[]),
    ),
    settingsProvider.overrideWith((ref) => Stream<AppSettings>.value(settings)),
    if (library != null)
      notionLibraryProvider.overrideWith((ref) async => library),
    if (notionBlocks != null)
      notionPageContentProvider.overrideWith(
        (ref, pageId) async => notionBlocks,
      ),
    notionSubjectSummariesProvider.overrideWith(
      (ref, subjectId) async => subjectSummaries ?? const [],
    ),
  ],
  child: MaterialApp(
    theme: ClassSyncTheme.light().copyWith(platform: platform),
    home: Scaffold(body: screen),
  ),
);

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

final _subject = AcademicSubject(
  notionId: 'subject-1',
  name: 'Operating Systems',
  year: '3º',
  semester: '1º Semestre',
  status: 'In progress',
  lastSyncedAt: DateTime.utc(2026, 9, 5),
);

AcademicSubject _copySubject({
  required String id,
  required String name,
  required String status,
}) => AcademicSubject(
  notionId: id,
  name: name,
  year: '3º',
  semester: '1º Semestre',
  status: status,
  lastSyncedAt: DateTime.utc(2026, 9, 5),
);

class _ImmediateCredentialStore extends SecureCredentialStore {
  @override
  Future<List<FirefliesConnection>> readFirefliesConnections() async =>
      const [];

  @override
  Future<bool> isConfigured(CredentialKey key) async => false;
}

class _PortalCredentialStore extends _ImmediateCredentialStore {
  @override
  Future<bool> isConfigured(CredentialKey key) async =>
      key == CredentialKey.portalUsername ||
      key == CredentialKey.portalPassword;
}

class _ControlledCredentialStore extends SecureCredentialStore {
  final _completers = {
    for (final key in CredentialKey.values) key: Completer<bool>(),
  };

  @override
  Future<bool> isConfigured(CredentialKey key) => _completers[key]!.future;

  @override
  Future<List<FirefliesConnection>> readFirefliesConnections() async =>
      await _completers[CredentialKey.firefliesApiKey]!.future
      ? const [
          FirefliesConnection(id: 'primary', name: 'Primary', apiKey: 'key'),
        ]
      : const [];

  void complete(CredentialKey key, bool value) {
    _completers[key]!.complete(value);
  }
}

class _NamedCredentialStore extends SecureCredentialStore {
  @override
  Future<String?> read(CredentialKey key) async => null;

  @override
  Future<List<FirefliesConnection>> readFirefliesConnections() async => const [
    FirefliesConnection(id: 'mine', name: 'Hugo', apiKey: 'mine-key'),
    FirefliesConnection(id: 'ana', name: 'Ana', apiKey: 'ana-key'),
  ];

  @override
  Future<bool> isConfigured(CredentialKey key) async => false;
}
