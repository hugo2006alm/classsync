import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../domain/sync/sync_notifier.dart';

class ClassSyncNotificationService implements SyncNotifier {
  ClassSyncNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize({void Function(String jobId)? onOpenJob}) async {
    timezone_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      windows: WindowsInitializationSettings(
        appName: 'ClassSync',
        appUserModelId: 'ClassSync.University.Manager.1',
        guid: 'd8f2aa91-f4cc-4ba1-96a1-14790667be0c',
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onOpenJob?.call(payload);
      },
    );
  }

  Future<void> scheduleAcademicReminder({
    required String id,
    required String title,
    required DateTime scheduledAt,
  }) => _plugin.zonedSchedule(
    id: _stableNotificationId(id),
    title: 'ClassSync academic reminder',
    body: title,
    scheduledDate: timezone.TZDateTime.from(scheduledAt.toUtc(), timezone.UTC),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'classsync_academic',
        'Academic deadlines',
        channelDescription: 'User-controlled exam and assignment reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: 'academic:$id',
  );

  Future<void> cancelAcademicReminder(String id) =>
      _plugin.cancel(id: _stableNotificationId(id));

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: false);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: false);
  }

  @override
  Future<void> success(String jobId, String subjectName) => _plugin.show(
    id: jobId.hashCode,
    title: 'ClassSync',
    body: 'Resumo de $subjectName sincronizado.',
    payload: jobId,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'classsync_success',
        'Synced summaries',
        channelDescription: 'Silent ClassSync success notifications',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
      ),
      iOS: DarwinNotificationDetails(presentSound: false),
      macOS: DarwinNotificationDetails(presentSound: false),
      windows: WindowsNotificationDetails(),
    ),
  );

  @override
  Future<void> needsReview(String jobId) => _plugin.show(
    id: jobId.hashCode,
    title: 'ClassSync',
    body: 'Preciso de confirmar a cadeira desta aula.',
    payload: jobId,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'classsync_attention',
        'ClassSync attention',
        channelDescription: 'Class reviews and failures',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    ),
  );

  @override
  Future<void> failure(String jobId, String message) => _plugin.show(
    id: jobId.hashCode,
    title: 'ClassSync',
    body: message,
    payload: jobId,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'classsync_attention',
        'ClassSync attention',
        channelDescription: 'Class reviews and failures',
        importance: Importance.defaultImportance,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    ),
  );
}

int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
