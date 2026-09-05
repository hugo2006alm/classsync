import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/integrations/notion/notion_client.dart';
import '../../core/providers.dart';
import '../../core/security/secure_credential_store.dart';
import '../../domain/settings/app_settings.dart';
import '../../platform/mobile/background_sync.dart';

class SetupWizard extends ConsumerStatefulWidget {
  const SetupWizard({super.key});

  @override
  ConsumerState<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends ConsumerState<SetupWizard> {
  final _pageController = PageController();
  final _firefliesController = TextEditingController();
  final _geminiController = TextEditingController();
  final _notionController = TextEditingController();
  final _relayUrlController = TextEditingController();
  final _relayTokenController = TextEditingController();
  final _modelController = TextEditingController(text: 'gemini-3.8-flash');

  var _page = 0;
  var _busy = false;
  String? _error;
  List<NotionDataSource> _dataSources = const [];
  String? _subjectsId;
  String? _summariesId;
  var _addMetadata = true;
  var _notifications = true;
  var _launchWithWindows = true;
  var _backgroundMobile = true;

  static const _stepCount = 7;

  @override
  void dispose() {
    _pageController.dispose();
    _firefliesController.dispose();
    _geminiController.dispose();
    _notionController.dispose();
    _relayUrlController.dispose();
    _relayTokenController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.auto_stories_rounded),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ClassSync',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text('${_page + 1} / $_stepCount'),
                  ],
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(value: (_page + 1) / _stepCount),
                const SizedBox(height: 24),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _welcome(),
                      _fireflies(),
                      _gemini(),
                      _notion(),
                      _relay(),
                      _automation(),
                      _ready(),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!)),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_page > 0)
                      TextButton(
                        onPressed: _busy ? null : _back,
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _busy ? null : _next,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _page == _stepCount - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                      label: Text(
                        _page == _stepCount - 1 ? 'Finish setup' : 'Continue',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _welcome() => _StepBody(
    icon: Icons.school_rounded,
    title: 'Your lectures, organized automatically',
    description:
        'ClassSync turns completed Fireflies transcripts into detailed study summaries in the correct Notion class. After setup, the normal desktop path needs no clicks.',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Processing stays on this device. Cloudflare stores only pending transcript identifiers.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _fireflies() => _StepBody(
    icon: Icons.mic_none_rounded,
    title: 'Connect Fireflies',
    description:
        'Used to discover recent transcripts and fetch speaker-aware lecture content. The key is stored in OS secure storage.',
    child: TextField(
      controller: _firefliesController,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      decoration: const InputDecoration(
        labelText: 'Fireflies API key',
        prefixIcon: Icon(Icons.key_rounded),
      ),
    ),
  );

  Widget _gemini() => _StepBody(
    icon: Icons.auto_awesome_rounded,
    title: 'Connect Gemini',
    description:
        'Gemini classifies lectures against active Notion subjects and generates structured study notes.',
    child: Column(
      children: [
        TextField(
          controller: _geminiController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Gemini API key',
            prefixIcon: Icon(Icons.key_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _modelController,
          decoration: const InputDecoration(
            labelText: 'Default Gemini model',
            helperText: 'Configurable later under Settings → AI',
          ),
        ),
      ],
    ),
  );

  Widget _notion() => _StepBody(
    icon: Icons.account_tree_outlined,
    title: 'Map your Notion workspace',
    description:
        'ClassSync discovers accessible data sources. It will not recreate your ISEP semester or databases.',
    child: Column(
      children: [
        TextField(
          controller: _notionController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Notion integration token',
            prefixIcon: Icon(Icons.key_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _discoverNotion,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Discover data sources'),
          ),
        ),
        if (_dataSources.isNotEmpty) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _subjectsId,
            decoration: const InputDecoration(labelText: 'Lista de Cadeiras'),
            items: _dataSources
                .map(
                  (source) => DropdownMenuItem(
                    value: source.id,
                    child: Text(source.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _subjectsId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _summariesId,
            decoration: const InputDecoration(
              labelText: 'Histórico de Resumos',
            ),
            items: _dataSources
                .map(
                  (source) => DropdownMenuItem(
                    value: source.id,
                    child: Text(source.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _summariesId = value),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _addMetadata,
            onChanged: (value) => setState(() => _addMetadata = value ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text('Add “Fireflies ID” to Histórico de Resumos'),
            subtitle: const Text(
              'Additive schema change. Enables safe desktop/mobile deduplication. No existing property is renamed or deleted. If disabled, deduplication is local and weaker.',
            ),
          ),
        ],
      ],
    ),
  );

  Widget _relay() => _StepBody(
    icon: Icons.cloud_queue_rounded,
    title: 'Connect ClassSync Relay',
    description:
        'Deploy apps/relay to Cloudflare first, then enter its Worker URL and device token. Fireflies polling remains the recovery path.',
    child: Column(
      children: [
        TextField(
          controller: _relayUrlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Relay base URL',
            hintText: 'https://classsync-relay.<account>.workers.dev',
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _relayTokenController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Device API token',
            prefixIcon: Icon(Icons.key_rounded),
          ),
        ),
      ],
    ),
  );

  Widget _automation() => _StepBody(
    icon: Icons.settings_suggest_rounded,
    title: 'Set quiet automation',
    description:
        'Success stays quiet. Reviews and failures remain visible and actionable.',
    child: Card(
      child: Column(
        children: [
          SwitchListTile(
            value: _notifications,
            onChanged: (value) => setState(() => _notifications = value),
            title: const Text('Problem and review notifications'),
            subtitle: const Text('Success notifications remain silent.'),
          ),
          const Divider(),
          SwitchListTile(
            value: _launchWithWindows,
            onChanged: (value) => setState(() => _launchWithWindows = value),
            title: const Text('Launch with Windows'),
            subtitle: const Text('Start hidden in the system tray.'),
          ),
          const Divider(),
          SwitchListTile(
            value: _backgroundMobile,
            onChanged: (value) => setState(() => _backgroundMobile = value),
            title: const Text('Best-effort mobile background sync'),
            subtitle: const Text('The OS may defer or stop background work.'),
          ),
        ],
      ),
    ),
  );

  Widget _ready() => _StepBody(
    icon: Icons.check_circle_outline_rounded,
    title: 'Ready for zero-click lecture sync',
    description:
        'ClassSync will cache active classes, watch its durable queue, poll Fireflies with overlap, and publish through one shared pipeline.',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            _ReadyRow(Icons.webhook_rounded, 'Relay fast path configured'),
            SizedBox(height: 12),
            _ReadyRow(Icons.history_rounded, '48-hour recovery overlap'),
            SizedBox(height: 12),
            _ReadyRow(Icons.shield_outlined, 'Credentials stored securely'),
            SizedBox(height: 12),
            _ReadyRow(
              Icons.visibility_off_outlined,
              'Full transcript removed after success',
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _next() async {
    setState(() => _error = null);
    try {
      setState(() => _busy = true);
      switch (_page) {
        case 1:
          if (_firefliesController.text.trim().isEmpty) {
            throw const FormatException('Enter a Fireflies API key.');
          }
          await ref
              .read(firefliesClientProvider)
              .testConnection(_firefliesController.text.trim());
        case 2:
          if (_geminiController.text.trim().isEmpty ||
              _modelController.text.trim().isEmpty) {
            throw const FormatException('Enter Gemini API key and model.');
          }
          await ref
              .read(geminiClientProvider)
              .testConnection(
                apiKey: _geminiController.text.trim(),
                model: _modelController.text.trim(),
              );
        case 3:
          if (_dataSources.isEmpty) await _discoverNotion();
          if (_subjectsId == null || _summariesId == null) {
            throw const FormatException('Select both Notion data sources.');
          }
        case 4:
          if (_relayUrlController.text.trim().isEmpty ||
              _relayTokenController.text.trim().length < 32) {
            throw const FormatException(
              'Enter relay URL and a device token of at least 32 characters.',
            );
          }
          await ref
              .read(relayClientProvider)
              .testConnection(_relayUrlController.text.trim());
        case 6:
          await _finish();
          return;
      }
      if (_page < _stepCount - 1) {
        setState(() => _page += 1);
        await _pageController.animateToPage(
          _page,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      setState(
        () => _error = error is FormatException
            ? error.message
            : error.toString(),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discoverNotion() async {
    final token = _notionController.text.trim();
    if (token.isEmpty) {
      throw const FormatException('Enter a Notion integration token.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notion = ref.read(notionClientProvider);
      await notion.testConnection(token);
      final sources = await notion.searchDataSources(token: token);
      setState(() {
        _dataSources = sources;
        _subjectsId = sources
            .where((source) => source.name == 'Lista de Cadeiras')
            .firstOrNull
            ?.id;
        _summariesId = sources
            .where((source) => source.name == 'Histórico de Resumos')
            .firstOrNull
            ?.id;
      });
      if (sources.isEmpty) {
        throw const FormatException(
          'No Notion data sources found. Share the ISEP page with the integration.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    final credentialStore = ref.read(credentialStoreProvider);
    final notionToken = _notionController.text.trim();
    if (_addMetadata) {
      await ref
          .read(notionClientProvider)
          .addFirefliesIdProperty(
            token: notionToken,
            summariesDataSourceId: _summariesId!,
          );
    }
    await Future.wait([
      credentialStore.write(
        CredentialKey.firefliesApiKey,
        _firefliesController.text,
      ),
      credentialStore.write(CredentialKey.geminiApiKey, _geminiController.text),
      credentialStore.write(CredentialKey.notionToken, notionToken),
      credentialStore.write(
        CredentialKey.relayDeviceToken,
        _relayTokenController.text,
      ),
    ]);
    final settings = AppSettings.defaults.copyWith(
      setupComplete: true,
      launchWithWindows: _launchWithWindows,
      backgroundMobileSync: _backgroundMobile,
      notificationsEnabled: _notifications,
      classificationModel: _modelController.text.trim(),
      summaryModel: _modelController.text.trim(),
      notionMetadataEnabled: _addMetadata,
      notionSubjectsDataSourceId: _subjectsId,
      notionSummariesDataSourceId: _summariesId,
      relayBaseUrl: _relayUrlController.text.trim(),
    );
    await ref.read(settingsControllerProvider).save(settings);
    if (_notifications) {
      await ref.read(notificationServiceProvider).requestPermissions();
    }
    await configureMobileBackgroundSync(settings);
  }

  void _back() {
    setState(() {
      _error = null;
      _page -= 1;
    });
    _pageController.animateToPage(
      _page,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    ),
  );
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
    ],
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
