import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/redactor.dart';
import '../../core/providers.dart';
import '../../core/security/secure_credential_store.dart';
import '../../core/integrations/relay/account_sync_client.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/settings/fireflies_connection.dart';
import '../../domain/sync/sync_models.dart';
import '../../platform/mobile/background_sync.dart';
import '../shared/page_frame.dart';
import '../academic/academic_connections_dialog.dart';
import 'device_sync_settings.dart';

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

enum _SettingsCategory {
  connections,
  deviceSync,
  automation,
  ai,
  notion,
  storage,
  diagnostics,
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final destinations =
        <
          ({
            _SettingsCategory category,
            IconData icon,
            String title,
            String subtitle,
          })
        >[
          (
            category: _SettingsCategory.connections,
            icon: Icons.link_rounded,
            title: 'Connections',
            subtitle: 'Fireflies sources, Gemini, Notion, Portal, and Moodle',
          ),
          (
            category: _SettingsCategory.deviceSync,
            icon: Icons.devices_rounded,
            title: 'Account & device sync',
            subtitle: 'Private keys and lecture status across your devices',
          ),
          (
            category: _SettingsCategory.automation,
            icon: Icons.sync_rounded,
            title: 'Automation',
            subtitle: _automationSubtitle(Theme.of(context).platform),
          ),
          (
            category: _SettingsCategory.ai,
            icon: Icons.auto_awesome_rounded,
            title: 'AI & summaries',
            subtitle: 'Models, detail, language, and classification',
          ),
          (
            category: _SettingsCategory.notion,
            icon: Icons.account_tree_outlined,
            title: 'Notion workspace',
            subtitle: 'Database mappings and summary metadata',
          ),
          (
            category: _SettingsCategory.storage,
            icon: Icons.shield_outlined,
            title: 'Storage & privacy',
            subtitle: 'Transcript cleanup and local retention',
          ),
          (
            category: _SettingsCategory.diagnostics,
            icon: Icons.monitor_heart_outlined,
            title: 'Diagnostics',
            subtitle: 'Queue health and redacted export',
          ),
        ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < destinations.length; index++) ...[
            ListTile(
              minTileHeight: 72,
              leading: CircleAvatar(child: Icon(destinations[index].icon)),
              title: Text(destinations[index].title),
              subtitle: Text(destinations[index].subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _SettingsCategoryPage(
                    category: destinations[index].category,
                  ),
                ),
              ),
            ),
            if (index < destinations.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SettingsCategoryPage extends ConsumerWidget {
  const _SettingsCategoryPage({required this.category});
  final _SettingsCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsValue = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_categoryTitle(category))),
      body: SafeArea(
        child: settingsValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(error.toString())),
          data: (settings) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: _SettingsDetailBody(
                  settings: settings,
                  category: category,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _categoryTitle(_SettingsCategory category) => switch (category) {
  _SettingsCategory.connections => 'Connections',
  _SettingsCategory.deviceSync => 'Account & device sync',
  _SettingsCategory.automation => 'Automation',
  _SettingsCategory.ai => 'AI & summaries',
  _SettingsCategory.notion => 'Notion workspace',
  _SettingsCategory.storage => 'Storage & privacy',
  _SettingsCategory.diagnostics => 'Diagnostics',
};

String _automationSubtitle(TargetPlatform platform) => switch (platform) {
  TargetPlatform.windows => 'Windows startup, polling, and notifications',
  TargetPlatform.android => 'Background sync, polling, and notifications',
  _ => 'Startup sync, polling, and notifications',
};

class _SettingsDetailBody extends ConsumerWidget {
  const _SettingsDetailBody({required this.settings, required this.category});
  final AppSettings settings;
  final _SettingsCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (category == _SettingsCategory.connections) ...[
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
                    child: _FirefliesConnectionsTile(
                      onManage: () => _manageFirefliesConnections(context, ref),
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
                        tester: (value) async {
                          final selectedModel = await ref
                              .read(geminiClientProvider)
                              .testConnection(
                                apiKey: value,
                                model: settings.classificationModel,
                              );
                          if (selectedModel != settings.classificationModel) {
                            await ref
                                .read(settingsControllerProvider)
                                .save(
                                  settings.copyWith(
                                    classificationModel: selectedModel,
                                    summaryModel:
                                        settings.summaryModel ==
                                            settings.classificationModel
                                        ? selectedModel
                                        : settings.summaryModel,
                                  ),
                                );
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AcademicIntegrationTile(
                      name: 'ISEP Portal',
                      icon: Icons.account_balance_outlined,
                      source: _AcademicSource.portal,
                      onConfigure: () =>
                          showAcademicConnectionsDialog(context, ref),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AcademicIntegrationTile(
                      name: 'Moodle ISEP',
                      icon: Icons.school_outlined,
                      source: _AcademicSource.moodle,
                      onConfigure: () =>
                          showAcademicConnectionsDialog(context, ref),
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
                        tester: (value) => ref
                            .read(notionClientProvider)
                            .testConnection(value),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
      if (category == _SettingsCategory.deviceSync) ...[
        _SettingsSection(
          title: 'Your devices',
          description: 'One account per person. Join only devices you own.',
          child: DeviceSyncSettings(settings: settings),
        ),
      ],
      if (category == _SettingsCategory.automation) ...[
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
                if (Theme.of(context).platform == TargetPlatform.windows) ...[
                  _SettingSwitch(
                    title: 'Launch with Windows',
                    subtitle: 'Start hidden in the tray after login.',
                    value: settings.launchWithWindows,
                    onChanged: (value) =>
                        _save(ref, settings.copyWith(launchWithWindows: value)),
                  ),
                  const Divider(),
                ],
                _SettingSwitch(
                  title: 'Sync on app launch',
                  subtitle:
                      'Run relay and Fireflies recovery discovery after startup.',
                  value: settings.syncOnLaunch,
                  onChanged: (value) =>
                      _save(ref, settings.copyWith(syncOnLaunch: value)),
                ),
                const Divider(),
                if (Theme.of(context).platform == TargetPlatform.android) ...[
                  _SettingSwitch(
                    title: 'Background mobile sync',
                    subtitle: 'Best-effort Android processing via WorkManager.',
                    value: settings.backgroundMobileSync,
                    onChanged: (value) => _save(
                      ref,
                      settings.copyWith(backgroundMobileSync: value),
                    ),
                  ),
                  const Divider(),
                ],
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
                  subtitle: const Text(
                    'Keep this conservative for API limits.',
                  ),
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
      ],
      if (category == _SettingsCategory.ai) ...[
        _SettingsSection(
          title: 'AI',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _SettingSwitch(
                    title: 'Identify classes with AI automatically',
                    subtitle: settings.useAiClassification
                        ? 'Uses the lightweight model below, then asks for review when uncertain.'
                        : 'Always asks you to choose a class unless a saved correction matches.',
                    value: settings.useAiClassification,
                    onChanged: (value) => _save(
                      ref,
                      settings.copyWith(useAiClassification: value),
                    ),
                  ),
                  const Divider(),
                  _GeminiModelDropdown(
                    fieldKey: ValueKey(
                      'classification-model:${settings.classificationModel}',
                    ),
                    label: 'Class identification model',
                    currentModel: settings.classificationModel,
                    onChanged: (value) => _save(
                      ref,
                      settings.copyWith(classificationModel: value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey(
                      'summary-language:${settings.summaryLanguage}',
                    ),
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
                  _GeminiModelDropdown(
                    fieldKey: ValueKey(
                      'summary-model:${settings.summaryModel}',
                    ),
                    label: 'Summary model',
                    currentModel: settings.summaryModel,
                    onChanged: (value) =>
                        _save(ref, settings.copyWith(summaryModel: value)),
                  ),
                  const SizedBox(height: 18),
                  _ThresholdSlider(
                    label: 'Automatic publish threshold',
                    value: settings.autoClassifyThreshold,
                    onChanged: (value) => _save(
                      ref,
                      settings.copyWith(
                        autoClassifyThreshold: value,
                        reviewThreshold: settings.reviewThreshold > value
                            ? value
                            : settings.reviewThreshold,
                      ),
                    ),
                  ),
                  _ThresholdSlider(
                    label: 'Review threshold',
                    value: settings.reviewThreshold,
                    onChanged: (value) => _save(
                      ref,
                      settings.copyWith(
                        reviewThreshold: value > settings.autoClassifyThreshold
                            ? settings.autoClassifyThreshold
                            : value,
                      ),
                    ),
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
        const _Corrections(),
      ],
      if (category == _SettingsCategory.notion) ...[
        _NotionWorkspaceSettings(settings: settings),
      ],
      if (category == _SettingsCategory.storage) ...[
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
                const Divider(),
                ListTile(
                  title: const Text('Purge stored lecture content'),
                  subtitle: const Text(
                    'Remove transcripts, partial AI work, and local summaries. Metadata remains.',
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _confirmPurge(context, ref),
                    child: const Text('Purge'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      if (category == _SettingsCategory.diagnostics) ...[
        _Diagnostics(settings: settings),
      ],
    ],
  );

  Future<void> _save(WidgetRef ref, AppSettings value) async {
    await ref.read(settingsControllerProvider).save(value);
    await configureMobileBackgroundSync(value);
  }
}

class _NotionWorkspaceSettings extends ConsumerWidget {
  const _NotionWorkspaceSettings({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SettingsSection(
    title: 'Workspace mapping',
    description:
        'ClassSync writes only to the two data sources selected during setup.',
    child: Card(
      child: Column(
        children: [
          _MappingTile(
            title: 'Classes data source',
            value: settings.notionSubjectsDataSourceId,
          ),
          const Divider(height: 1),
          _MappingTile(
            title: 'Lecture summaries data source',
            value: settings.notionSummariesDataSourceId,
          ),
          const Divider(height: 1),
          _SettingSwitch(
            title: 'Fireflies metadata',
            subtitle:
                'Store meeting ID for duplicate detection and source tracing.',
            value: settings.notionMetadataEnabled,
            onChanged: (value) => ref
                .read(settingsControllerProvider)
                .save(settings.copyWith(notionMetadataEnabled: value)),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Mappings stay on this device'),
            subtitle: Text(
              'To use another Notion workspace, configure its token and data sources on that device.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _MappingTile extends StatelessWidget {
  const _MappingTile({required this.title, required this.value});
  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final configured = value?.trim().isNotEmpty ?? false;
    return ListTile(
      leading: Icon(
        configured ? Icons.check_circle_outline : Icons.error_outline,
        color: configured
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
      title: Text(title),
      subtitle: Text(configured ? 'Mapped during setup' : 'Not mapped'),
    );
  }
}

class _Corrections extends ConsumerWidget {
  const _Corrections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corrections =
        ref.watch(classificationCorrectionsProvider).valueOrNull ?? const [];
    return _SettingsSection(
      title: 'Classification corrections',
      description: 'Exact lecture-title matches learned on this device.',
      child: Card(
        child: corrections.isEmpty
            ? const ListTile(title: Text('No learned corrections'))
            : Column(
                children: [
                  for (var index = 0; index < corrections.length; index++) ...[
                    ListTile(
                      title: Text(
                        corrections[index].titlePattern ?? 'Untitled',
                      ),
                      subtitle: Text(corrections[index].subjectName),
                      trailing: IconButton(
                        tooltip: 'Delete correction',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => ref
                            .read(databaseProvider)
                            .deleteCorrection(corrections[index].id),
                      ),
                    ),
                    if (index < corrections.length - 1) const Divider(),
                  ],
                ],
              ),
      ),
    );
  }
}

Future<void> _confirmPurge(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Purge local lecture content?'),
      content: const Text(
        'This removes stored transcripts and summaries. Published Notion pages and job metadata remain.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Purge'),
        ),
      ],
    ),
  );
  if (confirmed == true) await ref.read(databaseProvider).purgeStoredContent();
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
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(credentialConfiguredProvider(credential));
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = status.when(
      data: (configured) => configured
          ? ('Connected', scheme.primary)
          : ('Not configured', scheme.error),
      loading: () => ('Checking secure storage…', scheme.onSurfaceVariant),
      error: (error, stack) =>
          ('Could not check secure storage', scheme.onSurfaceVariant),
    );
    return Card(
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
                  Text(label, style: TextStyle(color: color)),
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
}

enum _AcademicSource { portal, moodle }

class _AcademicIntegrationTile extends ConsumerWidget {
  const _AcademicIntegrationTile({
    required this.name,
    required this.icon,
    required this.source,
    required this.onConfigure,
  });

  final String name;
  final IconData icon;
  final _AcademicSource source;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(academicConnectionStateProvider);
    final configured = value.valueOrNull == null
        ? null
        : switch (source) {
            _AcademicSource.portal => value.valueOrNull!.portalConfigured,
            _AcademicSource.moodle => value.valueOrNull!.moodleConfigured,
          };
    final scheme = Theme.of(context).colorScheme;
    final label = configured == null
        ? 'Checking secure storage…'
        : configured
        ? 'Connected'
        : 'Not configured';
    final color = configured == true
        ? scheme.primary
        : configured == false
        ? scheme.error
        : scheme.onSurfaceVariant;
    return Card(
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
                  Text(label, style: TextStyle(color: color)),
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
}

class _FirefliesConnectionsTile extends ConsumerWidget {
  const _FirefliesConnectionsTile({required this.onManage});
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(firefliesConnectionsProvider);
    final scheme = Theme.of(context).colorScheme;
    final (status, detail, color) = value.when(
      data: (connections) => connections.isEmpty
          ? ('Not configured', 'Add your first Fireflies source', scheme.error)
          : (
              '${connections.length} ${connections.length == 1 ? 'source' : 'sources'}',
              connections.map((item) => item.name).join(' · '),
              scheme.primary,
            ),
      loading: () => (
        'Checking secure storage…',
        'API keys remain encrypted on this device',
        scheme.onSurfaceVariant,
      ),
      error: (error, stack) => (
        'Could not check secure storage',
        'Open to retry',
        scheme.onSurfaceVariant,
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.mic_none_rounded)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fireflies',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(status, style: TextStyle(color: color)),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onManage,
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Manage Fireflies sources',
            ),
          ],
        ),
      ),
    );
  }
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

class _GeminiModelDropdown extends StatelessWidget {
  const _GeminiModelDropdown({
    required this.fieldKey,
    required this.label,
    required this.currentModel,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final String currentModel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final known = geminiTextModels.any((model) => model.id == currentModel);
    final options = [
      if (!known)
        GeminiModelOption(
          id: currentModel,
          label: 'Legacy model ($currentModel)',
          description:
              'Saved by an older ClassSync version. Choose a supported model.',
        ),
      ...geminiTextModels,
    ];
    final selected = options.firstWhere((model) => model.id == currentModel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: fieldKey,
          initialValue: currentModel,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            helperText: 'Falls back automatically when a model is unavailable.',
          ),
          items: options
              .map(
                (model) => DropdownMenuItem(
                  value: model.id,
                  child: Text(model.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null && value != currentModel) onChanged(value);
          },
        ),
        const SizedBox(height: 6),
        Text(
          selected.description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
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
                  onPressed: () => _configureRelay(context, ref, settings),
                  icon: const Icon(Icons.dns_outlined),
                  label: const Text('Advanced relay settings'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _exportDiagnostics(context, ref, settings, jobs),
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

Future<void> _manageFirefliesConnections(
  BuildContext context,
  WidgetRef ref,
) async {
  final connections = List<FirefliesConnection>.of(
    await ref.read(credentialStoreProvider).readFirefliesConnections(),
  );
  final webhook = await _loadAccountWebhook(ref);
  if (!context.mounted) return;
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: const Text('Fireflies sources'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A Fireflies source is an account this ClassSync account may query. Every source works through polling; realtime delivery is an optional account-level accelerator.',
              ),
              const SizedBox(height: 8),
              Text(
                'Only add API keys shared with permission.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (connections.isEmpty)
                const ListTile(
                  leading: Icon(Icons.key_off_outlined),
                  title: Text('No Fireflies sources'),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (
                      var index = 0;
                      index < connections.length;
                      index++
                    ) ...[
                      if (index > 0) const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline_rounded),
                        ),
                        title: Text(connections[index].name),
                        subtitle: FutureBuilder<DateTime?>(
                          future: ref
                              .read(databaseProvider)
                              .readCursor('fireflies:${connections[index].id}'),
                          builder: (context, snapshot) => Text(
                            'API ${connections[index].validatedAt == null ? 'saved' : 'connected'} · Polling active${snapshot.data == null ? '' : ' · Last ${_shortTimestamp(snapshot.data!)}'} · ${webhook?.lastReceivedAt == null ? 'Realtime not confirmed' : 'Realtime active'}',
                          ),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Manage source',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final updated =
                                          await _editFirefliesConnection(
                                            dialogContext,
                                            ref,
                                            existing: connections[index],
                                            allConnections: connections,
                                            webhook: webhook,
                                          );
                                      if (updated != null) {
                                        setState(() {
                                          busy = true;
                                          error = null;
                                          connections[index] = updated;
                                        });
                                        try {
                                          await _saveFirefliesSources(
                                            ref,
                                            connections,
                                          );
                                        } catch (failure) {
                                          error = failure.toString();
                                        } finally {
                                          setState(() => busy = false);
                                        }
                                      }
                                    },
                            ),
                            IconButton(
                              tooltip: 'Remove source',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final removed = connections.removeAt(
                                        index,
                                      );
                                      setState(() {
                                        busy = true;
                                        error = null;
                                      });
                                      try {
                                        await _saveFirefliesSources(
                                          ref,
                                          connections,
                                        );
                                      } catch (failure) {
                                        connections.insert(index, removed);
                                        error = failure.toString();
                                      } finally {
                                        setState(() => busy = false);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
          OutlinedButton.icon(
            onPressed:
                busy || connections.length >= FirefliesConnection.maxConnections
                ? null
                : () async {
                    final added = await _editFirefliesConnection(
                      dialogContext,
                      ref,
                      allConnections: connections,
                      webhook: webhook,
                    );
                    if (added != null) {
                      connections.add(added);
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await _saveFirefliesSources(ref, connections);
                      } catch (failure) {
                        connections.removeLast();
                        error = failure.toString();
                      } finally {
                        setState(() => busy = false);
                      }
                    }
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Fireflies source'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _saveFirefliesSources(
  WidgetRef ref,
  List<FirefliesConnection> connections,
) async {
  await ref
      .read(credentialStoreProvider)
      .writeFirefliesConnections(connections);
  ref.invalidate(firefliesConnectionsProvider);
  ref.invalidate(credentialConfiguredProvider(CredentialKey.firefliesApiKey));
  try {
    await ref.read(deviceSyncServiceProvider).pushConfiguration();
  } catch (_) {
    // Saved locally; device sync retries later.
  }
  unawaited(ref.read(syncControllerProvider.notifier).run(SyncReason.manual));
}

Future<AccountWebhookConfig?> _loadAccountWebhook(WidgetRef ref) async {
  final settings = await ref.read(settingsProvider.future);
  final account = await ref
      .read(accountSyncClientProvider)
      .readAccount(ref.read(credentialStoreProvider));
  if (account == null || settings.relayBaseUrl?.isNotEmpty != true) return null;
  try {
    return await ref
        .read(accountSyncClientProvider)
        .webhookConfig(baseUrl: settings.relayBaseUrl!, account: account);
  } catch (_) {
    // Polling remains operational while relay status is unavailable.
    return null;
  }
}

Future<FirefliesConnection?> _editFirefliesConnection(
  BuildContext context,
  WidgetRef ref, {
  FirefliesConnection? existing,
  required List<FirefliesConnection> allConnections,
  AccountWebhookConfig? webhook,
}) async {
  final nameController = TextEditingController(text: existing?.name);
  final keyController = TextEditingController();
  String? error;
  var busy = false;
  var currentWebhook = webhook;
  final result = await showDialog<FirefliesConnection>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text(existing == null ? 'Add Fireflies source' : existing.name),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: FirefliesConnection.maxNameLength,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Ana · My Fireflies · Lab recorder',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Fireflies API key',
                  helperText: existing == null
                      ? 'Connection is tested before saving.'
                      : 'Leave blank to keep current key.',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'API connection · ${existing?.validatedAt == null ? 'Validate before saving' : 'Connected'}',
              ),
              const SizedBox(height: 12),
              const Text('Transcript discovery'),
              const Text('Polling · Enabled'),
              FutureBuilder<DateTime?>(
                future: existing == null
                    ? Future<DateTime?>.value()
                    : ref
                          .read(databaseProvider)
                          .readCursor('fireflies:${existing.id}'),
                builder: (context, snapshot) => Text(
                  snapshot.data == null
                      ? 'Last successful poll · Not yet'
                      : 'Last successful poll · ${_shortTimestamp(snapshot.data!)}',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Realtime delivery for this ClassSync account'),
              Text(
                currentWebhook == null
                    ? 'Unavailable · Polling remains active'
                    : currentWebhook!.lastReceivedAt == null
                    ? 'Not confirmed · Configure Webhooks V2 manually'
                    : 'Active · Last event ${_shortTimestamp(currentWebhook!.lastReceivedAt!)}',
              ),
              if (existing?.accountEmail != null)
                Text('Fireflies account · ${existing!.accountEmail}'),
              if (currentWebhook != null) ...[
                const SizedBox(height: 8),
                SelectableText('Webhook URL\n${currentWebhook!.webhookUrl}'),
                const SizedBox(height: 8),
                const Text('Signing secret\n••••••••••••'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: currentWebhook!.webhookUrl),
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy URL'),
                    ),
                    TextButton.icon(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: currentWebhook!.signingSecret),
                      ),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('Copy secret'),
                    ),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              currentWebhook = await _loadAccountWebhook(ref);
                              setState(() => busy = false);
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh status'),
                    ),
                  ],
                ),
                const Text(
                  'In Fireflies Webhooks V2, use these values and subscribe to meeting.transcribed. Fireflies does not expose saved-webhook setup through its public API.',
                ),
              ],
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
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final name = nameController.text.trim();
                    final enteredKey = keyController.text.trim();
                    final apiKey = enteredKey.isEmpty
                        ? existing?.apiKey ?? ''
                        : enteredKey;
                    if (name.isEmpty || apiKey.isEmpty) {
                      setState(
                        () => error = 'Enter a name and Fireflies API key.',
                      );
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final identity = await ref
                          .read(firefliesClientProvider)
                          .testConnection(apiKey);
                      if (allConnections.any(
                        (item) =>
                            item.id != existing?.id &&
                            item.firefliesUserId == identity.userId,
                      )) {
                        throw const FormatException(
                          'This Fireflies account is already added.',
                        );
                      }
                      final candidate = FirefliesConnection(
                        id: existing?.id ?? const Uuid().v4(),
                        name: name,
                        apiKey: apiKey,
                        firefliesUserId: identity.userId,
                        accountEmail: identity.email,
                        validatedAt: DateTime.now().toUtc(),
                      );
                      candidate.validate();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, candidate);
                      }
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
                : Text(
                    existing == null ? 'Validate and add' : 'Validate and save',
                  ),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  keyController.dispose();
  return result;
}

String _shortTimestamp(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
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
                      try {
                        await ref
                            .read(deviceSyncServiceProvider)
                            .pushConfiguration();
                      } catch (_) {
                        // Saved locally; device sync retries later.
                      }
                      ref.invalidate(credentialConfiguredProvider(key));
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
              const Text(
                'For development, staging, or self-hosting. Existing account credentials authenticate this device; no bootstrap token is stored here.',
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
                final credentialStore = ref.read(credentialStoreProvider);
                final account = await ref
                    .read(accountSyncClientProvider)
                    .readAccount(credentialStore);
                if (account == null) {
                  throw const FormatException(
                    'Create or recover a ClassSync account before changing relay infrastructure.',
                  );
                }
                await ref
                    .read(accountSyncClientProvider)
                    .webhookConfig(
                      baseUrl: urlController.text.trim(),
                      account: account,
                    );
                await credentialStore.delete(CredentialKey.relayDeviceToken);
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
}

Future<void> _exportDiagnostics(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
  List<SyncJob> jobs,
) async {
  final info = await PackageInfo.fromPlatform();
  final output = {
    'application': 'ClassSync',
    'version': info.version,
    'platform': Platform.operatingSystem,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'database': {'status': 'ready', 'schemaVersion': 7},
    'queueEntries': jobs.length,
    'pollingMinutes': settings.pollingMinutes,
    'overlapHours': settings.overlapHours,
    'relayConfigured': settings.relayBaseUrl != null,
    'notionSubjectsMapped': settings.notionSubjectsDataSourceId != null,
    'notionSummariesMapped': settings.notionSummariesDataSourceId != null,
    'jobs': jobs
        .take(100)
        .map(
          (job) => {
            'id': job.id,
            'status': job.status.wireName,
            'sourceType': job.sourceType,
            'attemptCount': job.attemptCount,
            'lastErrorType': job.lastErrorType,
            'lastErrorMessage': job.lastErrorMessage,
            'updatedAt': job.updatedAt.toUtc().toIso8601String(),
          },
        )
        .toList(),
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
