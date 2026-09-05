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
    final subjects = ref.watch(activeSubjectsProvider);
    final jobs = ref.watch(syncJobsProvider).valueOrNull ?? const [];
    return PageFrame(
      title: 'Classes',
      subtitle: 'Active subjects from Notion',
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
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.school_outlined,
                title: 'No active classes found',
                message:
                    'Mark current subjects In progress in Notion, then refresh.',
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 3
                      : constraints.maxWidth >= 680
                      ? 2
                      : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: columns == 1 ? 210 : 230,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _ClassCard(
                      subject: items[index],
                      jobs: jobs
                          .where(
                            (job) => job.subjectId == items[index].notionId,
                          )
                          .toList(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.subject, required this.jobs});
  final AcademicSubject subject;
  final List<SyncJob> jobs;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () =>
          context.go('/classes/${Uri.encodeComponent(subject.notionId)}'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
            const Spacer(),
            Text(subject.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subject.semesterLabel),
            const SizedBox(height: 14),
            Text(
              jobs.where((job) => job.summaryTitle != null).isEmpty
                  ? 'No local summaries yet'
                  : 'Latest: ${jobs.firstWhere((job) => job.summaryTitle != null).summaryTitle}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
