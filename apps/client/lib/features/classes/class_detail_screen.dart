import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/integrations/notion/notion_client.dart';
import '../../core/providers.dart';
import '../../core/security/trusted_url_launcher.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/page_frame.dart';
import '../shared/status_badge.dart';

class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({required this.subjectId, super.key});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsValue = ref.watch(subjectsProvider);
    if (subjectsValue.isLoading) {
      return const PageFrame(
        title: 'Opening class',
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (subjectsValue.hasError) {
      return PageFrame(
        title: 'Class unavailable',
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load this class',
          message: subjectsValue.error.toString(),
          action: FilledButton(
            onPressed: () => context.go('/classes'),
            child: const Text('Back to classes'),
          ),
        ),
      );
    }
    final subjects = subjectsValue.valueOrNull ?? const [];
    final subject = subjects
        .where((item) => item.notionId == subjectId)
        .firstOrNull;
    final jobs = (ref.watch(syncJobsProvider).valueOrNull ?? const [])
        .where((job) => job.subjectId == subjectId)
        .toList();
    final notionValue = ref.watch(notionSubjectSummariesProvider(subjectId));
    final summaries = _recentSummaries(
      jobs,
      notionValue.valueOrNull ?? const [],
    );
    if (subject == null) {
      return PageFrame(
        title: 'Class unavailable',
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Class is not in the active cache',
          message: 'Refresh classes to load its latest Notion status.',
          action: FilledButton(
            onPressed: () => context.go('/classes'),
            child: const Text('Back to classes'),
          ),
        ),
      );
    }
    return PageFrame(
      title: subject.name,
      subtitle: '${subject.semesterLabel} · ${subject.status}',
      actions: [
        if (subject.notionUrl case final url?)
          OutlinedButton.icon(
            onPressed: () async {
              final opened = await launchTrustedUrl(
                url,
                allowedHosts: trustedNotionHosts,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open this Notion page.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open in Notion'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Recent summaries',
                    value: '${summaries.length}',
                    icon: Icons.auto_stories_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Needs review',
                    value:
                        '${jobs.where((job) => job.status.name == 'needsReview').length}',
                    icon: Icons.help_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader('Recent summaries'),
          if (notionValue.isLoading && summaries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (notionValue.hasError && summaries.isEmpty)
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load Notion summaries',
              message: notionValue.error.toString(),
              action: FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(notionSubjectSummariesProvider(subjectId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            )
          else if (summaries.isEmpty)
            const EmptyState(
              icon: Icons.notes_rounded,
              title: 'No summaries for this class',
              message:
                  'No local or Notion summaries were found. Check that the summaries database is shared with your Notion integration.',
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notionValue.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextButton.icon(
                      onPressed: () => ref.invalidate(
                        notionSubjectSummariesProvider(subjectId),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Notion refresh'),
                    ),
                  ),
                Card(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < summaries.length;
                        index++
                      ) ...[
                        ListTile(
                          title: Text(summaries[index].title),
                          subtitle: Text(
                            '${DateFormat.yMMMd().format(summaries[index].date.toLocal())} · ${summaries[index].isNotionOnly ? 'Notion' : 'ClassSync'}',
                          ),
                          trailing: summaries[index].job == null
                              ? const Icon(Icons.open_in_new_rounded)
                              : StatusBadge(summaries[index].job!.status),
                          onTap: () =>
                              _openRecentSummary(context, summaries[index]),
                        ),
                        if (index < summaries.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
                if (summaries.length == 20)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Showing 20 most recent summaries. Open Library to browse everything.',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

List<_RecentSummary> _recentSummaries(
  List<SyncJob> jobs,
  List<NotionSummaryRecord> notionSummaries,
) {
  final linkedNotionPages = jobs
      .map((job) => job.notionPageId)
      .whereType<String>()
      .toSet();
  final output =
      <_RecentSummary>[
        ...jobs
            .where(
              (job) =>
                  job.summaryJson != null ||
                  job.summaryTitle != null ||
                  job.notionPageId != null,
            )
            .map(_RecentSummary.fromJob),
        ...notionSummaries
            .where((summary) => !linkedNotionPages.contains(summary.id))
            .map(_RecentSummary.fromNotion),
      ]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate == 0 ? b.id.compareTo(a.id) : byDate;
      });
  return output.take(20).toList();
}

void _openRecentSummary(BuildContext context, _RecentSummary summary) {
  if (summary.job case final job?) {
    if (job.notionPageId case final pageId?) {
      context.go(
        Uri(
          path: '/library/${Uri.encodeComponent(pageId)}',
          queryParameters: {
            'title': job.summaryTitle ?? job.title,
            if (job.notionUrl != null) 'url': job.notionUrl!,
          },
        ).toString(),
      );
      return;
    }
    context.go('/sync/${job.id}');
    return;
  }
  final notion = summary.notion!;
  context.go(
    Uri(
      path: '/library/${Uri.encodeComponent(notion.id)}',
      queryParameters: {
        'title': notion.title,
        if (notion.url != null) 'url': notion.url!,
      },
    ).toString(),
  );
}

class _RecentSummary {
  const _RecentSummary._({
    required this.id,
    required this.title,
    required this.date,
    this.job,
    this.notion,
  });

  factory _RecentSummary.fromJob(SyncJob job) => _RecentSummary._(
    id: job.id,
    title: job.summaryTitle ?? job.title,
    date: job.meetingDate,
    job: job,
  );

  factory _RecentSummary.fromNotion(NotionSummaryRecord summary) =>
      _RecentSummary._(
        id: summary.id,
        title: summary.title,
        date: summary.date ?? DateTime(0),
        notion: summary,
      );

  final String id;
  final String title;
  final DateTime date;
  final SyncJob? job;
  final NotionSummaryRecord? notion;

  bool get isNotionOnly => notion != null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
