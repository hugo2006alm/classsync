import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../domain/sync/sync_models.dart';
import '../features/setup/setup_wizard.dart';
import 'router/app_router.dart';
import 'theme/classsync_theme.dart';

class ClassSyncApp extends ConsumerStatefulWidget {
  const ClassSyncApp({super.key});

  @override
  ConsumerState<ClassSyncApp> createState() => _ClassSyncAppState();
}

class _ClassSyncAppState extends ConsumerState<ClassSyncApp>
    with WidgetsBindingObserver {
  DateTime? _lastResumeSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (_lastResumeSync != null &&
        now.difference(_lastResumeSync!) < const Duration(seconds: 30)) {
      return;
    }
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null ||
        !settings.setupComplete ||
        !settings.automaticSync) {
      return;
    }
    _lastResumeSync = now;
    unawaited(
      ref.read(syncControllerProvider.notifier).run(SyncReason.appResume),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return settings.when(
      loading: () => _materialApp(const _LaunchScreen()),
      error: (error, stack) => _materialApp(_BootstrapError(error: error)),
      data: (value) {
        if (!value.setupComplete) return _materialApp(const SetupWizard());
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'ClassSync',
          theme: ClassSyncTheme.light(),
          darkTheme: ClassSyncTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: ref.watch(routerProvider),
        );
      },
    );
  }

  MaterialApp _materialApp(Widget home) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ClassSync',
    theme: ClassSyncTheme.light(),
    darkTheme: ClassSyncTheme.dark(),
    themeMode: ThemeMode.system,
    home: home,
  );
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Semantics(
        label: 'ClassSync is starting',
        child: const CircularProgressIndicator(),
      ),
    ),
  );
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 16),
              Text(
                'ClassSync could not open its local database.',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
