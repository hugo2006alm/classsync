import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/database/classsync_database.dart';
import '../../core/providers.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/sync/sync_models.dart';

const _taskName = 'classsync.periodicSync';
const _pushTaskName = 'classsync.pushSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    final database = ClassSyncDatabase();
    await database.initialize();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    try {
      final settings = await database.readSettings();
      if (!settings.setupComplete ||
          !settings.automaticSync ||
          !settings.backgroundMobileSync) {
        return true;
      }
      await container
          .read(syncCoordinatorProvider)
          .run(
            task == _pushTaskName
                ? SyncReason.firefliesWebhook
                : SyncReason.mobileBackground,
          );
      return true;
    } catch (_) {
      return false;
    } finally {
      container.dispose();
      await database.close();
    }
  });
}

Future<void> enqueueMobileSyncFromPush() async {
  if (!Platform.isAndroid) return;
  await Workmanager().registerOneOffTask(
    _pushTaskName,
    _pushTaskName,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 10),
  );
}

Future<void> configureMobileBackgroundSync(AppSettings settings) async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(callbackDispatcher);
  if (!settings.automaticSync || !settings.backgroundMobileSync) {
    await Workmanager().cancelByUniqueName(_taskName);
    return;
  }
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    frequency: Duration(minutes: settings.pollingMinutes.clamp(15, 1440)),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 10),
  );
}
