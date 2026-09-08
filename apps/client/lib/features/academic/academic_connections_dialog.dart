import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/academic/academic_hub_actions.dart';

Future<void> showAcademicConnectionsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final connections = await ref.read(academicConnectionStateProvider.future);
  final username = await ref
      .read(academicHubActionsProvider)
      .readPortalUsername();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _AcademicConnectionsDialog(
      initialUsername: username,
      portalConfigured: connections.portalConfigured,
      moodleConfigured: connections.moodleConfigured,
    ),
  );
}

class _AcademicConnectionsDialog extends ConsumerStatefulWidget {
  const _AcademicConnectionsDialog({
    required this.initialUsername,
    required this.portalConfigured,
    required this.moodleConfigured,
  });

  final String initialUsername;
  final bool portalConfigured;
  final bool moodleConfigured;

  @override
  ConsumerState<_AcademicConnectionsDialog> createState() =>
      _AcademicConnectionsDialogState();
}

class _AcademicConnectionsDialogState
    extends ConsumerState<_AcademicConnectionsDialog> {
  late final _username = TextEditingController(text: widget.initialUsername);
  final _password = TextEditingController();
  final _otherUsername = TextEditingController();
  final _otherPassword = TextEditingController();
  late bool _portalConfigured = widget.portalConfigured;
  late bool _moodleConfigured = widget.moodleConfigured;
  bool _busy = false;
  String? _portalError;
  String? _moodleError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _otherUsername.dispose();
    _otherPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ISEP connection'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One institutional login connects Portal and Moodle. Each service keeps its own connection status.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _username,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'ISEP username or email',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _portalConfigured
                    ? 'Leave blank to reuse the password securely saved on this device.'
                    : 'Portal password and Moodle token stay in OS secure storage.',
              ),
            ),
            const SizedBox(height: 20),
            _ConnectionPanel(
              icon: Icons.account_balance_outlined,
              title: 'Portal',
              configured: _portalConfigured,
              error: _portalError,
              children: const [],
            ),
            const SizedBox(height: 8),
            _ConnectionPanel(
              icon: Icons.school_outlined,
              title: 'Moodle',
              configured: _moodleConfigured,
              error: _moodleError,
              children: const [],
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Different Moodle account'),
              subtitle: const Text(
                'For external accounts or a separate Moodle identity',
              ),
              children: [
                TextField(
                  controller: _otherUsername,
                  enabled: !_busy,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Moodle username',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otherPassword,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Moodle password',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _connect(separate: true),
                  child: const Text('Connect this Moodle account'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : () => _connect(),
        icon: _busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.link),
        label: Text(_busy ? 'Connecting…' : 'Connect Portal and Moodle'),
      ),
    ],
  );

  Future<void> _connect({bool separate = false}) async {
    setState(() {
      _busy = true;
      _portalError = null;
      _moodleError = null;
    });
    final actions = ref.read(academicHubActionsProvider);
    var connected = false;
    try {
      if (!separate) {
        try {
          await actions.connectPortal(
            username: _username.text,
            password: _password.text.isEmpty ? null : _password.text,
          );
          connected = true;
          if (mounted) setState(() => _portalConfigured = true);
        } on AcademicActionFailure catch (error) {
          if (mounted) setState(() => _portalError = error.message);
        }
      }
      try {
        if (separate && _otherPassword.text.isEmpty) {
          throw const AcademicActionFailure(
            'Enter the separate Moodle password.',
          );
        }
        await actions.connectMoodle(
          username: separate ? _otherUsername.text : _username.text,
          password: separate ? _otherPassword.text : _password.text,
        );
        connected = true;
        if (mounted) setState(() => _moodleConfigured = true);
      } on AcademicActionFailure catch (error) {
        if (mounted) setState(() => _moodleError = error.message);
      }
      ref.invalidate(academicConnectionStateProvider);
      // Newly connected sources load through the shared academic service.
      if (connected) {
        ref.read(academicSyncServiceProvider).synchronize();
      }
    } finally {
      _password.clear();
      _otherPassword.clear();
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.icon,
    required this.title,
    required this.configured,
    required this.children,
    this.error,
  });

  final IconData icon;
  final String title;
  final bool configured;
  final String? error;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  configured ? 'Connected' : 'Not configured',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: configured
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
