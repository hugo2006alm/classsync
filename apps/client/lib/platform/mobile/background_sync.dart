import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/database/classsync_database.dart';
import '../../core/providers.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/sync/sync_models.dart';
import 'mobile_background_policy.dart';

const _taskName = 'classsync.periodicSync';

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
      if (settings.notificationsEnabled) {
        await container.read(notificationServiceProvider).initialize();
      }
      Future<void> synchronizeAccountState() async {
        try {
          await container.read(deviceSyncServiceProvider).synchronize();
        } catch (_) {
          // Account sync is an accelerator; the durable lecture queue remains local-first.
        }
      }

      await synchronizeAccountState();
      await container
          .read(syncCoordinatorProvider)
          .run(
            task == mobilePushTaskName
                ? SyncReason.firefliesWebhook
                : SyncReason.mobileBackground,
            onQueueCheckpoint: synchronizeAccountState,
          );
      await synchronizeAccountState();
      return true;
    } catch (_) {
      return false;
    } finally {
      container.dispose();
      await database.close();
    }
  });
}

Future<void> enqueueMobileSyncFromPush({
  String? eventId,
  String? messageId,
}) async {
  if (!Platform.isAndroid) return;
  await Workmanager().registerOneOffTask(
    mobilePushUniqueWorkName(eventId: eventId, messageId: messageId),
    mobilePushTaskName,
    inputData: {
      if (eventId?.isNotEmpty == true) 'eventId': eventId!,
      if (messageId?.isNotEmpty == true) 'messageId': messageId!,
    },
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 10),
    expedited: true,
    outOfQuotaPolicy: OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
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
