import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/page_frame.dart';
import '../shared/status_badge.dart';

enum _JobFilter { all, pending, processing, review, completed, failed, ignored }

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  _JobFilter _filter = _JobFilter.all;

  @override
  Widget build(BuildContext context) {
    final jobsValue = ref.watch(syncJobsProvider);
    final syncState = ref.watch(syncControllerProvider);
    return PageFrame(
      title: 'Sync',
      subtitle: 'Lecture processing queue and history',
      actions: [
        OutlinedButton.icon(
          onPressed: () => _showManualImport(context),
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Import transcript'),
        ),
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
      child: jobsValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load sync queue',
          message: error.toString(),
        ),
        data: (jobs) {
          final filtered = jobs.where(_matchesFilter).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _JobFilter.values
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_filterLabel(filter)),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              if (syncState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MaterialBanner(
                    content: Text(syncState.error.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => ref
                            .read(syncControllerProvider.notifier)
                            .run(SyncReason.manual),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (filtered.isEmpty)
                EmptyState(
                  icon: jobs.isEmpty
                      ? Icons.inbox_outlined
                      : Icons.filter_alt_off_rounded,
                  title: jobs.isEmpty
                      ? 'No transcripts discovered yet'
                      : 'No matching jobs',
                  message: jobs.isEmpty
                      ? 'Sync now checks the relay and Fireflies recovery range.'
                      : 'Choose another status filter.',
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var index = 0; index < filtered.length; index++) ...[
                        _JobRow(job: filtered[index]),
                        if (index < filtered.length - 1) const Divider(),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilter(SyncJob job) => switch (_filter) {
    _JobFilter.all => true,
    _JobFilter.pending =>
      job.status == SyncJobStatus.discovered ||
          job.status == SyncJobStatus.queued,
    _JobFilter.processing => job.status.isProcessing,
    _JobFilter.review => job.status == SyncJobStatus.needsReview,
    _JobFilter.completed =>
      job.status == SyncJobStatus.success ||
          job.status == SyncJobStatus.duplicate,
    _JobFilter.failed =>
      job.status == SyncJobStatus.failedRetryable ||
          job.status == SyncJobStatus.failedTerminal,
    _JobFilter.ignored => job.status == SyncJobStatus.ignored,
  };

  Future<void> _showManualImport(BuildContext context) async {
    final titleController = TextEditingController();
    final transcriptController = TextEditingController();
    final jobId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import transcript'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Lecture title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: transcriptController,
                  minLines: 8,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: 'Transcript',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (transcriptController.text.trim().isEmpty) return;
              final id = await ref
                  .read(syncCoordinatorProvider)
                  .importTranscript(
                    title: titleController.text,
                    transcriptText: transcriptController.text,
                  );
              if (context.mounted) Navigator.pop(context, id);
            },
            child: const Text('Queue import'),
          ),
        ],
      ),
    );
    titleController.dispose();
    transcriptController.dispose();
    if (jobId != null && mounted) this.context.go('/sync/$jobId');
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});
  final SyncJob job;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go('/sync/${job.id}'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            child: Icon(
              job.sourceType == 'manual'
                  ? Icons.note_add_outlined
                  : Icons.mic_none_rounded,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    DateFormat.yMMMd().add_Hm().format(
                      job.meetingDate.toLocal(),
                    ),
                    if (job.subjectName != null) job.subjectName!,
                    if (job.classificationConfidence != null)
                      '${(job.classificationConfidence! * 100).round()}% heuristic',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusBadge(job.status),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

String _filterLabel(_JobFilter filter) => switch (filter) {
  _JobFilter.all => 'All',
  _JobFilter.pending => 'Pending',
  _JobFilter.processing => 'Processing',
  _JobFilter.review => 'Needs review',
  _JobFilter.completed => 'Completed',
  _JobFilter.failed => 'Failed',
  _JobFilter.ignored => 'Ignored',
};
