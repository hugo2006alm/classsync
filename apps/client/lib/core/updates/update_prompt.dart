import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/secure_credential_store.dart';
import 'release_update_service.dart';

bool _checking = false;

Future<void> checkForUpdates(
  BuildContext context, {
  required SecureCredentialStore credentials,
  bool silent = false,
}) async {
  if (_checking) return;
  _checking = true;
  try {
    final token = await credentials.read(CredentialKey.githubReleaseToken);
    final service = ReleaseUpdateService(token: token);
    final update = await service.check();
    if (!context.mounted) return;
    if (update == null) {
      if (!silent) _message(context, 'ClassSync is up to date.');
      return;
    }
    final install = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ClassSync ${update.version} is available'),
        content: Text(
          Platform.isAndroid
              ? 'Download the verified APK and open Android’s installer? Android will ask you to confirm the update.'
              : 'Download the verified Windows installer and start the update? ClassSync may close and reopen during installation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Download and update'),
          ),
        ],
      ),
    );
    if (install != true || !context.mounted) return;
    final progress = ValueNotifier<double>(0);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Downloading update'),
            content: SizedBox(
              width: 340,
              child: ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (context, value, child) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: value),
                    const SizedBox(height: 12),
                    Text('${(value * 100).round()}% · verifying checksum'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    var loadingOpen = true;
    try {
      final file = await service.download(
        update,
        onProgress: (received, total) {
          progress.value = received / total;
        },
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      loadingOpen = false;
      if (Platform.isAndroid) {
        await const MethodChannel(
          'classsync/updates',
        ).invokeMethod<void>('installApk', file.path);
      } else if (Platform.isWindows) {
        await Process.start(file.path, const [
          '/SILENT',
          '/CLOSEAPPLICATIONS',
          '/RESTARTAPPLICATIONS',
        ], mode: ProcessStartMode.detached);
      }
    } catch (_) {
      if (context.mounted) {
        if (loadingOpen) Navigator.of(context, rootNavigator: true).pop();
        _message(context, 'Update download or installation failed. Try again.');
      }
    } finally {
      progress.dispose();
    }
  } catch (_) {
    if (context.mounted && !silent) {
      _message(
        context,
        'Could not check GitHub releases. Check your connection and try again.',
      );
    }
  } finally {
    _checking = false;
  }
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
