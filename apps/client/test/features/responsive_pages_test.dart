import 'package:classsync/app/theme/classsync_theme.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/providers.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:classsync/domain/settings/app_settings.dart';
import 'package:classsync/domain/sync/sync_models.dart';
import 'package:classsync/features/classes/class_detail_screen.dart';
import 'package:classsync/features/overview/overview_screen.dart';
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

    expect(find.text('AI'), findsOneWidget);
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
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    activeSubjectsProvider.overrideWith(
      (ref) => Stream<List<AcademicSubject>>.value(subjects),
    ),
    syncJobsProvider.overrideWith(
      (ref) => Stream<List<SyncJob>>.value(const <SyncJob>[]),
    ),
    settingsProvider.overrideWith(
      (ref) => Stream<AppSettings>.value(AppSettings.defaults),
    ),
  ],
  child: MaterialApp(
    theme: ClassSyncTheme.light(),
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
