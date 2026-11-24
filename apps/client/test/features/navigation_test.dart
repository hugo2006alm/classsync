import 'package:classsync/app/router/app_router.dart';
import 'package:classsync/app/theme/classsync_theme.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/providers.dart';
import 'package:classsync/domain/academic/academic_models.dart';
import 'package:classsync/domain/settings/app_settings.dart';
import 'package:classsync/domain/sync/sync_models.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a page ID alone opens Library and back returns to recording', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 850);
    addTearDown(tester.view.reset);
    final database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
    addTearDown(database.close);
    final now = DateTime.utc(2026);
    final job = SyncJob(
      id: 'duplicate',
      firefliesId: 'transcript',
      title: 'Recorded lecture',
      meetingDate: now,
      status: SyncJobStatus.duplicate,
      sourceType: 'fireflies',
      attemptCount: 0,
      discoveredAt: now,
      updatedAt: now,
      notionPageId: 'page-id',
      summaryTitle: 'Canonical lecture notes',
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        syncJobProvider(job.id).overrideWith((ref) => Stream.value(job)),
        jobTimelineProvider(job.id).overrideWith((ref) => Stream.value([])),
        activeSubjectsProvider.overrideWith((ref) => Stream.value([])),
        firefliesConnectionsProvider.overrideWith((ref) async => []),
        notionPageContentProvider('page-id').overrideWith((ref) async => []),
        notionLibraryProvider.overrideWith(
          (ref) async => throw StateError('Offline'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider)..go('/sync/duplicate');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read in Library'));
    await tester.pumpAndSettle();
    expect(find.text('Canonical lecture notes'), findsOneWidget);
    expect(find.text('This Notion page has no content yet.'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Read in Library'), findsOneWidget);
    expect(find.text('Open in Notion'), findsNothing);
  });

  testWidgets('main navigation closes an open settings detail page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 820);
    addTearDown(tester.view.reset);
    final database = ClassSyncDatabase(NativeDatabase.memory());
    await database.initialize();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        settingsProvider.overrideWith(
          (ref) =>
              Stream.value(AppSettings.defaults.copyWith(setupComplete: true)),
        ),
        activeSubjectsProvider.overrideWith(
          (ref) => Stream<List<AcademicSubject>>.value(const []),
        ),
        syncJobsProvider.overrideWith(
          (ref) => Stream<List<SyncJob>>.value(const []),
        ),
        syncAccountProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider)..go('/settings');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ClassSyncTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account & device sync'));
    await tester.pumpAndSettle();
    expect(find.text('No ClassSync account'), findsOneWidget);

    await tester.tap(find.text('Overview').first);
    await tester.pumpAndSettle();

    expect(find.text('No ClassSync account'), findsNothing);
    expect(find.textContaining('Good '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
