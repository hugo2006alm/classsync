import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../domain/academic/academic_models.dart';
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

    return PageFrame(
      title: '${_greeting()}, ClassSync',
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
          _SyncHealthCard(
            attention: attention,
            failures: failures,
            pending: pending,
            state: syncState,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 4 ? 2.1 : 2.4,
                children: [
                  MetricCard(
                    label: 'Active classes',
                    value: '${subjects.length}',
                    icon: Icons.school_rounded,
                  ),
                  MetricCard(
                    label: 'Pending',
                    value: '$pending',
                    icon: Icons.schedule_rounded,
                  ),
                  MetricCard(
                    label: 'Processing',
                    value: '$processing',
                    icon: Icons.autorenew_rounded,
                  ),
                  MetricCard(
                    label: 'Needs attention',
                    value: '${attention + failures}',
                    icon: Icons.notifications_active_rounded,
                    emphasis: attention + failures > 0,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final classes = _ActiveClasses(subjects: subjects);
              final summaries = _RecentSummaries(jobs: recent);
              if (!wide) {
                return Column(
                  children: [classes, const SizedBox(height: 28), summaries],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: classes),
                  const SizedBox(width: 20),
                  Expanded(child: summaries),
                ],
              );
            },
          ),
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

class _ActiveClasses extends StatelessWidget {
  const _ActiveClasses({required this.subjects});
  final List<AcademicSubject> subjects;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(
        'Active classes',
        action: TextButton(
          onPressed: () => context.go('/classes'),
          child: const Text('View all'),
        ),
      ),
      if (subjects.isEmpty)
        const EmptyState(
          icon: Icons.school_outlined,
          title: 'No active classes cached',
          message:
              'Run Sync now to fetch classes marked In progress in Notion.',
        )
      else
        Card(
          child: Column(
            children: [
              for (var index = 0; index < subjects.take(5).length; index++) ...[
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.book_outlined)),
                  title: Text(subjects[index].name),
                  subtitle: Text(subjects[index].semesterLabel),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.go('/classes/${subjects[index].notionId}'),
                ),
                if (index < subjects.take(5).length - 1) const Divider(),
              ],
            ],
          ),
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
