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
  late final TextEditingController _username;
  final _password = TextEditingController();
  final _moodleToken = TextEditingController();
  late bool _portalConfigured = widget.portalConfigured;
  late bool _moodleConfigured = widget.moodleConfigured;
  bool _portalBusy = false;
  bool _moodleBusy = false;
  String? _portalError;
  String? _moodleError;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _moodleToken.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Academic connections'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConnectionPanel(
              icon: Icons.account_balance_outlined,
              title: 'ISEP Portal',
              configured: _portalConfigured,
              error: _portalError,
              children: [
                TextField(
                  controller: _username,
                  enabled: !_portalBusy,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Portal username or ISEP email',
                    helperText:
                        'Use exactly the username or email accepted by portal.isep.ipp.pt.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_portalBusy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: _portalConfigured
                        ? 'Leave blank to keep the password stored on this device.'
                        : 'Required on first connection. Stored in OS secure storage.',
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _portalBusy ? null : _savePortal,
                    icon: _portalBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(
                      _portalBusy ? 'Testing…' : 'Test and save Portal',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ConnectionPanel(
              icon: Icons.school_outlined,
              title: 'Moodle ISEP',
              configured: _moodleConfigured,
              error: _moodleError,
              children: [
                TextField(
                  controller: _moodleToken,
                  enabled: !_moodleBusy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Web Services token',
                    helperText:
                        'Moodle is independent from Portal. Only this token is required.',
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _moodleBusy ? null : _saveMoodle,
                    icon: _moodleBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(
                      _moodleBusy ? 'Testing…' : 'Test and save Moodle',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _portalBusy || _moodleBusy
            ? null
            : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );

  Future<void> _savePortal() async {
    setState(() {
      _portalBusy = true;
      _portalError = null;
    });
    try {
      await ref
          .read(academicHubActionsProvider)
          .connectPortal(
            username: _username.text,
            password: _password.text.isEmpty ? null : _password.text,
          );
      if (!mounted) return;
      _password.clear();
      setState(() => _portalConfigured = true);
      ref.invalidate(academicConnectionStateProvider);
      _showSuccess('ISEP Portal connected.');
    } on AcademicActionFailure catch (error) {
      if (mounted) setState(() => _portalError = error.message);
    } finally {
      if (mounted) setState(() => _portalBusy = false);
    }
  }

  Future<void> _saveMoodle() async {
    setState(() {
      _moodleBusy = true;
      _moodleError = null;
    });
    try {
      await ref
          .read(academicHubActionsProvider)
          .connectMoodle(_moodleToken.text);
      if (!mounted) return;
      _moodleToken.clear();
      setState(() => _moodleConfigured = true);
      ref.invalidate(academicConnectionStateProvider);
      _showSuccess('Moodle connected.');
    } on AcademicActionFailure catch (error) {
      if (mounted) setState(() => _moodleError = error.message);
    } finally {
      if (mounted) setState(() => _moodleBusy = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
