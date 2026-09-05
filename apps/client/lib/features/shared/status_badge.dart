import 'package:flutter/material.dart';

import '../../domain/sync/sync_models.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final SyncJobStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (status) {
      SyncJobStatus.success => (
        'Completed',
        scheme.primary,
        Icons.check_circle_rounded,
      ),
      SyncJobStatus.needsReview => (
        'Needs review',
        scheme.tertiary,
        Icons.help_rounded,
      ),
      SyncJobStatus.failedRetryable || SyncJobStatus.failedTerminal => (
        'Failed',
        scheme.error,
        Icons.error_rounded,
      ),
      SyncJobStatus.ignored => ('Ignored', scheme.outline, Icons.block_rounded),
      SyncJobStatus.duplicate => (
        'Duplicate',
        scheme.secondary,
        Icons.copy_rounded,
      ),
      _ when status.isProcessing => (
        'Processing',
        scheme.primary,
        Icons.autorenew_rounded,
      ),
      _ => ('Pending', scheme.secondary, Icons.schedule_rounded),
    };
    return Semantics(
      label: 'Status: $label',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
