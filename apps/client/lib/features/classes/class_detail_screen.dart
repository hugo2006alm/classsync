import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../shared/page_frame.dart';
import '../shared/status_badge.dart';

class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({required this.subjectId, super.key});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(activeSubjectsProvider).valueOrNull ?? const [];
    final subject = subjects
        .where((item) => item.notionId == subjectId)
        .firstOrNull;
    final jobs = (ref.watch(syncJobsProvider).valueOrNull ?? const [])
        .where((job) => job.subjectId == subjectId)
        .toList();
    if (subject == null) {
      return PageFrame(
        title: 'Class unavailable',
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Class is not in the active cache',
          message: 'It may have changed status in Notion.',
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
            onPressed: () => launchUrl(Uri.parse(url)),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open in Notion'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Local summaries',
                  value:
                      '${jobs.where((job) => job.summaryJson != null).length}',
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
          const SizedBox(height: 28),
          const SectionHeader('Recent summaries'),
          if (jobs.isEmpty)
            const EmptyState(
              icon: Icons.notes_rounded,
              title: 'No summaries for this class',
              message: 'ClassSync will add them after matching a lecture.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < jobs.length; index++) ...[
                    ListTile(
                      title: Text(
                        jobs[index].summaryTitle ?? jobs[index].title,
                      ),
                      subtitle: Text(
                        jobs[index].meetingDate
                            .toLocal()
                            .toString()
                            .split(' ')
                            .first,
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
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
