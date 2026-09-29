import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/updates/update_prompt.dart';
import '../domain/settings/app_settings.dart';
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
  DateTime? _lastUpdateCheck;
  bool _modelPromptOpen = false;

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
    _scheduleUpdateCheck();
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
    ref.listen<ModelRetryPrompt?>(modelRetryPromptProvider, (previous, next) {
      if (next == null || _modelPromptOpen) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_handleModelRetryPrompt(next));
      });
    });
    final settings = ref.watch(settingsProvider);
    return settings.when(
      loading: () => _materialApp(const _LaunchScreen()),
      error: (error, stack) => _materialApp(_BootstrapError(error: error)),
      data: (value) {
        if (!value.setupComplete) return _materialApp(const SetupWizard());
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scheduleUpdateCheck(),
        );
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

  void _scheduleUpdateCheck() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastUpdateCheck != null &&
        now.difference(_lastUpdateCheck!) < const Duration(hours: 24)) {
      return;
    }
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    _lastUpdateCheck = now;
    unawaited(
      checkForUpdates(
        context,
        credentials: ref.read(credentialStoreProvider),
        silent: true,
      ),
    );
  }

  Future<void> _handleModelRetryPrompt(ModelRetryPrompt prompt) async {
    if (!mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _clearModelPrompt(prompt);
      return;
    }
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) {
      _clearModelPrompt(prompt);
      return;
    }
    _modelPromptOpen = true;
    try {
      final selectedModel = await _showModelRetryDialog(dialogContext, prompt);
      _clearModelPrompt(prompt);
      if (selectedModel == null || !mounted) return;
      final settings = await ref.read(settingsProvider.future);
      final updated = prompt.operation == GeminiOperation.classification
          ? settings.copyWith(classificationModel: selectedModel)
          : settings.copyWith(summaryModel: selectedModel);
      await ref.read(settingsControllerProvider).save(updated);
      await ref.read(syncCoordinatorProvider).retryJob(prompt.jobId);
      if (mounted) {
        ref.read(routerProvider).go('/sync/${prompt.jobId}');
      }
    } catch (error) {
      final currentContext = rootNavigatorKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(
          currentContext,
        ).showSnackBar(SnackBar(content: Text('Retry failed: $error')));
      }
    } finally {
      _modelPromptOpen = false;
    }
  }

  void _clearModelPrompt(ModelRetryPrompt prompt) {
    if (ref.read(modelRetryPromptProvider) == prompt) {
      ref.read(modelRetryPromptProvider.notifier).state = null;
    }
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

Future<String?> _showModelRetryDialog(
  BuildContext context,
  ModelRetryPrompt prompt,
) {
  var selectedModel = _nextGeminiModel(prompt.currentModel);
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final selected = geminiTextModels.firstWhere(
          (model) => model.id == selectedModel,
        );
        final operation = prompt.operation == GeminiOperation.classification
            ? 'class identification'
            : 'summary generation';
        return AlertDialog(
          title: const Text('Try another Gemini model?'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$operation failed ${prompt.attemptCount} times. '
                  'Current model: ${geminiModelLabel(prompt.currentModel)}.',
                ),
                const SizedBox(height: 8),
                Text(prompt.message),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: selectedModel,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Retry model'),
                  items: geminiTextModels
                      .map(
                        (model) => DropdownMenuItem(
                          value: model.id,
                          child: Text(model.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedModel = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  selected.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                prompt.retryScheduled
                    ? 'Keep scheduled retry'
                    : 'Keep current model',
              ),
            ),
            FilledButton(
              onPressed: selectedModel == prompt.currentModel
                  ? null
                  : () => Navigator.pop(context, selectedModel),
              child: const Text('Switch and retry now'),
            ),
          ],
        );
      },
    ),
  );
}

String _nextGeminiModel(String current) {
  final index = geminiTextModels.indexWhere((model) => model.id == current);
  if (index >= 0 && index + 1 < geminiTextModels.length) {
    return geminiTextModels[index + 1].id;
  }
  return geminiTextModels.first.id;
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
