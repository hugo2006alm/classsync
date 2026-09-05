import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/logging/redactor.dart';
import '../../core/providers.dart';
import '../../core/security/secure_credential_store.dart';
import '../../domain/settings/app_settings.dart';
import '../../platform/mobile/background_sync.dart';
import '../shared/page_frame.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsValue = ref.watch(settingsProvider);
    return PageFrame(
      title: 'Settings',
      subtitle: 'Integrations, automation, AI, storage, and diagnostics',
      child: settingsValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (settings) => _SettingsBody(settings: settings),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SettingsSection(
        title: 'Integrations',
        description: 'Secrets remain in OS secure storage.',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 850
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _IntegrationTile(
                    name: 'Fireflies',
                    icon: Icons.mic_none_rounded,
                    credential: CredentialKey.firefliesApiKey,
                    onConfigure: () => _configureSecret(
                      context,
                      ref,
                      name: 'Fireflies',
                      key: CredentialKey.firefliesApiKey,
                      tester: (value) => ref
                          .read(firefliesClientProvider)
                          .testConnection(value),
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _IntegrationTile(
                    name: 'Gemini',
                    icon: Icons.auto_awesome_rounded,
                    credential: CredentialKey.geminiApiKey,
                    onConfigure: () => _configureSecret(
                      context,
                      ref,
                      name: 'Gemini',
                      key: CredentialKey.geminiApiKey,
                      tester: (value) => ref
                          .read(geminiClientProvider)
                          .testConnection(
                            apiKey: value,
                            model: settings.classificationModel,
                          ),
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _IntegrationTile(
                    name: 'Notion',
                    icon: Icons.account_tree_outlined,
                    credential: CredentialKey.notionToken,
                    onConfigure: () => _configureSecret(
                      context,
                      ref,
                      name: 'Notion',
                      key: CredentialKey.notionToken,
                      tester: (value) =>
                          ref.read(notionClientProvider).testConnection(value),
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _IntegrationTile(
                    name: 'ClassSync Relay',
                    icon: Icons.cloud_queue_rounded,
                    credential: CredentialKey.relayDeviceToken,
                    onConfigure: () => _configureRelay(context, ref, settings),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 28),
      _SettingsSection(
        title: 'Automation',
        child: Card(
          child: Column(
            children: [
              _SettingSwitch(
                title: 'Automatic sync',
                subtitle: 'Process discovered lectures without interaction.',
                value: settings.automaticSync,
                onChanged: (value) =>
                    _save(ref, settings.copyWith(automaticSync: value)),
              ),
              const Divider(),
              _SettingSwitch(
                title: 'Launch with Windows',
                subtitle: 'Start hidden in the tray after login.',
                value: settings.launchWithWindows,
                onChanged: (value) =>
                    _save(ref, settings.copyWith(launchWithWindows: value)),
              ),
              const Divider(),
              _SettingSwitch(
                title: 'Sync on app launch',
                subtitle:
                    'Run relay and Fireflies recovery discovery after startup.',
                value: settings.syncOnLaunch,
                onChanged: (value) =>
                    _save(ref, settings.copyWith(syncOnLaunch: value)),
              ),
              const Divider(),
              _SettingSwitch(
                title: 'Background mobile sync',
                subtitle: 'Best-effort Android processing via WorkManager.',
                value: settings.backgroundMobileSync,
                onChanged: (value) =>
                    _save(ref, settings.copyWith(backgroundMobileSync: value)),
              ),
              const Divider(),
              _SettingSwitch(
                title: 'Notifications',
                subtitle: 'Silent success; visible reviews and failures.',
                value: settings.notificationsEnabled,
                onChanged: (value) async {
                  if (value) {
                    await ref
                        .read(notificationServiceProvider)
                        .requestPermissions();
                  }
                  await _save(
                    ref,
                    settings.copyWith(notificationsEnabled: value),
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Recovery polling interval'),
                subtitle: const Text('Webhook loss stays harmless.'),
                trailing: DropdownButton<int>(
                  value: settings.pollingMinutes,
                  items: const [15, 30, 60, 120]
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes min'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _save(ref, settings.copyWith(pollingMinutes: value));
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Recovery overlap'),
                subtitle: const Text(
                  'Re-query this window to recover lost webhooks.',
                ),
                trailing: DropdownButton<int>(
                  value: settings.overlapHours,
                  items: const [12, 24, 48, 72]
                      .map(
                        (hours) => DropdownMenuItem(
                          value: hours,
                          child: Text('$hours h'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _save(ref, settings.copyWith(overlapHours: value));
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Concurrent lecture jobs'),
                subtitle: const Text('Keep this conservative for API limits.'),
                trailing: DropdownButton<int>(
                  value: settings.workerCount,
                  items: const [1, 2]
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _save(ref, settings.copyWith(workerCount: value));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 28),
      _SettingsSection(
        title: 'AI',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                TextFormField(
                  key: ValueKey(settings.classificationModel),
                  initialValue: settings.classificationModel,
                  decoration: const InputDecoration(
                    labelText: 'Classification model',
                  ),
                  onFieldSubmitted: (value) => _save(
                    ref,
                    settings.copyWith(classificationModel: value.trim()),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(settings.summaryLanguage),
                  initialValue: settings.summaryLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Summary language',
                  ),
                  onFieldSubmitted: (value) => _save(
                    ref,
                    settings.copyWith(summaryLanguage: value.trim()),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(settings.summaryModel),
                  initialValue: settings.summaryModel,
                  decoration: const InputDecoration(labelText: 'Summary model'),
                  onFieldSubmitted: (value) =>
                      _save(ref, settings.copyWith(summaryModel: value.trim())),
                ),
                const SizedBox(height: 18),
                _ThresholdSlider(
                  label: 'Automatic publish threshold',
                  value: settings.autoClassifyThreshold,
                  onChanged: (value) => _save(
                    ref,
                    settings.copyWith(autoClassifyThreshold: value),
                  ),
                ),
                _ThresholdSlider(
                  label: 'Review threshold',
                  value: settings.reviewThreshold,
                  onChanged: (value) =>
                      _save(ref, settings.copyWith(reviewThreshold: value)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Summary detail'),
                  trailing: DropdownButton<SummaryDetail>(
                    value: settings.summaryDetail,
                    items: SummaryDetail.values
                        .map(
                          (detail) => DropdownMenuItem(
                            value: detail,
                            child: Text(_capitalize(detail.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _save(ref, settings.copyWith(summaryDetail: value));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 28),
      _SettingsSection(
        title: 'Storage',
        child: Card(
          child: Column(
            children: [
              _SettingSwitch(
                title: 'Keep transcripts after success',
                subtitle: 'Off by default for privacy.',
                value: settings.keepTranscripts,
                onChanged: (value) =>
                    _save(ref, settings.copyWith(keepTranscripts: value)),
              ),
              const Divider(),
              ListTile(
                title: const Text('Diagnostics retention'),
                subtitle: const Text('Operational metadata only.'),
                trailing: DropdownButton<int>(
                  value: settings.diagnosticsRetentionDays,
                  items: const [7, 14, 30, 90]
                      .map(
                        (days) => DropdownMenuItem(
                          value: days,
                          child: Text('$days days'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _save(
                        ref,
                        settings.copyWith(diagnosticsRetentionDays: value),
                      );
                    }
                  },
                ),
              ),
              const Divider(),
              _SettingSwitch(
                title: 'Clean completed payloads',
                subtitle:
                    'Retain metadata and diagnostics, remove lecture content.',
                value: settings.cleanCompletedPayloads,
                onChanged: (value) => _save(
                  ref,
                  settings.copyWith(cleanCompletedPayloads: value),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 28),
      _Diagnostics(settings: settings),
    ],
  );

  Future<void> _save(WidgetRef ref, AppSettings value) async {
    await ref.read(settingsControllerProvider).save(value);
    await configureMobileBackgroundSync(value);
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.description,
  });
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (description != null) ...[
        const SizedBox(height: 4),
        Text(description!, style: Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _IntegrationTile extends ConsumerWidget {
  const _IntegrationTile({
    required this.name,
    required this.icon,
    required this.credential,
    required this.onConfigure,
  });
  final String name;
  final IconData icon;
  final CredentialKey credential;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                FutureBuilder<bool>(
                  future: ref
                      .read(credentialStoreProvider)
                      .isConfigured(credential),
                  builder: (context, snapshot) => Text(
                    snapshot.data == true ? 'Connected' : 'Not configured',
                    style: TextStyle(
                      color: snapshot.data == true
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onConfigure,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Configure $name',
          ),
        ],
      ),
    ),
  );
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text('${(value * 100).round()}% heuristic'),
        ],
      ),
      Slider(
        value: value,
        min: 0.5,
        max: 1,
        divisions: 10,
        label: '${(value * 100).round()}%',
        onChanged: onChanged,
      ),
    ],
  );
}

class _Diagnostics extends ConsumerWidget {
  const _Diagnostics({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(syncJobsProvider).valueOrNull ?? const [];
    return _SettingsSection(
      title: 'Diagnostics',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _DiagnosticRow('Database', 'Ready'),
              _DiagnosticRow(
                'Queue size',
                '${jobs.where((job) => !job.status.isTerminal).length}',
              ),
              _DiagnosticRow(
                'Failed jobs',
                '${jobs.where((job) => job.lastErrorType != null).length}',
              ),
              _DiagnosticRow(
                'Relay',
                settings.relayBaseUrl == null ? 'Not configured' : 'Configured',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _exportDiagnostics(context, ref, settings, jobs.length),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export redacted diagnostics'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}

Future<void> _configureSecret(
  BuildContext context,
  WidgetRef ref, {
  required String name,
  required CredentialKey key,
  required Future<void> Function(String value) tester,
}) async {
  final controller = TextEditingController();
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Configure $name'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(labelText: '$name credential'),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    try {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      await tester(controller.text.trim());
                      await ref
                          .read(credentialStoreProvider)
                          .write(key, controller.text);
                      if (context.mounted) Navigator.pop(context);
                    } catch (failure) {
                      setState(() {
                        busy = false;
                        error = failure.toString();
                      });
                    }
                  },
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test and save'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

Future<void> _configureRelay(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) async {
  final urlController = TextEditingController(text: settings.relayBaseUrl);
  final tokenController = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Configure ClassSync Relay'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Relay base URL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Device token'),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(relayClientProvider)
                    .testConnection(urlController.text.trim());
                await ref
                    .read(credentialStoreProvider)
                    .write(
                      CredentialKey.relayDeviceToken,
                      tokenController.text,
                    );
                await ref
                    .read(settingsControllerProvider)
                    .save(
                      settings.copyWith(
                        relayBaseUrl: urlController.text.trim(),
                      ),
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (failure) {
                setState(() => error = failure.toString());
              }
            },
            child: const Text('Test and save'),
          ),
        ],
      ),
    ),
  );
  urlController.dispose();
  tokenController.dispose();
}

Future<void> _exportDiagnostics(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
  int queueEntries,
) async {
  final info = await PackageInfo.fromPlatform();
  final output = {
    'application': 'ClassSync',
    'version': info.version,
    'platform': Platform.operatingSystem,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'database': 'ready',
    'queueEntries': queueEntries,
    'pollingMinutes': settings.pollingMinutes,
    'overlapHours': settings.overlapHours,
    'relayConfigured': settings.relayBaseUrl != null,
    'notionSubjectsMapped': settings.notionSubjectsDataSourceId != null,
    'notionSummariesMapped': settings.notionSummariesDataSourceId != null,
  };
  final path = await FilePicker.saveFile(
    dialogTitle: 'Export ClassSync diagnostics',
    fileName: 'classsync-diagnostics.json',
  );
  if (path == null) return;
  await File(path).writeAsString(
    SecretRedactor.redact(const JsonEncoder.withIndent('  ').convert(output)),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Redacted diagnostics exported.')),
    );
  }
}

String _capitalize(String value) =>
    '${value[0].toUpperCase()}${value.substring(1)}';
