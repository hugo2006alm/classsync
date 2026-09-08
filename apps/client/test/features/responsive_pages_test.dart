import 'dart:async';

import 'package:classsync/app/theme/classsync_theme.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/providers.dart';
import 'package:classsync/core/integrations/notion/notion_client.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
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
    expect(find.text('Evaluations'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Course context'), findsOneWidget);
    expect(find.text('Search & ask'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
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

  testWidgets('equal Gemini model values have unique settings field keys', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(_app(database, const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI & summaries'));
    await tester.pumpAndSettle();
    expect(find.text('AI'), findsOneWidget);
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
    expect(find.text('Checking secure storage…'), findsNWidgets(4));
    credentials.complete(CredentialKey.firefliesApiKey, false);
    credentials.complete(CredentialKey.geminiApiKey, true);
    credentials.complete(CredentialKey.notionToken, true);
    credentials.complete(CredentialKey.relayDeviceToken, false);
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsNWidgets(2));
    expect(find.text('Not configured'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('Fireflies settings identify every named connection', (
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

    expect(find.text('2 connected'), findsOneWidget);
    expect(find.text('Hugo · Ana'), findsOneWidget);
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
  Future<List<FirefliesConnection>> readFirefliesConnections() async => const [
    FirefliesConnection(id: 'mine', name: 'Hugo', apiKey: 'mine-key'),
    FirefliesConnection(id: 'ana', name: 'Ana', apiKey: 'ana-key'),
  ];

  @override
  Future<bool> isConfigured(CredentialKey key) async => false;
}
