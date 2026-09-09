import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/integrations/notion/notion_client.dart';
import '../../core/integrations/relay/account_sync_client.dart';
import '../../core/providers.dart';
import '../../core/security/trusted_url_launcher.dart';
import '../../core/security/secure_credential_store.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/settings/fireflies_connection.dart';
import '../../domain/sync/sync_models.dart';
import '../../platform/mobile/background_sync.dart';

class SetupWizard extends ConsumerStatefulWidget {
  const SetupWizard({super.key});

  @override
  ConsumerState<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends ConsumerState<SetupWizard> {
  final _pageController = PageController();
  final _firefliesController = TextEditingController();
  final _firefliesNameController = TextEditingController(text: 'My Fireflies');
  final _geminiController = TextEditingController();
  final _notionController = TextEditingController();
  final _portalUsernameController = TextEditingController();
  final _portalPasswordController = TextEditingController();
  final _moodleUsernameController = TextEditingController();
  final _moodlePasswordController = TextEditingController();
  final _relayUrlController = TextEditingController(
    text: AppSettings.productionRelayBaseUrl,
  );
  final _relayTokenController = TextEditingController();
  final _modelController = TextEditingController(text: 'gemini-3.8-flash');
  final _accountCodeController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _primaryFirefliesId = const Uuid().v4();

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
  var _joinAccount = false;
  var _joinedExistingAccount = false;
  var _recoveryEntry = false;
  List<int> get _flow =>
      _recoveryEntry ? const [0, 6, 7, 8] : List.generate(_stepCount, (i) => i);
  SyncAccount? _syncAccount;
  AccountWebhookConfig? _webhookConfig;

  static const _stepCount = 9;
  static const _steps = <_StepDefinition>[
    _StepDefinition('Welcome', Icons.waving_hand_outlined),
    _StepDefinition('Fireflies', Icons.mic_none_rounded),
    _StepDefinition('Gemini', Icons.auto_awesome_outlined),
    _StepDefinition('Notion', Icons.account_tree_outlined),
    _StepDefinition('Academic', Icons.school_outlined),
    _StepDefinition('Relay', Icons.cloud_queue_outlined),
    _StepDefinition('Account', Icons.devices_rounded),
    _StepDefinition('Automation', Icons.tune_rounded),
    _StepDefinition('Ready', Icons.check_circle_outline_rounded),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _firefliesController.dispose();
    _firefliesNameController.dispose();
    _geminiController.dispose();
    _notionController.dispose();
    _portalUsernameController.dispose();
    _portalPasswordController.dispose();
    _moodleUsernameController.dispose();
    _moodlePasswordController.dispose();
    _relayUrlController.dispose();
    _relayTokenController.dispose();
    _modelController.dispose();
    _accountCodeController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ColoredBox(
        color: scheme.surface,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 24 : 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: wide
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 300,
                                  child: _SetupRail(
                                    current: _flow.indexOf(_page),
                                    steps: _flow.map((i) => _steps[i]).toList(),
                                  ),
                                ),
                                Expanded(child: _setupPanel(compact: false)),
                              ],
                            )
                          : _setupPanel(compact: true),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _setupPanel({required bool compact}) => Padding(
    padding: EdgeInsets.fromLTRB(
      compact ? 18 : 48,
      compact ? 18 : 32,
      compact ? 18 : 48,
      compact ? 16 : 28,
    ),
    child: Column(
      children: [
        _SetupHeader(
          current: _flow.indexOf(_page),
          total: _flow.length,
          compact: compact,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _welcome(),
              _fireflies(),
              _gemini(),
              _notion(),
              _academicConnections(),
              _relay(),
              _account(),
              _automation(),
              _ready(),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _InlineError(message: _error!),
        ],
        const SizedBox(height: 16),
        _SetupFooter(page: _page, busy: _busy, onBack: _back, onNext: _next),
      ],
    ),
  );

  Widget _welcome() => _StepBody(
    eyebrow: 'WELCOME TO YOUR STUDY DESK',
    icon: Icons.auto_stories_rounded,
    title: 'From lecture to study notes, quietly.',
    description:
        'Nine short steps connect the tools you already use. ClassSync then sorts completed Fireflies lectures into the correct Notion class and writes detailed notes.',
    child: Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.devices_rounded),
            label: const Text('Use recovery code'),
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _recoveryEntry = true;
                      _joinAccount = true;
                      _page = 6;
                      _error = null;
                    });
                    _pageController.jumpToPage(6);
                  },
          ),
        ),
        const Text('Already have an account? Restore your saved setup.'),
        const SizedBox(height: 14),
        const _GuideCard(
          title: 'Have these four things ready',
          items: [
            'A Fireflies API key',
            'A Gemini API key',
            'A Notion integration token and the ISEP page shared with it',
            'The ClassSync device API token',
          ],
        ),
        const SizedBox(height: 14),
        const _InfoStrip(
          icon: Icons.check_circle_outline_rounded,
          message:
              'Firebase, Cloudflare, and the production relay URL are already configured in this build.',
        ),
        const SizedBox(height: 10),
        const _InfoStrip(
          icon: Icons.lock_outline_rounded,
          message:
              'Your API keys stay in OS secure storage. The relay receives identifiers and timestamps, never transcript text or summaries.',
        ),
      ],
    ),
  );

  Widget _fireflies() => _StepBody(
    eyebrow: 'SOURCE · 1 OF 4',
    icon: Icons.mic_none_rounded,
    title: 'Bring in your lectures.',
    description:
        'ClassSync uses your API key to find completed meetings and fetch speaker-aware transcripts.',
    child: Column(
      children: [
        const _GuideCard(
          title: 'In Fireflies',
          items: [
            'Open Settings → Personal → Developer settings.',
            'Copy your API key.',
            'Keep this page open. Your private webhook URL appears in the Account step.',
          ],
        ),
        const SizedBox(height: 16),
        _SecretField(
          controller: _firefliesController,
          label: 'Fireflies API key',
          hint: 'Paste the key from Developer settings',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _firefliesNameController,
          maxLength: FirefliesConnection.maxNameLength,
          decoration: const InputDecoration(
            labelText: 'Connection name',
            hintText: 'My Fireflies',
            helperText:
                'Use a person or account name so transcript ownership is clear.',
          ),
        ),
      ],
    ),
  );

  Widget _gemini() => _StepBody(
    eyebrow: 'AI · 2 OF 4',
    icon: Icons.auto_awesome_rounded,
    title: 'Shape raw speech into notes.',
    description:
        'Gemini matches each lecture to an active subject and produces structured study notes in Portuguese.',
    child: Column(
      children: [
        const _GuideCard(
          title: 'In Google AI Studio',
          items: [
            'Open the API keys page.',
            'Create or copy a Gemini API key.',
            'Paste it below. ClassSync checks available models without generating content.',
            'If the preferred model is unavailable, the next supported model is selected automatically.',
          ],
        ),
        const SizedBox(height: 16),
        _SecretField(
          controller: _geminiController,
          label: 'Gemini API key',
          hint: 'Usually starts with AIza',
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Advanced model setting'),
            subtitle: const Text(
              'The recommended default is already selected.',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Gemini model',
                  helperText:
                      'ClassSync falls back automatically when this model is unavailable.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _notion() => _StepBody(
    eyebrow: 'DESTINATION · 3 OF 4',
    icon: Icons.account_tree_outlined,
    title: 'Point to your study workspace.',
    description:
        'ClassSync discovers the databases that your integration can access. It will never recreate or rename your existing workspace.',
    child: Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _busy
                ? null
                : () => launchTrustedUrl(
                    'https://checker-dryer-7e3.notion.site/ClassSync-Template-3d387b0ef0908153a466c7aa2f8f7332',
                    allowedHosts: const {'notion.site'},
                  ),
            icon: const Icon(Icons.content_copy_rounded),
            label: const Text('Duplicate the ClassSync Notion template'),
          ),
        ),
        const SizedBox(height: 14),
        const _GuideCard(
          title: 'In Notion',
          items: [
            'Open the template above and choose Duplicate into your own workspace.',
            'Create an internal integration at notion.so/my-integrations.',
            'Copy its internal integration secret.',
            'Open your ClassSync Template page, choose ••• → Connections, and add the integration.',
          ],
        ),
        const SizedBox(height: 16),
        _SecretField(
          controller: _notionController,
          label: 'Notion integration token',
          hint: 'Paste the internal integration secret',
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _discoverNotion,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Discover shared databases'),
          ),
        ),
        if (_dataSources.isNotEmpty) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('subjects-$_subjectsId'),
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
            key: ValueKey('summaries-$_summariesId'),
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
            title: const Text('Add “Fireflies ID” for safer duplicate checks'),
            subtitle: const Text(
              'Recommended. This only adds one text property; no existing property is renamed or removed.',
            ),
          ),
          const SizedBox(height: 8),
          const _InfoStrip(
            icon: Icons.rule_rounded,
            message:
                'Required: Lista de Cadeiras needs Nome, Ano, Semestre and Status. Histórico de Resumos needs Nome, Data and Cadeira.',
          ),
        ],
      ],
    ),
  );

  Widget _relay() => _StepBody(
    eyebrow: 'DELIVERY · 4 OF 4',
    icon: Icons.cloud_queue_rounded,
    title: 'Connect this device.',
    description:
        'The hosted relay URL is built in. App and relay updates keep the same address, so you only need to paste the bootstrap device token.',
    child: Column(
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hosted ClassSync relay',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const SelectableText(AppSettings.productionRelayBaseUrl),
                      const SizedBox(height: 6),
                      const Text(
                        'Already selected · future deployments use this same URL',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SecretField(
          controller: _relayTokenController,
          label: 'Device API token',
          hint: 'Paste the 32+ character bootstrap token',
        ),
        const SizedBox(height: 10),
        const _InfoStrip(
          icon: Icons.info_outline_rounded,
          message:
              'This is DEVICE_API_TOKEN from Cloudflare—not the Fireflies webhook secret. It is used once to enroll this installation.',
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Use a different relay'),
            subtitle: const Text(
              'Only for self-hosting or a staging environment.',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _relayUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Custom relay URL',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _academicConnections() => _StepBody(
    eyebrow: 'ACADEMIC SOURCES · OPTIONAL',
    icon: Icons.school_outlined,
    title: 'Bring the official context with you.',
    description:
        'Portal adds your timetable, grades, enrolment, exam registrations, official lesson summaries, FUC details, and notices. Moodle adds assignments and announcements. Leave everything blank to skip this step.',
    child: Column(
      children: [
        const _InfoStrip(
          icon: Icons.lock_outline_rounded,
          message:
              'These credentials stay in this device’s OS secure storage. ClassSync only reads academic data and never submits an exam registration.',
        ),
        const SizedBox(height: 14),
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('ISEP Portal'),
            subtitle: const Text('Recommended · username and password'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _portalUsernameController,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Portal username or ISEP email',
                  helperText:
                      'Username and password are both required on the first connection.',
                ),
              ),
              const SizedBox(height: 12),
              _SecretField(
                controller: _portalPasswordController,
                label: 'Portal password',
                hint: 'Same password used at portal.isep.ipp.pt',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('Moodle ISEP'),
            subtitle: const Text('Optional · ISEP username and password'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _moodleUsernameController.text =
                        _portalUsernameController.text;
                    _moodlePasswordController.text =
                        _portalPasswordController.text;
                  }),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Use Portal credentials'),
                ),
              ),
              TextField(
                controller: _moodleUsernameController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Moodle username or ISEP email',
                  hintText: 'Usually the same username as the Portal',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _SecretField(
                controller: _moodlePasswordController,
                label: 'Moodle password',
                hint: 'Leave blank to connect later',
              ),
              const SizedBox(height: 10),
              const Text(
                'ClassSync exchanges these credentials for a Moodle app token, stores only the token, and immediately discards the password.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'You can connect or replace either source later from Academic → Connections.',
        ),
      ],
    ),
  );

  Widget _account() => _StepBody(
    eyebrow: 'YOUR DEVICES',
    icon: Icons.devices_rounded,
    title: _recoveryEntry
        ? 'Restore your study desk.'
        : 'Keep each person separate.',
    description:
        'One private account connects your own PCs and phone. Other people create their own account, keys, Notion workspace, and queue.',
    child: Column(
      children: [
        if (!_joinAccount && _syncAccount == null) ...[
          TextField(
            controller: _accountNameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Your name',
              hintText: 'Name shown across your ClassSync devices',
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (!_recoveryEntry)
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.add_rounded),
                label: Text('New account'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.devices_rounded),
                label: Text('Join mine'),
              ),
            ],
            selected: {_joinAccount},
            onSelectionChanged: _syncAccount == null
                ? (values) => setState(() => _joinAccount = values.first)
                : null,
          ),
        if (_joinAccount && _syncAccount == null) ...[
          const Text(
            'Use your recovery code to restore saved API keys and Notion mappings. No setup token needed.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _accountCodeController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Recovery code from your first device',
              hintText: 'CS1.…',
            ),
          ),
          ExpansionTile(
            title: const Text('Custom relay (optional)'),
            children: [
              TextField(
                controller: _relayUrlController,
                decoration: const InputDecoration(labelText: 'Relay URL'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy || _syncAccount != null ? null : _prepareAccount,
            icon: Icon(_joinAccount ? Icons.login_rounded : Icons.lock_rounded),
            label: Text(
              _joinAccount ? 'Join account' : 'Create private account',
            ),
          ),
        ),
        if (_syncAccount != null && _webhookConfig != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('In Fireflies Webhooks V2'),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the URL and signing secret below. Subscribe only to meeting.transcribed, save, then run Test Webhook.',
                  ),
                  const SizedBox(height: 14),
                  SelectableText('URL\n${_webhookConfig!.webhookUrl}'),
                  const SizedBox(height: 10),
                  SelectableText(
                    'Signing secret\n${_webhookConfig!.signingSecret}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: _webhookConfig!.webhookUrl),
                        ),
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Copy URL'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: _webhookConfig!.signingSecret),
                        ),
                        icon: const Icon(Icons.key_rounded),
                        label: const Text('Copy secret'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: _syncAccount!.recoveryCode),
                        ),
                        icon: const Icon(Icons.save_alt_rounded),
                        label: const Text('Copy recovery code'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _InfoStrip(
            icon: Icons.security_rounded,
            message:
                'Save the recovery code in a password manager. The relay cannot decrypt your synced API keys or settings.',
          ),
        ],
      ],
    ),
  );

  Future<void> _prepareAccount() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_joinAccount &&
          (_accountNameController.text.trim().isEmpty ||
              _accountNameController.text.trim().length > 80)) {
        throw const FormatException(
          'Enter an account name of 80 characters or fewer.',
        );
      }
      final client = ref.read(accountSyncClientProvider);
      final store = ref.read(credentialStoreProvider);
      final baseUrl = _relayUrlController.text.trim();
      final account = _joinAccount
          ? await client.joinAccount(
              baseUrl: baseUrl,
              recoveryCode: _accountCodeController.text,
              store: store,
            )
          : await client.createAccount(
              baseUrl: baseUrl,
              setupToken: _relayTokenController.text.trim(),
              store: store,
            );
      ref.invalidate(syncAccountProvider);
      if (_joinAccount) {
        await ref
            .read(deviceSyncServiceProvider)
            .restoreConfiguration(baseUrl: baseUrl);
      }
      final webhook = _joinAccount
          ? null
          : await client.webhookConfig(baseUrl: baseUrl, account: account);
      if (!mounted) return;
      setState(() {
        _syncAccount = account;
        _joinedExistingAccount = _joinAccount;
        _webhookConfig = webhook;
        if (_joinAccount) _page = 7;
      });
      if (_joinAccount) _pageController.jumpToPage(7);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _automation() => _StepBody(
    eyebrow: 'PREFERENCES',
    icon: Icons.settings_suggest_rounded,
    title: 'Choose how quietly it works.',
    description:
        'Successful automation stays out of your way. Reviews and failures remain visible and actionable.',
    child: Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: _notifications,
            onChanged: (value) => setState(() => _notifications = value),
            title: const Text('Problem and review notifications'),
            subtitle: const Text('Successful syncs remain silent.'),
          ),
          if (Platform.isWindows) ...[
            const Divider(),
            SwitchListTile.adaptive(
              value: _launchWithWindows,
              onChanged: (value) => setState(() => _launchWithWindows = value),
              title: const Text('Launch with Windows'),
              subtitle: const Text(
                'Start hidden in the system tray after login.',
              ),
            ),
          ],
          if (Platform.isAndroid) ...[
            const Divider(),
            SwitchListTile.adaptive(
              value: _backgroundMobile,
              onChanged: (value) => setState(() => _backgroundMobile = value),
              title: const Text('Background mobile sync'),
              subtitle: const Text(
                'Android may defer work to protect battery.',
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _ready() => _StepBody(
    eyebrow: 'READY',
    icon: Icons.check_circle_outline_rounded,
    title: 'Your study desk is ready.',
    description:
        'Finish setup and ClassSync will perform its first sync. Healthy runs stay quiet; anything uncertain waits for your review.',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _ReadyRow(
              Icons.mic_none_rounded,
              _joinedExistingAccount
                  ? 'Fireflies connections restored'
                  : 'Fireflies connection verified',
            ),
            const SizedBox(height: 12),
            _ReadyRow(
              Icons.auto_awesome_rounded,
              _joinedExistingAccount
                  ? 'Gemini configuration restored'
                  : 'Gemini model verified',
            ),
            const SizedBox(height: 12),
            const _ReadyRow(
              Icons.account_tree_outlined,
              'Notion databases mapped',
            ),
            const SizedBox(height: 12),
            const _ReadyRow(
              Icons.webhook_rounded,
              'This device can reach the relay',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            _ReadyRow(
              Icons.notifications_none_rounded,
              _notifications
                  ? 'Review and failure notifications enabled'
                  : 'Notifications disabled',
            ),
            const SizedBox(height: 12),
            const _ReadyRow(
              Icons.history_rounded,
              '48-hour recovery polling enabled',
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
          if (_firefliesController.text.trim().isEmpty ||
              _firefliesController.text.trim().length >
                  FirefliesConnection.maxApiKeyLength ||
              _firefliesNameController.text.trim().isEmpty ||
              _firefliesNameController.text.trim().length >
                  FirefliesConnection.maxNameLength) {
            throw const FormatException(
              'Enter a Fireflies API key and connection name.',
            );
          }
          await ref
              .read(firefliesClientProvider)
              .testConnection(_firefliesController.text.trim());
        case 2:
          if (_geminiController.text.trim().isEmpty ||
              _modelController.text.trim().isEmpty) {
            throw const FormatException('Enter Gemini API key and model.');
          }
          final selectedModel = await ref
              .read(geminiClientProvider)
              .testConnection(
                apiKey: _geminiController.text.trim(),
                model: _modelController.text.trim(),
              );
          _modelController.text = selectedModel;
        case 3:
          if (_dataSources.isEmpty) await _discoverNotion();
          if (_subjectsId == null || _summariesId == null) {
            throw const FormatException('Select both Notion databases.');
          }
          await ref
              .read(notionClientProvider)
              .validateDataSources(
                token: _notionController.text.trim(),
                subjectsDataSourceId: _subjectsId!,
                summariesDataSourceId: _summariesId!,
                metadataEnabled: _addMetadata,
              );
        case 4:
          final portalUser = _portalUsernameController.text.trim();
          final portalPassword = _portalPasswordController.text;
          if (portalUser.isNotEmpty || portalPassword.isNotEmpty) {
            if (portalUser.isEmpty || portalPassword.isEmpty) {
              throw const FormatException(
                'Enter both Portal fields, or leave both blank to skip.',
              );
            }
            await ref
                .read(academicHubActionsProvider)
                .connectPortal(username: portalUser, password: portalPassword);
          }
          final moodleUser = _moodleUsernameController.text.trim();
          final moodlePassword = _moodlePasswordController.text;
          if (moodleUser.isNotEmpty || moodlePassword.isNotEmpty) {
            if (moodleUser.isEmpty || moodlePassword.isEmpty) {
              throw const FormatException(
                'Enter both Moodle fields, or leave both blank to skip.',
              );
            }
            try {
              await ref
                  .read(academicHubActionsProvider)
                  .connectMoodle(
                    username: moodleUser,
                    password: moodlePassword,
                  );
            } finally {
              _moodlePasswordController.clear();
            }
          }
        case 5:
          if (_relayUrlController.text.trim().isEmpty ||
              _relayTokenController.text.trim().length < 32) {
            throw const FormatException(
              'Paste a device API token of at least 32 characters.',
            );
          }
          await ref
              .read(relayClientProvider)
              .testConnection(
                _relayUrlController.text.trim(),
                token: _relayTokenController.text.trim(),
              );
        case 6:
          if (_syncAccount == null ||
              (!_joinedExistingAccount && _webhookConfig == null)) {
            throw const FormatException(
              'Create or join your private ClassSync account first.',
            );
          }
        case 8:
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
      if (!mounted) return;
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
          'No Notion databases found. Share the ISEP page with the integration, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    final credentialStore = ref.read(credentialStoreProvider);
    final settingsController = ref.read(settingsControllerProvider);
    final notificationService = ref.read(notificationServiceProvider);
    final syncController = ref.read(syncControllerProvider.notifier);
    final notionToken = _notionController.text.trim();
    if (_addMetadata && !_joinedExistingAccount) {
      await ref
          .read(notionClientProvider)
          .addFirefliesIdProperty(
            token: notionToken,
            summariesDataSourceId: _summariesId!,
          );
    }
    if (!_joinedExistingAccount) {
      await credentialStore.writeAll({
        CredentialKey.relayDeviceToken: _relayTokenController.text.trim(),
        CredentialKey.geminiApiKey: _geminiController.text.trim(),
        CredentialKey.notionToken: notionToken,
      });
      await credentialStore.writeFirefliesConnections([
        FirefliesConnection(
          id: _primaryFirefliesId,
          name: _firefliesNameController.text.trim(),
          apiKey: _firefliesController.text.trim(),
        ),
      ]);
    }
    final restored = _joinedExistingAccount
        ? await ref.read(databaseProvider).readSettings()
        : AppSettings.defaults;
    final settings = restored.copyWith(
      displayName: _joinedExistingAccount
          ? restored.displayName
          : _accountNameController.text.trim(),
      setupComplete: true,
      launchWithWindows: _launchWithWindows,
      backgroundMobileSync: _backgroundMobile,
      notificationsEnabled: _notifications,
      classificationModel: _joinedExistingAccount
          ? restored.classificationModel
          : _modelController.text.trim(),
      summaryModel: _joinedExistingAccount
          ? restored.summaryModel
          : _modelController.text.trim(),
      notionMetadataEnabled: _joinedExistingAccount
          ? restored.notionMetadataEnabled
          : _addMetadata,
      notionSubjectsDataSourceId: _joinedExistingAccount
          ? restored.notionSubjectsDataSourceId
          : _subjectsId,
      notionSummariesDataSourceId: _joinedExistingAccount
          ? restored.notionSummariesDataSourceId
          : _summariesId,
      relayBaseUrl: _relayUrlController.text.trim(),
    );
    if (_notifications) {
      await notificationService.requestPermissions();
    }
    await configureMobileBackgroundSync(settings);
    await settingsController.save(settings);
    ref.invalidate(syncAccountProvider);
    ref.invalidate(firefliesConnectionsProvider);
    ref.invalidate(academicConnectionStateProvider);
    for (final key in CredentialKey.values) {
      ref.invalidate(credentialConfiguredProvider(key));
    }
    unawaited(syncController.run(SyncReason.manual));
  }

  void _back() {
    if (_page == 0) return;
    setState(() {
      _error = null;
      if (_recoveryEntry && _page == 6) {
        _page = 0;
        _recoveryEntry = false;
        _joinAccount = false;
      } else {
        _page = _flow[_flow.indexOf(_page) - 1];
      }
    });
    _pageController.animateToPage(
      _page,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
}

class _StepDefinition {
  const _StepDefinition(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _SetupRail extends StatelessWidget {
  const _SetupRail({required this.current, required this.steps});
  final int current;
  final List<_StepDefinition> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 24, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ClassSync',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              'SETUP SYLLABUS',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < steps.length; index++)
              _RailStep(
                step: steps[index],
                index: index,
                current: current,
                last: index == steps.length - 1,
              ),
            const Spacer(),
            Icon(Icons.lock_outline_rounded, color: scheme.onPrimary),
            const SizedBox(height: 10),
            Text(
              'Private by design',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Credentials stay in secure storage on this device.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailStep extends StatelessWidget {
  const _RailStep({
    required this.step,
    required this.index,
    required this.current,
    required this.last,
  });
  final _StepDefinition step;
  final int index;
  final int current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = index == current;
    final complete = index < current;
    final foreground = scheme.onPrimary;
    return Semantics(
      label:
          'Step ${index + 1}, ${step.label}, ${complete
              ? 'completed'
              : selected
              ? 'current'
              : 'upcoming'}',
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 48,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (!last)
                    Positioned(
                      top: 24,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: foreground.withValues(alpha: 0.24),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.secondary
                          : complete
                          ? foreground
                          : scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: foreground.withValues(
                          alpha: complete ? 1 : 0.55,
                        ),
                        width: 2,
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 26,
                      child: Icon(
                        complete ? Icons.check_rounded : step.icon,
                        size: 14,
                        color: complete
                            ? scheme.primary
                            : selected
                            ? scheme.onSecondary
                            : foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                step.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground.withValues(alpha: selected ? 1 : 0.72),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({
    required this.current,
    required this.total,
    required this.compact,
  });
  final int current;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            if (compact) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 20,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('ClassSync', style: Theme.of(context).textTheme.titleLarge),
            ] else
              Text(
                'SETUP IN PROGRESS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const Spacer(),
            Text(
              '${current + 1} / $total',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (current + 1) / total,
            minHeight: 5,
            backgroundColor: scheme.surfaceContainer,
            color: scheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _SetupFooter extends StatelessWidget {
  const _SetupFooter({
    required this.page,
    required this.busy,
    required this.onBack,
    required this.onNext,
  });
  final int page;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = switch (page) {
      0 => 'Start setup',
      >= 1 && <= 3 => 'Test & continue',
      4 => 'Save or skip',
      5 => 'Test & continue',
      6 => 'Review setup',
      7 => 'Continue',
      _ => 'Finish setup',
    };
    return Row(
      children: [
        if (page > 0)
          TextButton.icon(
            onPressed: busy ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back'),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: busy ? null : onNext,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      page == 8
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
              label: Text(label),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.eyebrow,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });
  final String eyebrow;
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: scheme.onSecondaryContainer),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  eyebrow,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 26),
                child,
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            for (var index = 0; index < items.length; index++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 26,
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Text(items[index])),
                ],
              ),
              if (index < items.length - 1) const SizedBox(height: 11),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: scheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    required this.label,
    required this.hint,
  });
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: _obscure,
    enableSuggestions: false,
    autocorrect: false,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.key_rounded),
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        tooltip: _obscure ? 'Show credential' : 'Hide credential',
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      Icon(
        Icons.check_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
    ],
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
