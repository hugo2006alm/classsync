import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/integrations/integration_exception.dart';
import '../../core/providers.dart';
import '../../domain/sync/sync_models.dart';
import '../library/library_location.dart';

String? recordingLibraryLocation(SyncJob job) {
  final pageId = job.notionPageId?.trim();
  if (pageId == null || pageId.isEmpty) return null;
  return libraryLocation(
    pageId,
    title: job.summaryTitle ?? job.title,
    url: job.notionUrl,
  );
}

Widget discardRecordingLabel(BuildContext context) {
  final color = Theme.of(context).colorScheme.error;
  return Row(
    children: [
      Icon(Icons.delete_outline_rounded, color: color),
      const SizedBox(width: 8),
      Text('Discard transcript', style: TextStyle(color: color)),
    ],
  );
}

Future<bool> confirmDiscardRecording(
  BuildContext context,
  WidgetRef ref,
  SyncJob job,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text('Discard transcript?'),
        content: Text(
          '“${job.title}” will leave Recordings. ClassSync will clear its '
          'cached transcript and partial summaries, remove derived lecture '
          'tasks, and keep a record to prevent rediscovery. '
          'The original recording stays in Fireflies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return false;
  String message;
  var discarded = false;
  try {
    await ref.read(syncCoordinatorProvider).discardJob(job.id);
    discarded = true;
    message = 'Transcript discarded.';
  } on IntegrationException catch (error) {
    message = error.userMessage;
  } catch (_) {
    message = 'Could not discard the transcript. Try again.';
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
  return discarded;
}
