import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/integrations/relay/account_sync_client.dart';
import '../../core/providers.dart';
import '../../core/security/secure_credential_store.dart';
import '../../domain/settings/app_settings.dart';

class DeviceSyncSettings extends ConsumerStatefulWidget {
  const DeviceSyncSettings({required this.settings, super.key});
  final AppSettings settings;

  @override
  ConsumerState<DeviceSyncSettings> createState() => _DeviceSyncSettingsState();
}

class _DeviceSyncSettingsState extends ConsumerState<DeviceSyncSettings> {
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final accountValue = ref.watch(syncAccountProvider);
    return accountValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text(error.toString()),
      data: (account) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: account == null
                  ? _disconnected(context)
                  : _connected(context, account),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 18),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What follows you'),
                  SizedBox(height: 8),
                  Text(
                    'Fireflies, Gemini, and Notion keys; Notion database mappings; AI preferences; and lecture job status.',
                  ),
                  SizedBox(height: 14),
                  Text('What stays on this device'),
                  SizedBox(height: 8),
                  Text(
                    'Windows launch behavior, Android background behavior, notifications, cached transcripts, and full generated content.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _disconnected(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'No ClassSync account',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Create one for your devices, or join one with its recovery code. Each person should create a different account.',
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create my account'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _join,
            icon: const Icon(Icons.devices_rounded),
            label: const Text('Join with a code'),
          ),
        ],
      ),
    ],
  );

  Widget _connected(BuildContext context, SyncAccount account) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const CircleAvatar(child: Icon(Icons.lock_rounded)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private device account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Connected · ${account.id.substring(0, 8)}'),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'The relay stores encrypted snapshots. Keep the recovery code private: it can join another device and decrypt your keys.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _sync,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Sync devices now'),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _copy(account.recoveryCode, 'Recovery code copied.'),
            icon: const Icon(Icons.key_rounded),
            label: const Text('Copy recovery code'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _showWebhook(account),
            icon: const Icon(Icons.webhook_rounded),
            label: const Text('Fireflies webhook'),
          ),
          TextButton(
            onPressed: _busy ? null : _disconnect,
            child: const Text('Disconnect this device'),
          ),
        ],
      ),
    ],
  );

  Future<void> _create() async {
    await _run(() async {
      final store = ref.read(credentialStoreProvider);
      final setupToken = await store.read(CredentialKey.relayDeviceToken);
      if (setupToken == null || setupToken.isEmpty) {
        throw StateError('Configure the ClassSync Relay setup token first.');
      }
      final account = await ref
          .read(accountSyncClientProvider)
          .createAccount(
            baseUrl:
                widget.settings.relayBaseUrl ??
                AppSettings.productionRelayBaseUrl,
            setupToken: setupToken,
            store: store,
          );
      await ref
          .read(deviceSyncServiceProvider)
          .synchronize(pushConfiguration: true);
      await ref.read(settingsControllerProvider).save(widget.settings);
      ref.invalidate(syncAccountProvider);
      await _copy(
        account.recoveryCode,
        'Account created and recovery code copied. Save it securely.',
      );
    });
  }

  Future<void> _join() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join your ClassSync account'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Recovery code',
            hintText: 'CS1.…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;
    await _run(() async {
      await ref
          .read(accountSyncClientProvider)
          .joinAccount(
            baseUrl:
                widget.settings.relayBaseUrl ??
                AppSettings.productionRelayBaseUrl,
            recoveryCode: code,
            store: ref.read(credentialStoreProvider),
          );
      await ref.read(deviceSyncServiceProvider).synchronize();
      ref.invalidate(syncAccountProvider);
      for (final key in CredentialKey.values) {
        ref.invalidate(credentialConfiguredProvider(key));
      }
      setState(() => _message = 'Device joined and private settings restored.');
    });
  }

  Future<void> _sync() => _run(() async {
    await ref.read(deviceSyncServiceProvider).synchronize();
    for (final key in CredentialKey.values) {
      ref.invalidate(credentialConfiguredProvider(key));
    }
    setState(() => _message = 'Devices are up to date.');
  });

  Future<void> _showWebhook(SyncAccount account) async {
    await _run(() async {
      final config = await ref
          .read(accountSyncClientProvider)
          .webhookConfig(
            baseUrl:
                widget.settings.relayBaseUrl ??
                AppSettings.productionRelayBaseUrl,
            account: account,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your Fireflies webhook'),
          content: SelectableText(
            'URL\n${config.webhookUrl}\n\nSigning secret\n${config.signingSecret}',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  _copy(config.signingSecret, 'Signing secret copied.'),
              child: const Text('Copy secret'),
            ),
            TextButton(
              onPressed: () => _copy(config.webhookUrl, 'Webhook URL copied.'),
              child: const Text('Copy URL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _disconnect() => _run(() async {
    await ref
        .read(accountSyncClientProvider)
        .disconnect(ref.read(credentialStoreProvider));
    ref.invalidate(syncAccountProvider);
    setState(
      () => _message = 'This device is disconnected. Local data remains.',
    );
  });

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) setState(() => _message = message);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
