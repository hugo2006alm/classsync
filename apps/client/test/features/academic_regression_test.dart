import 'package:classsync/app/theme/classsync_theme.dart';
import 'package:classsync/core/database/classsync_database.dart';
import 'package:classsync/core/providers.dart';
import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/features/academic/academic_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/academic_qa.dart';

class _NoCredentials extends SecureCredentialStore {
  @override
  Future<String?> read(CredentialKey key) async => null;
}

void main() {
  for (final width in [400.0, 1280.0]) {
    testWidgets(
      'Finance, Progress and local search reject old cache noise at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = ClassSyncDatabase(NativeDatabase.memory());
        await db.initialize();
        await seedAcademicQa(db);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              credentialStoreProvider.overrideWithValue(_NoCredentials()),
              academicConnectionStateProvider.overrideWith(
                (ref) async => const AcademicConnectionState(
                  portalConfigured: true,
                  moodleConfigured: false,
                ),
              ),
            ],
            child: MaterialApp(
              theme: ClassSyncTheme.dark(),
              home: const Scaffold(body: AcademicScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await verifyAcademicTabs(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
      },
    );
  }
}
