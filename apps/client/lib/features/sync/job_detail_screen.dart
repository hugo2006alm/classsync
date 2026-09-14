import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/redactor.dart';
import '../../core/providers.dart';
import '../../core/security/trusted_url_launcher.dart';
import '../../domain/academic/academic_models.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/page_frame.dart';
import '../shared/status_badge.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({required this.jobId, super.key});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobValue = ref.watch(syncJobProvider(jobId));
    final timeline =
        ref.watch(jobTimelineProvider(jobId)).valueOrNull ?? const [];
    final subjects = ref.watch(activeSubjectsProvider).valueOrNull ?? const [];
    final connections =
        ref.watch(firefliesConnectionsProvider).valueOrNull ?? const [];
    return jobValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (job) {
        if (job == null) {
          return const PageFrame(
            title: 'Job not found',
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'This sync job is unavailable',
              message: 'It may have been cleaned from local storage.',
            ),
          );
        }
        return PageFrame(
          title: job.title,
          subtitle: [
            DateFormat.yMMMMd().add_Hm().format(job.meetingDate.toLocal()),
            if (job.sourceType == 'manual')
              'Manual import'
            else
              connections
                      .where((item) => job.sourceType == 'fireflies:${item.id}')
                      .firstOrNull
                      ?.name ??
                  'Fireflies',
          ].join(' · '),
          actions: [
            if (job.firefliesUrl case final url?)
              OutlinedButton.icon(
                onPressed: () => _openUrl(context, url, const {'fireflies.ai'}),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Fireflies'),
              ),
            if (job.notionUrl case final url?)
              OutlinedButton.icon(
                onPressed: () => _openUrl(context, url, trustedNotionHosts),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Notion'),
              ),
            if (job.status == SyncJobStatus.failedRetryable ||
                job.status == SyncJobStatus.failedTerminal ||
                _isStaleProcessing(job))
              FilledButton.icon(
                onPressed: () =>
                    ref.read(syncCoordinatorProvider).retryJob(job.id),
                icon: const Icon(Icons.replay_rounded),
                label: Text(_isStaleProcessing(job) ? 'Recover' : 'Retry'),
              ),
            if (job.notionPageId != null)
              PopupMenuButton<_ReprocessAction>(
                tooltip: 'Reprocess',
                onSelected: (action) =>
                    _confirmReprocess(context, ref, job, action),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ReprocessAction.regenerate,
                    child: Text('Regenerate summary'),
                  ),
                  PopupMenuItem(
                    value: _ReprocessAction.reclassify,
                    child: Text('Reclassify subject'),
                  ),
                  PopupMenuItem(
                    value: _ReprocessAction.republish,
                    child: Text('Republish to Notion'),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) {
              final detail = _JobContent(job: job, subjects: subjects);
              final events = _Timeline(events: timeline);
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [detail, const SizedBox(height: 20), events],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: detail),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: events),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

Future<void> _openUrl(
  BuildContext context,
  String value,
  Set<String> hosts,
) async {
  if (await launchTrustedUrl(value, allowedHosts: hosts)) return;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Blocked invalid external link.')),
  );
}

class _JobContent extends ConsumerWidget {
  const _JobContent({required this.job, required this.subjects});
  final SyncJob job;
  final List<AcademicSubject> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = job.summaryJson == null
        ? null
        : LectureSummary.decode(job.summaryJson!);
    final transcriptText = job.transcriptJson == null
        ? null
        : LectureTranscript.fromStoredJson(job.transcriptJson!).plainText;
    final candidates = _candidates(job.classificationCandidatesJson);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(job.status),
                    const Spacer(),
                    if (job.classificationConfidence != null &&
                        candidates.isNotEmpty)
                      Text(
                        '${(job.classificationConfidence! * 100).round()}% AI confidence',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        job.subjectName ?? 'No class selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (subjects.isNotEmpty && !job.status.isProcessing)
                      TextButton.icon(
                        onPressed: () =>
                            _chooseSubject(context, ref, job, subjects),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          job.subjectId == null ? 'Choose class' : 'Change',
                        ),
                      ),
                  ],
                ),
                if (_showsCurrentError(job)) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded),
                          const SizedBox(width: 10),
                          Expanded(child: Text(job.lastErrorMessage!)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (job.status == SyncJobStatus.needsReview) ...[
          const SizedBox(height: 20),
          Text('Confirm class', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...candidates
              .take(3)
              .map(
                (candidate) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () async {
                        final subject = subjects
                            .where(
                              (item) => item.notionId == candidate.subjectId,
                            )
                            .firstOrNull;
                        if (subject != null) {
                          await _applySubject(context, ref, job, subject);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(candidate.subjectName)),
                            Text('${(candidate.confidence * 100).round()}%'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _chooseSubject(context, ref, job, subjects),
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Choose another class'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _DetailSection(
          title: 'Transcript',
          icon: Icons.mic_none_rounded,
          action: transcriptText == null
              ? null
              : IconButton(
                  onPressed: () =>
                      _showFullTranscript(context, job.title, transcriptText),
                  tooltip: 'Open full transcript',
                  icon: const Icon(Icons.open_in_full_rounded),
                ),
          child: transcriptText == null
              ? Text(_missingTranscriptMessage(job))
              : Text(transcriptText, maxLines: 18, overflow: TextOverflow.fade),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Classification',
          icon: Icons.route_rounded,
          child: candidates.isEmpty
              ? Text(_classificationMessage(job))
              : Column(
                  children: candidates
                      .map(
                        (candidate) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(candidate.subjectName),
                          trailing: Text(
                            '${(candidate.confidence * 100).round()}%',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Summary',
          icon: Icons.auto_stories_rounded,
          initiallyExpanded: summary != null,
          child: summary == null
              ? _MissingSummary(job: job)
              : _SummaryPreview(summary: summary),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Diagnostics',
          icon: Icons.monitor_heart_outlined,
          child: SelectableText(
            SecretRedactor.redact(
              'Job ${job.id}\nSource ${job.firefliesId}\nStatus ${job.status.wireName}\nAttempts ${job.attemptCount}\nError ${job.lastErrorType ?? 'none'}',
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
    this.action,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: Icon(icon),
      title: Row(
        children: [
          Expanded(child: Text(title)),
          ?action,
        ],
      ),
      initiallyExpanded: initiallyExpanded,
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [Align(alignment: Alignment.centerLeft, child: child)],
    ),
  );
}

class _SummaryPreview extends StatelessWidget {
  const _SummaryPreview({required this.summary});
  final LectureSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(summary.title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      Text(summary.context),
      for (final section in summary.sections) ...[
        const SizedBox(height: 18),
        Text(section.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(section.content),
        for (final point in section.keyPoints)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('• $point'),
          ),
      ],
      ..._summaryGroup(context, 'Ênfase do docente', summary.teacherEmphasis),
      ..._summaryGroup(
        context,
        'Detalhes pequenos mas importantes',
        summary.importantDetails,
      ),
      ..._summaryGroup(
        context,
        'Perguntas e respostas',
        summary.questionsAndAnswers,
      ),
      ..._summaryGroup(
        context,
        'Tarefas, prazos e avisos',
        summary.assignmentsAndDeadlines,
      ),
      ..._summaryGroup(context, 'Pistas para avaliação', summary.examHints),
      if (summary.conclusions.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(
          'Conclusões e Pontos-Chave',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final point in summary.conclusions)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('• $point'),
          ),
      ],
    ],
  );
}

class _MissingSummary extends StatelessWidget {
  const _MissingSummary({required this.job});
  final SyncJob job;

  @override
  Widget build(BuildContext context) {
    if (job.summaryTitle != null ||
        job.status == SyncJobStatus.success ||
        job.status == SyncJobStatus.duplicate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (job.summaryTitle case final title?) ...[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
          ],
          const Text(
            'Summary completed. Full content is available in Notion and is not copied between devices.',
          ),
        ],
      );
    }
    return const Text('Summary has not been generated yet.');
  }
}

bool _showsCurrentError(SyncJob job) =>
    job.lastErrorMessage != null &&
    (job.status == SyncJobStatus.failedRetryable ||
        job.status == SyncJobStatus.failedTerminal);

bool _isStaleProcessing(SyncJob job) {
  if (!job.status.isProcessing) return false;
  final now = DateTime.now().toUtc();
  if (job.leaseExpiresAt case final expires?) return !expires.isAfter(now);
  final started = job.startedAt;
  return started != null &&
      now.difference(started.toUtc()) >= const Duration(minutes: 30);
}

String _missingTranscriptMessage(SyncJob job) =>
    job.status == SyncJobStatus.success || job.status == SyncJobStatus.duplicate
    ? 'Transcript content is not stored on this device. Open Fireflies for the canonical transcript.'
    : 'Transcript payload is not retained locally.';

String _classificationMessage(SyncJob job) {
  if (job.subjectName != null) {
    return 'Selected class: ${job.subjectName}. Detailed classification evidence is not stored on this device.';
  }
  if (job.status == SyncJobStatus.success ||
      job.status == SyncJobStatus.duplicate) {
    return 'Classification completed on another device, but its selected class metadata is not available locally.';
  }
  return 'Classification has not run yet.';
}

Future<void> _showFullTranscript(
  BuildContext context,
  String title,
  String transcript,
) => showDialog<void>(
  context: context,
  useSafeArea: true,
  builder: (context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close transcript',
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(title),
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Text(transcript),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _chooseSubject(
  BuildContext context,
  WidgetRef ref,
  SyncJob job,
  List<AcademicSubject> subjects,
) async {
  if (subjects.isEmpty) return;
  var selectedId = subjects.any((subject) => subject.notionId == job.subjectId)
      ? job.subjectId!
      : subjects.first.notionId;
  final selected = await showDialog<AcademicSubject>(
    context: context,
    builder: (context) => StatefulBuilder(
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
                  'Changing the class regenerates the summary and updates the existing Notion page without creating a duplicate.',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed:
                selectedId == job.subjectId &&
                    (job.status == SyncJobStatus.success ||
                        job.status == SyncJobStatus.duplicate)
                ? null
                : () => Navigator.pop(
                    context,
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
  if (selected != null && context.mounted) {
    await _applySubject(context, ref, job, selected);
  }
}

Future<void> _applySubject(
  BuildContext context,
  WidgetRef ref,
  SyncJob job,
  AcademicSubject subject,
) async {
  try {
    await ref.read(syncCoordinatorProvider).confirmSubject(job.id, subject);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update class: $error')));
    }
  }
}

List<Widget> _summaryGroup(
  BuildContext context,
  String title,
  List<String> items,
) => items.isEmpty
    ? const []
    : [
        const SizedBox(height: 18),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('• $item'),
          ),
      ];

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<JobTimelineEvent> events;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader('Pipeline timeline'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: events.isEmpty
              ? const Text('No pipeline events recorded.')
              : Column(
                  children: events
                      .map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Icon(
                                    Icons.radio_button_checked_rounded,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  Container(
                                    width: 2,
                                    height: 30,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(event.message),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat.Hm().format(
                                        event.createdAt.toLocal(),
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ),
    ],
  );
}

List<ClassificationCandidate> _candidates(String? source) {
  if (source == null) return const [];
  try {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return ClassificationResult.fromJson(json).candidates;
  } catch (_) {
    return const [];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

enum _ReprocessAction { regenerate, reclassify, republish }

Future<void> _confirmReprocess(
  BuildContext context,
  WidgetRef ref,
  SyncJob job,
  _ReprocessAction action,
) async {
  final label = switch (action) {
    _ReprocessAction.regenerate => 'regenerate this summary',
    _ReprocessAction.reclassify => 'reclassify this lecture',
    _ReprocessAction.republish => 'republish this summary',
  };
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reprocess lecture?'),
      content: Text(
        'ClassSync will $label and update the existing Notion page. '
        'It will not create a duplicate.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final coordinator = ref.read(syncCoordinatorProvider);
  try {
    switch (action) {
      case _ReprocessAction.regenerate:
        await coordinator.regenerateSummary(job.id);
      case _ReprocessAction.reclassify:
        await coordinator.reclassifyJob(job.id);
      case _ReprocessAction.republish:
        await coordinator.republishJob(job.id);
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
