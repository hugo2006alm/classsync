import 'dart:async';

import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/integrations/fireflies/fireflies_client.dart';
import 'package:classsync/core/integrations/gemini/gemini_client.dart';
import 'package:classsync/core/integrations/notion/notion_client.dart';
import 'package:classsync/core/integrations/relay/relay_client.dart';
import 'package:classsync/core/providers.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/domain/sync/sync_coordinator.dart';
import 'package:classsync/features/sync/sync_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SlowImport extends SyncCoordinator {
  _SlowImport(ClassSyncDatabase db)
    : super(
        database: db,
        credentials: SecureCredentialStore(),
        fireflies: FirefliesClient(),
        gemini: GeminiClient(),
        notion: NotionClient(),
        relay: RelayClient(),
      );
  var calls = 0;
  final pending = Completer<String>();
  @override
  Future<String> importTranscript({
    required String title,
    required String transcriptText,
    DateTime? lectureDate,
  }) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'manual import validates empty input and blocks repeated submission',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = ClassSyncDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final coordinator = _SlowImport(db);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            syncCoordinatorProvider.overrideWithValue(coordinator),
          ],
          child: const MaterialApp(home: Scaffold(body: SyncScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import transcript'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Queue import'));
      await tester.pump();
      expect(find.text('Transcript cannot be empty.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Valid transcript');
      await tester.tap(find.text('Queue import'));
      await tester.pump();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Queue import'),
      );
      expect(button.onPressed, isNull);
      expect(coordinator.calls, 1);
      coordinator.pending.completeError(
        const FormatException('Import rejected'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Import rejected'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
