import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:window_manager/window_manager.dart';

import 'app/classsync_app.dart';
import 'app/router/app_router.dart';
import 'core/database/classsync_database.dart';
import 'core/providers.dart';
import 'domain/sync/sync_models.dart';
import 'platform/desktop/desktop_automation_service.dart';
import 'platform/desktop/single_instance_service.dart';
import 'platform/mobile/background_sync.dart';
import 'platform/mobile/firebase_push_service.dart';
import 'platform/mobile/next_class_widget.dart';
import 'firebase_options.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!SingleInstanceService.acquire()) return;
  if (Platform.isAndroid) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
    FirebaseMessaging.onBackgroundMessage(classSyncFirebaseBackgroundHandler);
  }
  final database = ClassSyncDatabase();
  await database.initialize();
  if (Platform.isAndroid) NextClassWidget.observe(database);
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(database)],
  );

  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(720, 600),
      center: true,
      title: 'ClassSync',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (arguments.contains('--background')) {
        await windowManager.hide();
        await windowManager.setSkipTaskbar(true);
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
    final desktop = DesktopAutomationService(
      container: container,
      database: database,
    );
    await desktop.initialize();
  }

  final notifications = container.read(notificationServiceProvider);
  final router = container.read(routerProvider);
  await notifications.initialize(
    onOpenJob: (payload) {
      if (payload.startsWith('academic:')) {
        final parts = payload.split(':');
        final section = parts.length >= 3 ? parts[1] : '0';
        final record = parts.length >= 3
            ? parts.skip(2).join(':')
            : parts.skip(1).join(':');
        router.go(
          '/academic?section=${Uri.encodeQueryComponent(section)}&record=${Uri.encodeQueryComponent(record)}',
        );
      } else {
        router.go('/sync/${Uri.encodeComponent(payload)}');
      }
    },
  );
  final settings = await database.readSettings();
  await container.read(academicSyncServiceProvider).repairPortalCache();
  await configureMobileBackgroundSync(settings);
  if (Platform.isAndroid) {
    await FirebasePushService(
      database: database,
      credentials: container.read(credentialStoreProvider),
      relay: container.read(relayClientProvider),
      onEvent: () => container
          .read(syncControllerProvider.notifier)
          .run(SyncReason.firefliesWebhook),
    ).initialize();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ClassSyncApp(),
    ),
  );

  if (settings.setupComplete &&
      settings.automaticSync &&
      settings.syncOnLaunch) {
    Future<void>.delayed(const Duration(seconds: 2), () {
      container
          .read(syncControllerProvider.notifier)
          .run(
            Platform.isWindows
                ? SyncReason.desktopStartup
                : SyncReason.appResume,
          );
    });
  }
}
