import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../domain/academic/academic_hub_models.dart';
import '../../domain/academic/academic_models.dart';
import '../../domain/academic/next_class.dart';
import '../../domain/sync/sync_coordinator.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/page_frame.dart';
import '../shared/status_badge.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(activeSubjectsProvider).valueOrNull ?? const [];
    final jobs = ref.watch(syncJobsProvider).valueOrNull ?? const [];
    final academicRecords =
        ref.watch(academicRecordsProvider).valueOrNull ?? const [];
    final displayName = ref
        .watch(settingsProvider)
        .valueOrNull
        ?.displayName
        .trim();
    final syncState = ref.watch(syncControllerProvider);
    final semester = AcademicSemester.derive(subjects);
    final pending = jobs
        .where((job) => !job.status.isTerminal && !job.status.isProcessing)
        .length;
    final processing = jobs.where((job) => job.status.isProcessing).length;
    final attention = jobs
        .where((job) => job.status == SyncJobStatus.needsReview)
        .length;
    final failures = jobs
        .where(
          (job) =>
              job.status == SyncJobStatus.failedRetryable ||
              job.status == SyncJobStatus.failedTerminal,
        )
        .length;
    final recent = jobs
        .where((job) => job.status == SyncJobStatus.success)
        .take(5)
        .toList();
    final nextClass = nextUpcomingClass(academicRecords, DateTime.now());
    final showSyncHealth =
        attention + failures > 0 || syncState.isLoading || syncState.hasError;

    return PageFrame(
      title:
          '${_greeting()}, ${displayName?.isNotEmpty == true ? displayName : 'ClassSync'}',
      subtitle: semester?.label ?? 'University overview',
      actions: [
        FilledButton.icon(
          onPressed: syncState.isLoading
              ? null
              : () => ref
                    .read(syncControllerProvider.notifier)
                    .run(SyncReason.manual),
          icon: syncState.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          label: const Text('Sync now'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nextClass != null) ...[
            _NextClassCard(slot: nextClass),
            const SizedBox(height: 20),
          ],
          if (showSyncHealth) ...[
            _SyncHealthCard(
              attention: attention,
              failures: failures,
              pending: pending,
              state: syncState,
            ),
            const SizedBox(height: 20),
          ],
          _GeneralInfo(
            activeClasses: subjects.length,
            pending: pending,
            processing: processing,
            needsAttention: attention + failures,
          ),
          const SizedBox(height: 28),
          _RecentSummaries(jobs: recent),
        ],
      ),
    );
  }
}

class _SyncHealthCard extends StatelessWidget {
  const _SyncHealthCard({
    required this.attention,
    required this.failures,
    required this.pending,
    required this.state,
  });
  final int attention;
  final int failures;
  final int pending;
  final AsyncValue<SyncRunResult?> state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasIssue = attention + failures > 0;
    final title = state.isLoading
        ? 'Syncing lectures'
        : hasIssue
        ? '${attention + failures} items need attention'
        : pending > 0
        ? '$pending transcripts waiting'
        : 'All caught up';
    final message = state.when(
      loading: () => 'Checking relay, Fireflies, and local queue.',
      error: (error, stack) => error.toString(),
      data: (result) => result == null
          ? 'ClassSync will stay quiet while everything is healthy.'
          : '${result.discovered} discovered · ${result.processed} processed · ${result.failed} failed',
    );
    return Card(
      color: hasIssue ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Icon(
              hasIssue
                  ? Icons.notifications_active_rounded
                  : Icons.check_circle_rounded,
              size: 34,
              color: hasIssue
                  ? scheme.onErrorContainer
                  : scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.slot});

  final TimetableSlot slot;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (slot.lessonType?.trim().isNotEmpty == true) slot.lessonType!,
      if (slot.className?.trim().isNotEmpty == true) slot.className!,
      if (slot.room?.trim().isNotEmpty == true) 'Room ${slot.room!}',
      if (slot.lecturer?.trim().isNotEmpty == true) 'Teacher ${slot.lecturer!}',
    ];
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/academic?section=0'),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.event_available_rounded, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next class',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slot.subjectName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${DateFormat.EEEE().add_MMMd().format(slot.start.toLocal())} · ${DateFormat.Hm().format(slot.start.toLocal())}–${DateFormat.Hm().format(slot.end.toLocal())}',
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(details.join(' · ')),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneralInfo extends StatelessWidget {
  const _GeneralInfo({
    required this.activeClasses,
    required this.pending,
    required this.processing,
    required this.needsAttention,
  });

  final int activeClasses;
  final int pending;
  final int processing;
  final int needsAttention;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader('General'),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Wrap(
            spacing: 22,
            runSpacing: 12,
            children: [
              _CompactMetric(
                icon: Icons.school_outlined,
                label:
                    '$activeClasses active ${activeClasses == 1 ? 'class' : 'classes'}',
              ),
              if (pending > 0)
                _CompactMetric(
                  icon: Icons.schedule_rounded,
                  label: '$pending pending',
                ),
              if (processing > 0)
                _CompactMetric(
                  icon: Icons.autorenew_rounded,
                  label: '$processing processing',
                ),
              _CompactMetric(
                icon: needsAttention > 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                label: needsAttention > 0
                    ? '$needsAttention need attention'
                    : 'Sync healthy',
                color: needsAttention > 0
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 19, color: color),
      const SizedBox(width: 7),
      Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      ),
    ],
  );
}

class _RecentSummaries extends StatelessWidget {
  const _RecentSummaries({required this.jobs});
  final List<SyncJob> jobs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(
        'Recent summaries',
        action: TextButton(
          onPressed: () => context.go('/sync'),
          child: const Text('View sync'),
        ),
      ),
      if (jobs.isEmpty)
        const EmptyState(
          icon: Icons.auto_stories_outlined,
          title: 'No summaries yet',
          message: 'Completed lecture summaries will appear here.',
        )
      else
        Card(
          child: Column(
            children: [
              for (var index = 0; index < jobs.length; index++) ...[
                ListTile(
                  title: Text(jobs[index].summaryTitle ?? jobs[index].title),
                  subtitle: Text(
                    '${jobs[index].subjectName ?? 'Unclassified'} · ${DateFormat.MMMd().format(jobs[index].meetingDate.toLocal())}',
                  ),
                  trailing: StatusBadge(jobs[index].status),
                  onTap: () => context.go('/sync/${jobs[index].id}'),
                ),
                if (index < jobs.length - 1) const Divider(),
              ],
            ],
          ),
        ),
    ],
  );
}

String _greeting() => switch (DateTime.now().hour) {
  < 12 => 'Good morning',
  < 18 => 'Good afternoon',
  _ => 'Good evening',
};
