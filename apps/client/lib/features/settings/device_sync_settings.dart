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
                    'Fireflies sources; Gemini and Notion keys; Notion mappings; Moodle token; Portal login; AI preferences; and lecture job status.',
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
                  widget.settings.displayName.trim().isEmpty
                      ? 'Private device account'
                      : widget.settings.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('ClassSync account · ${account.id.substring(0, 8)}'),
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
            onPressed: _busy ? null : _editName,
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Edit name'),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _copy(account.recoveryCode, 'Recovery code copied.'),
            icon: const Icon(Icons.key_rounded),
            label: const Text('Copy recovery code'),
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
    final name = await _requestName();
    if (name == null) return;
    final setupToken = await _requestBootstrapToken();
    if (setupToken == null) return;
    await _run(() async {
      final store = ref.read(credentialStoreProvider);
      final account = await ref
          .read(accountSyncClientProvider)
          .createAccount(
            baseUrl:
                widget.settings.relayBaseUrl ??
                AppSettings.productionRelayBaseUrl,
            setupToken: setupToken,
            store: store,
          );
      ref.invalidate(syncAccountProvider);
      await ref
          .read(settingsControllerProvider)
          .save(widget.settings.copyWith(displayName: name));
      await ref
          .read(deviceSyncServiceProvider)
          .synchronize(pushConfiguration: true);
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
      ref.invalidate(syncAccountProvider);
      try {
        await ref.read(deviceSyncServiceProvider).synchronize();
      } catch (error) {
        for (final key in CredentialKey.values) {
          ref.invalidate(credentialConfiguredProvider(key));
        }
        ref.invalidate(firefliesConnectionsProvider);
        setState(
          () => _message =
              'Account joined. Private settings will retry syncing: $error',
        );
        return;
      }
      for (final key in CredentialKey.values) {
        ref.invalidate(credentialConfiguredProvider(key));
      }
      ref.invalidate(firefliesConnectionsProvider);
      setState(() => _message = 'Device joined and private settings restored.');
    });
  }

  Future<void> _sync() => _run(() async {
    await ref.read(deviceSyncServiceProvider).synchronize();
    ref.invalidate(syncAccountProvider);
    for (final key in CredentialKey.values) {
      ref.invalidate(credentialConfiguredProvider(key));
    }
    ref.invalidate(firefliesConnectionsProvider);
    setState(() => _message = 'Devices are up to date.');
  });

  Future<void> _disconnect() => _run(() async {
    await ref
        .read(accountSyncClientProvider)
        .disconnect(ref.read(credentialStoreProvider));
    ref.invalidate(syncAccountProvider);
    setState(
      () => _message = 'This device is disconnected. Local data remains.',
    );
  });

  Future<void> _editName() async {
    final name = await _requestName(current: widget.settings.displayName);
    if (name == null) return;
    await _run(() async {
      await ref
          .read(settingsControllerProvider)
          .save(widget.settings.copyWith(displayName: name));
      setState(() => _message = 'Account name updated.');
    });
  }

  Future<String?> _requestName({String current = ''}) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'Shown on Overview and your devices',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return null;
    if (value.isEmpty) {
      setState(() => _message = 'Account name cannot be empty.');
      return null;
    }
    return value;
  }

  Future<String?> _requestBootstrapToken() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create ClassSync account'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Device API token',
            helperText:
                'Bootstrap credential used once for account creation. It is not saved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final token = controller.text.trim();
              if (token.length >= 32) Navigator.pop(context, token);
            },
            child: const Text('Create account'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

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
