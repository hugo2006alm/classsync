import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/integrations/notion/notion_client.dart';
import '../../core/providers.dart';
import '../../core/security/trusted_url_launcher.dart';
import '../../domain/academic/academic_models.dart';
import '../shared/page_frame.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';
  String? _semester;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(notionLibraryProvider);
    return PageFrame(
      title: 'Library',
      subtitle: 'Your Notion lecture notebooks, organized by semester',
      actions: [
        IconButton(
          tooltip: 'Refresh from Notion',
          onPressed: () => ref.invalidate(notionLibraryProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _LibraryError(
          message: error.toString(),
          onRetry: () => ref.invalidate(notionLibraryProvider),
        ),
        data: (data) => _body(data),
      ),
    );
  }

  Widget _body(NotionLibraryData data) {
    final semesterLabels =
        data.summaries
            .map((summary) => _semesterFor(summary, data.subjects))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final normalizedQuery = _query.trim().toLowerCase();
    final summaries = data.summaries.where((summary) {
      final subject = _subjectFor(summary, data.subjects);
      final matchesQuery =
          normalizedQuery.isEmpty ||
          summary.title.toLowerCase().contains(normalizedQuery) ||
          (subject?.name.toLowerCase().contains(normalizedQuery) ?? false);
      return matchesQuery &&
          (_semester == null ||
              _semesterFor(summary, data.subjects) == _semester);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search lectures or classes',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            DropdownButton<String?>(
              value: _semester,
              hint: const Text('All semesters'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All semesters'),
                ),
                ...semesterLabels.map(
                  (label) => DropdownMenuItem<String?>(
                    value: label,
                    child: Text(label),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _semester = value),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (summaries.isEmpty)
          const _EmptyLibrary()
        else
          ..._grouped(summaries, data.subjects).entries.map(
            (group) => _SemesterSection(
              label: group.key,
              summaries: group.value,
              subjects: data.subjects,
            ),
          ),
      ],
    );
  }
}

Map<String, List<NotionSummaryRecord>> _grouped(
  List<NotionSummaryRecord> summaries,
  Map<String, AcademicSubject> subjects,
) {
  final groups = <String, List<NotionSummaryRecord>>{};
  for (final summary in summaries) {
    groups.putIfAbsent(_semesterFor(summary, subjects), () => []).add(summary);
  }
  return Map.fromEntries(
    groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
  );
}

AcademicSubject? _subjectFor(
  NotionSummaryRecord summary,
  Map<String, AcademicSubject> subjects,
) => summary.subjectIds.isEmpty ? null : subjects[summary.subjectIds.first];

String _semesterFor(
  NotionSummaryRecord summary,
  Map<String, AcademicSubject> subjects,
) {
  final subject = _subjectFor(summary, subjects);
  if (subject == null) return 'Other notes';
  final year = subject.displayYear.trim();
  final semester = subject.semester.trim();
  if (year.isEmpty && semester.isEmpty) return 'Other notes';
  return [
    if (year.isNotEmpty) year,
    if (semester.isNotEmpty) semester,
  ].join(' · ');
}

class _SemesterSection extends StatelessWidget {
  const _SemesterSection({
    required this.label,
    required this.summaries,
    required this.subjects,
  });
  final String label;
  final List<NotionSummaryRecord> summaries;
  final Map<String, AcademicSubject> subjects;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${summaries.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < summaries.length; index++) ...[
                _SummaryTile(summary: summaries[index], subjects: subjects),
                if (index < summaries.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.summary, required this.subjects});
  final NotionSummaryRecord summary;
  final Map<String, AcademicSubject> subjects;

  @override
  Widget build(BuildContext context) {
    final subject = _subjectFor(summary, subjects);
    final date = summary.date == null
        ? 'Date not set'
        : DateFormat.yMMMd().format(summary.date!);
    return ListTile(
      minTileHeight: 76,
      leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
      title: Text(summary.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${subject?.name ?? 'Unlinked class'} · $date'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(
        Uri(
          path: '/library/${Uri.encodeComponent(summary.id)}',
          queryParameters: {
            'title': summary.title,
            if (summary.url != null) 'url': summary.url!,
          },
        ).toString(),
      ),
    );
  }
}

class LibraryDetailScreen extends ConsumerWidget {
  const LibraryDetailScreen({
    required this.pageId,
    required this.title,
    this.notionUrl,
    super.key,
  });
  final String pageId;
  final String title;
  final String? notionUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(notionPageContentProvider(pageId));
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (notionUrl != null)
            IconButton(
              tooltip: 'Open in Notion',
              onPressed: () => launchTrustedUrl(
                notionUrl!,
                allowedHosts: const {'notion.so', 'notion.site'},
              ),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: content.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _LibraryError(
            message: error.toString(),
            onRetry: () => ref.invalidate(notionPageContentProvider(pageId)),
          ),
          data: (blocks) => blocks.isEmpty
              ? const _EmptyLibrary(
                  message: 'This Notion page has no content yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 56),
                  itemCount: blocks.length,
                  itemBuilder: (context, index) => _NotionBlock(blocks[index]),
                ),
        ),
      ),
    );
  }
}

class _NotionBlock extends StatelessWidget {
  const _NotionBlock(this.block);
  final NotionContentBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.type == 'divider') return const Divider(height: 32);
    final theme = Theme.of(context);
    final headingLevel = switch (block.type) {
      'heading_1' => 1,
      'heading_2' => 2,
      'heading_3' => 3,
      _ => 0,
    };
    final prefix = switch (block.type) {
      'bulleted_list_item' => '•  ',
      'numbered_list_item' => '${block.depth + 1}.  ',
      'to_do' => '□  ',
      'callout' => '▸  ',
      _ => '',
    };
    final style = switch (headingLevel) {
      1 => theme.textTheme.headlineSmall,
      2 => theme.textTheme.titleLarge,
      3 => theme.textTheme.titleMedium,
      _ =>
        block.type == 'code'
            ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
            : theme.textTheme.bodyLarge,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12.0 * block.depth,
        headingLevel > 0 ? 18 : 5,
        0,
        5,
      ),
      child: SelectableText('$prefix${block.text}', style: style),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 42),
        const SizedBox(height: 12),
        const Text('Could not load your Notion library.'),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({this.message = 'No summaries match these filters.'});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined, size: 34),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
