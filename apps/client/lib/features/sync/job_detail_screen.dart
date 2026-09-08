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
                job.status == SyncJobStatus.failedTerminal)
              FilledButton.icon(
                onPressed: () =>
                    ref.read(syncCoordinatorProvider).retryJob(job.id),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Retry'),
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
                    if (job.classificationConfidence != null)
                      Text(
                        '${(job.classificationConfidence! * 100).round()}% heuristic',
                      ),
                  ],
                ),
                if (job.subjectName != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    job.subjectName!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
                if (job.lastErrorMessage != null) ...[
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
                      onPressed: () {
                        final subject = subjects
                            .where(
                              (item) => item.notionId == candidate.subjectId,
                            )
                            .firstOrNull;
                        if (subject != null) {
                          ref
                              .read(syncCoordinatorProvider)
                              .confirmSubject(job.id, subject);
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
        ],
        const SizedBox(height: 20),
        _DetailSection(
          title: 'Transcript',
          icon: Icons.mic_none_rounded,
          child: job.transcriptJson == null
              ? const Text('Transcript payload not retained locally.')
              : Text(
                  LectureTranscript.fromStoredJson(
                    job.transcriptJson!,
                  ).plainText,
                  maxLines: 18,
                  overflow: TextOverflow.fade,
                ),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Classification',
          icon: Icons.route_rounded,
          child: candidates.isEmpty
              ? const Text('Classification has not run yet.')
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
              ? const Text('Summary has not been generated yet.')
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
  });
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: Icon(icon),
      title: Text(title),
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
