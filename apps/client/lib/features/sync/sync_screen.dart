import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/integrations/integration_exception.dart';
import '../../core/providers.dart';
import '../../domain/academic/academic_models.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/page_frame.dart';
import '../shared/status_badge.dart';

enum _JobFilter { all, pending, processing, review, completed, failed }

enum _JobAction { openSummary, changeSubject, language, discard }

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
          final visibleJobs = jobs
              .where((job) => job.status != SyncJobStatus.ignored)
              .toList();
          final filtered = visibleJobs.where(_matchesFilter).toList();
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
                  icon: visibleJobs.isEmpty
                      ? Icons.inbox_outlined
                      : Icons.filter_alt_off_rounded,
                  title: visibleJobs.isEmpty
                      ? 'No transcripts discovered yet'
                      : 'No matching jobs',
                  message: visibleJobs.isEmpty
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
  };

  Future<void> _showManualImport(BuildContext context) async {
    final titleController = TextEditingController();
    final transcriptController = TextEditingController();
    var importing = false;
    String? importError;
    final jobId = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import transcript'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Lecture title',
                    ),
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
                  if (importError != null)
                    Text(
                      importError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: importing ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: importing
                  ? null
                  : () async {
                      if (transcriptController.text.trim().isEmpty) {
                        setDialogState(
                          () => importError = 'Transcript cannot be empty.',
                        );
                        return;
                      }
                      setDialogState(() {
                        importing = true;
                        importError = null;
                      });
                      try {
                        final id = await ref
                            .read(syncCoordinatorProvider)
                            .importTranscript(
                              title: titleController.text,
                              transcriptText: transcriptController.text,
                            );
                        if (context.mounted) Navigator.pop(context, id);
                      } catch (error) {
                        if (context.mounted) {
                          setDialogState(() {
                            importing = false;
                            importError = switch (error) {
                              FormatException() => error.message,
                              IntegrationException() => error.userMessage,
                              _ => 'Import failed. Try again.',
                            };
                          });
                        }
                      }
                    },
              child: const Text('Queue import'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    transcriptController.dispose();
    if (jobId != null && mounted) this.context.go('/sync/$jobId');
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job});
  final SyncJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections =
        ref.watch(firefliesConnectionsProvider).valueOrNull ?? const [];
    final subjects =
        ref.watch(activeSubjectsProvider).valueOrNull ??
        const <AcademicSubject>[];
    final sourceName = job.sourceType == 'manual'
        ? 'Manual import'
        : connections
                  .where((item) => job.sourceType == 'fireflies:${item.id}')
                  .firstOrNull
                  ?.name ??
              'Fireflies';
    return InkWell(
      onTap: () => _openJob(context, job),
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
                      sourceName,
                      DateFormat.yMMMd().add_Hm().format(
                        job.meetingDate.toLocal(),
                      ),
                      if (job.subjectName != null) job.subjectName!,
                      if (job.summaryLanguageOverride case final language?)
                        'Summary: $language',
                      if (job.classificationConfidence != null)
                        '${(job.classificationConfidence! * 100).round()}% heuristic',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (job.notionPageId != null) ...[
              IconButton.filledTonal(
                tooltip: 'Read summary in Library',
                onPressed: () => context.go(_libraryLocation(job)),
                icon: const Icon(Icons.auto_stories_rounded),
              ),
              const SizedBox(width: 4),
            ],
            PopupMenuButton<_JobAction>(
              tooltip: 'Transcript actions',
              onSelected: (action) =>
                  _handleAction(context, ref, subjects, action),
              itemBuilder: (context) => [
                if (job.notionPageId != null)
                  const PopupMenuItem(
                    value: _JobAction.openSummary,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.auto_stories_rounded),
                      title: Text('Read summary'),
                    ),
                  ),
                if (!job.status.isProcessing && subjects.isNotEmpty)
                  const PopupMenuItem(
                    value: _JobAction.changeSubject,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Change class'),
                    ),
                  ),
                PopupMenuItem(
                  value: _JobAction.language,
                  enabled: !job.status.isProcessing,
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.translate_rounded),
                    title: Text('Summary language'),
                  ),
                ),
                if (_canDiscard(job))
                  const PopupMenuItem(
                    value: _JobAction.discard,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Discard transcript'),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            StatusBadge(job.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    List<AcademicSubject> subjects,
    _JobAction action,
  ) async {
    switch (action) {
      case _JobAction.openSummary:
        if (job.notionPageId != null) context.go(_libraryLocation(job));
      case _JobAction.changeSubject:
        await _chooseSubject(context, ref, subjects);
      case _JobAction.language:
        await _chooseLanguage(context, ref);
      case _JobAction.discard:
        await _discard(context, ref);
    }
  }

  Future<void> _chooseSubject(
    BuildContext context,
    WidgetRef ref,
    List<AcademicSubject> subjects,
  ) async {
    if (subjects.isEmpty) return;
    var selectedId = subjects.any((subject) => subject.notionId == job.subjectId)
        ? job.subjectId!
        : subjects.first.notionId;
    final selected = await showDialog<AcademicSubject>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(job.subjectId == null ? 'Choose class' : 'Change class'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Active class'),
                  items: subjects
                      .map(
                        (subject) => DropdownMenuItem(
                          value: subject.notionId,
                          child: Text(
                            subject.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedId = value);
                    }
                  },
                ),
                if (job.notionPageId != null) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Changing the class regenerates the summary, updates the existing Notion page, and refreshes lecture tasks without creating a duplicate.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedId == job.subjectId
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      subjects.firstWhere(
                        (subject) => subject.notionId == selectedId,
                      ),
                    ),
              child: const Text('Use class'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await ref.read(syncCoordinatorProvider).confirmSubject(job.id, selected);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Class changed to ${selected.name}.')),
      );
    } on IntegrationException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update class: $error')),
      );
    }
  }

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    final defaultLanguage = settings?.summaryLanguage ?? 'app default';
    final controller = TextEditingController(
      text: job.summaryLanguageOverride ?? '',
    );
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Summary language'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Language for this transcript',
                  hintText: 'e.g. English',
                  helperText:
                      'Leave blank to use the app default: $defaultLanguage',
                ),
                onSubmitted: (value) =>
                    Navigator.pop(dialogContext, value.trim()),
              ),
              if (job.summaryJson != null || job.notionPageId != null) ...[
                const SizedBox(height: 14),
                const Text(
                  'This transcript already has a summary. Changing the language will regenerate it and update the published Library entry.',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Use default'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (selected == null || !context.mounted) return;
    try {
      await ref
          .read(syncCoordinatorProvider)
          .setSummaryLanguage(job.id, selected.isEmpty ? null : selected);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected.isEmpty
                ? 'This transcript now uses the default summary language.'
                : 'Summary language set to $selected.',
          ),
        ),
      );
    } on IntegrationException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard transcript?'),
        content: Text(
          job.notionPageId == null
              ? '“${job.title}” will be removed from Sync and will not be processed again if Fireflies rediscovers it.'
              : '“${job.title}” will be removed from Sync. Its published summary stays in Library/Notion, and lecture tasks derived from this transcript are removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(syncCoordinatorProvider).discardJob(job.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transcript discarded.')));
    } on IntegrationException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }
}

bool _canDiscard(SyncJob job) => !job.status.isProcessing;

void _openJob(BuildContext context, SyncJob job) {
  context.go('/sync/${job.id}');
}

String _libraryLocation(SyncJob job) => Uri(
  path: '/library/${Uri.encodeComponent(job.notionPageId!)}',
  queryParameters: {
    'title': job.summaryTitle ?? job.title,
    if (job.notionUrl != null) 'url': job.notionUrl!,
  },
).toString();

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _filterLabel(_JobFilter filter) => switch (filter) {
  _JobFilter.all => 'All',
  _JobFilter.pending => 'Pending',
  _JobFilter.processing => 'Processing',
  _JobFilter.review => 'Needs review',
  _JobFilter.completed => 'Completed',
  _JobFilter.failed => 'Failed',
};
