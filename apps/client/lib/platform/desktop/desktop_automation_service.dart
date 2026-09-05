import 'dart:async';
import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/database/classsync_database.dart';
import '../../core/providers.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/sync/sync_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopAutomationService with TrayListener, WindowListener {
  DesktopAutomationService({
    required ProviderContainer container,
    required ClassSyncDatabase database,
  }) : _container = container,
       _database = database;

  final ProviderContainer _container;
  final ClassSyncDatabase _database;
  StreamSubscription<List<SyncJob>>? _jobsSubscription;
  StreamSubscription<AppSettings>? _settingsSubscription;
  Timer? _timer;
  List<SyncJob> _jobs = const [];
  AppSettings _settings = AppSettings.defaults;

  Future<void> initialize() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    final executableDirectory = path.dirname(Platform.resolvedExecutable);
    final iconPath = path.join(
      executableDirectory,
      'data',
      'flutter_assets',
      'assets',
      'app_icon.ico',
    );
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('ClassSync');
    _jobsSubscription = _database.watchJobs().listen((jobs) {
      _jobs = jobs;
      _updateMenu();
    });
    _settingsSubscription = _database.watchSettings().listen((settings) {
      _settings = settings;
      _configureAutostart(settings);
      _configureTimer(settings);
      _updateMenu();
    });
    await windowManager.setPreventClose(true);
    await _updateMenu();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _jobsSubscription?.cancel();
    await _settingsSubscription?.cancel();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  Future<void> _updateMenu() async {
    final pending = _jobs.where((job) => !job.status.isTerminal).length;
    final lastSync = await _database.readCursor('fireflies');
    final lastLabel = lastSync == null
        ? 'Last sync: never'
        : 'Last sync: ${lastSync.toLocal().hour.toString().padLeft(2, '0')}:${lastSync.toLocal().minute.toString().padLeft(2, '0')}';
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'open', label: 'Open ClassSync'),
          MenuItem(key: 'sync', label: 'Sync now'),
          MenuItem(
            key: 'pause',
            label: _settings.automaticSync
                ? 'Pause automation'
                : 'Resume automation',
          ),
          MenuItem.separator(),
          MenuItem(key: 'last_sync', label: lastLabel, disabled: true),
          MenuItem(key: 'pending', label: 'Pending: $pending', disabled: true),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  Future<void> _configureAutostart(AppSettings settings) async {
    final info = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: 'ClassSync',
      appPath: Platform.resolvedExecutable,
      packageName: info.packageName,
      args: const ['--background'],
    );
    final enabled = await launchAtStartup.isEnabled();
    if (settings.launchWithWindows && !enabled) await launchAtStartup.enable();
    if (!settings.launchWithWindows && enabled) await launchAtStartup.disable();
  }

  void _configureTimer(AppSettings settings) {
    _timer?.cancel();
    if (!settings.automaticSync) return;
    _timer = Timer.periodic(Duration(minutes: settings.pollingMinutes), (_) {
      _container
          .read(syncControllerProvider.notifier)
          .run(SyncReason.periodicPoll);
    });
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.setSkipTaskbar(false);
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        _showWindow();
      case 'sync':
        _container.read(syncControllerProvider.notifier).run(SyncReason.manual);
      case 'pause':
        _database.saveSettings(
          _settings.copyWith(automaticSync: !_settings.automaticSync),
        );
      case 'quit':
        _quit();
    }
  }

  Future<void> _quit() async {
    await dispose();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}
