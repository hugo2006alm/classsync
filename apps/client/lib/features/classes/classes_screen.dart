import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../domain/academic/academic_models.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/page_frame.dart';

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);
    final jobs = ref.watch(syncJobsProvider).valueOrNull ?? const [];
    return PageFrame(
      title: 'Classes',
      subtitle: 'Current, future, and completed subjects from Notion',
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(syncCoordinatorProvider).refreshActiveSubjects(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ],
      child: subjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load classes',
          message: error.toString(),
        ),
        data: (items) {
          final active = items.where((item) => item.isActive).toList();
          final previous = items.where(_isDone).toList();
          final future = items
              .where((item) => !item.isActive && !_isDone(item))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Active classes'),
              if (active.isEmpty)
                const EmptyState(
                  icon: Icons.school_outlined,
                  title: 'No active classes found',
                  message:
                      'Mark current subjects In progress in Notion, then refresh.',
                )
              else
                _ClassGrid(items: active, jobs: jobs),
              const SizedBox(height: 24),
              _ClassDrawer(
                icon: Icons.upcoming_outlined,
                title: 'Future classes',
                hint: 'Not Done',
                items: future,
                jobs: jobs,
              ),
              const SizedBox(height: 10),
              _ClassDrawer(
                icon: Icons.history_rounded,
                title: 'Previous classes',
                hint: 'Done',
                items: previous,
                jobs: jobs,
              ),
            ],
          );
        },
      ),
    );
  }
}

bool _isDone(AcademicSubject subject) =>
    subject.status.trim().toLowerCase() == 'done';

class _ClassDrawer extends StatelessWidget {
  const _ClassDrawer({
    required this.icon,
    required this.title,
    required this.hint,
    required this.items,
    required this.jobs,
  });

  final IconData icon;
  final String title;
  final String hint;
  final List<AcademicSubject> items;
  final List<SyncJob> jobs;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey(title),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text('${items.length} · $hint'),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'No ${title.toLowerCase()} found.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          _ClassGrid(items: items, jobs: jobs, compact: true),
      ],
    ),
  );
}

class _ClassGrid extends StatelessWidget {
  const _ClassGrid({
    required this.items,
    required this.jobs,
    this.compact = false,
  });

  final List<AcademicSubject> items;
  final List<SyncJob> jobs;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 3
          : constraints.maxWidth >= 680
          ? 2
          : 1;
      return GridView.builder(
        key: PageStorageKey(
          'class-grid:${items.map((item) => item.notionId).join(',')}',
        ),
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: compact ? 148 : (columns == 1 ? 210 : 230),
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _ClassCard(
          subject: items[index],
          compact: compact,
          jobs: jobs
              .where((job) => job.subjectId == items[index].notionId)
              .toList(),
        ),
      );
    },
  );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.subject,
    required this.jobs,
    required this.compact,
  });
  final AcademicSubject subject;
  final List<SyncJob> jobs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final summaries = jobs.where((job) => job.summaryTitle != null).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            context.go('/classes/${Uri.encodeComponent(subject.notionId)}'),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    compact ? Icons.book_outlined : Icons.menu_book_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const Spacer(),
                  if (compact)
                    Text(
                      subject.status,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
              const Spacer(),
              Text(
                subject.name,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(subject.semesterLabel),
              if (!compact) ...[
                const SizedBox(height: 14),
                Text(
                  summaries.isEmpty
                      ? 'No local summaries yet'
                      : 'Latest: ${summaries.first.summaryTitle}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
