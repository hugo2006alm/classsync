import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/integrations/notion/notion_client.dart';
import '../../core/providers.dart';
import '../../core/security/trusted_url_launcher.dart';
import '../../domain/academic/academic_models.dart';
import '../shared/page_frame.dart';

final Set<String> _trustedNotionContentHosts = {
  ...trustedNotionHosts,
  'fireflies.ai',
};

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
          for (final (index, group) in _grouped(
            summaries,
            data.subjects,
          ).entries.indexed)
            _SemesterSection(
              label: group.key,
              summaries: group.value,
              subjects: data.subjects,
              initiallyExpanded: index == 0,
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
    required this.initiallyExpanded,
  });
  final String label;
  final List<NotionSummaryRecord> summaries;
  final Map<String, AcademicSubject> subjects;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final bySubject = <String, List<NotionSummaryRecord>>{};
    for (final summary in summaries) {
      final key = summary.subjectIds.firstOrNull ?? '__unlinked__';
      bySubject.putIfAbsent(key, () => []).add(summary);
    }
    final groups = bySubject.entries.toList()
      ..sort((a, b) {
        final left = subjects[a.key]?.name ?? 'Unlinked notes';
        final right = subjects[b.key]?.name ?? 'Unlinked notes';
        return left.compareTo(right);
      });
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('semester:$label'),
          initiallyExpanded: initiallyExpanded,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            child: Text('${summaries.length}'),
          ),
          title: Text(label, style: Theme.of(context).textTheme.titleLarge),
          subtitle: Text(
            '${groups.length} ${groups.length == 1 ? 'subject' : 'subjects'}',
          ),
          children: [
            const Divider(height: 1),
            for (final (index, group) in groups.indexed)
              _SubjectSection(
                subject: subjects[group.key],
                summaries: group.value,
                subjects: subjects,
                initiallyExpanded: index == 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _SubjectSection extends StatelessWidget {
  const _SubjectSection({
    required this.subject,
    required this.summaries,
    required this.subjects,
    required this.initiallyExpanded,
  });

  final AcademicSubject? subject;
  final List<NotionSummaryRecord> summaries;
  final Map<String, AcademicSubject> subjects;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final ordered = [
      ...summaries,
    ]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    return ExpansionTile(
      key: PageStorageKey('subject:${subject?.notionId ?? 'unlinked'}'),
      initiallyExpanded: initiallyExpanded,
      leading: const Icon(Icons.book_outlined),
      title: Text(subject?.name ?? 'Unlinked notes'),
      subtitle: Text(
        '${ordered.length} ${ordered.length == 1 ? 'lecture' : 'lectures'}',
      ),
      children: [
        for (var index = 0; index < ordered.length; index++) ...[
          _SummaryTile(summary: ordered[index], subjects: subjects),
          if (index < ordered.length - 1) const Divider(height: 1, indent: 72),
        ],
      ],
    );
  }
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
      onTap: () => _openSummary(context, summary),
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
    final library = ref.watch(notionLibraryProvider).valueOrNull;
    final current = library?.summaries
        .where((summary) => summary.id == pageId)
        .firstOrNull;
    final neighbours = library == null
        ? const _SummaryNeighbours()
        : _summaryNeighbours(current, library.summaries);
    final effectiveTitle = current?.title ?? title;
    final effectiveUrl = current?.url ?? notionUrl;
    return Scaffold(
      appBar: AppBar(
        title: Text(effectiveTitle),
        actions: [
          if (effectiveUrl != null)
            IconButton(
              tooltip: 'Open in Notion',
              onPressed: () async {
                final opened = await launchTrustedUrl(
                  effectiveUrl,
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
      bottomNavigationBar:
          neighbours.previous == null && neighbours.next == null
          ? null
          : SafeArea(
              top: false,
              child: Material(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: neighbours.previous == null
                              ? null
                              : () =>
                                    _openSummary(context, neighbours.previous!),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: neighbours.next == null
                              ? null
                              : () => _openSummary(context, neighbours.next!),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

void _openSummary(BuildContext context, NotionSummaryRecord summary) {
  context.go(
    Uri(
      path: '/library/${Uri.encodeComponent(summary.id)}',
      queryParameters: {
        'title': summary.title,
        if (summary.url != null) 'url': summary.url!,
      },
    ).toString(),
  );
}

_SummaryNeighbours _summaryNeighbours(
  NotionSummaryRecord? current,
  List<NotionSummaryRecord> all,
) {
  if (current == null) return const _SummaryNeighbours();
  final subjectId = current.subjectIds.firstOrNull;
  final sameSubject =
      all.where((summary) {
        final candidate = summary.subjectIds.firstOrNull;
        return candidate == subjectId;
      }).toList()..sort((a, b) {
        final byDate = (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0));
        return byDate == 0 ? a.id.compareTo(b.id) : byDate;
      });
  final index = sameSubject.indexWhere((summary) => summary.id == current.id);
  if (index < 0) return const _SummaryNeighbours();
  return _SummaryNeighbours(
    previous: index > 0 ? sameSubject[index - 1] : null,
    next: index + 1 < sameSubject.length ? sameSubject[index + 1] : null,
  );
}

class _SummaryNeighbours {
  const _SummaryNeighbours({this.previous, this.next});
  final NotionSummaryRecord? previous;
  final NotionSummaryRecord? next;
}

class _NotionBlock extends StatelessWidget {
  const _NotionBlock(this.block);
  final NotionContentBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.type == 'divider') return const Divider(height: 32);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final headingLevel = switch (block.type) {
      'heading_1' => 1,
      'heading_2' => 2,
      'heading_3' => 3,
      _ => 0,
    };
    final style = switch (headingLevel) {
      1 => theme.textTheme.headlineSmall,
      2 => theme.textTheme.titleLarge,
      3 => theme.textTheme.titleMedium,
      _ => theme.textTheme.bodyLarge,
    };
    final richText = _NotionRichText(
      fallback: block.text,
      spans: block.spans,
      style: style,
    );

    Widget child;
    switch (block.type) {
      case 'callout':
        child = DecoratedBox(
          decoration: BoxDecoration(
            color: _notionBackgroundColor(block.color) ??
                scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.icon ?? '📌', style: theme.textTheme.titleMedium),
                const SizedBox(width: 10),
                Expanded(child: richText),
              ],
            ),
          ),
        );
      case 'code':
        child = DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.language case final language?
                    when language.trim().isNotEmpty &&
                        language.toLowerCase() != 'plain text') ...[
                  Text(
                    language,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _NotionRichText(
                  fallback: block.text,
                  spans: block.spans,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        );
      case 'equation':
        child = Align(
          alignment: Alignment.center,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SelectableText(
                block.text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        );
      case 'quote':
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: scheme.outlineVariant),
            const SizedBox(width: 12),
            Expanded(child: richText),
          ],
        );
      case 'to_do':
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                block.checked == true
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: richText),
          ],
        );
      case 'bulleted_list_item':
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 4),
            Text('•', style: style),
            const SizedBox(width: 10),
            Expanded(child: richText),
          ],
        );
      case 'numbered_list_item':
        child = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${block.depth + 1}.', style: style),
            const SizedBox(width: 10),
            Expanded(child: richText),
          ],
        );
      default:
        child = richText;
    }

    final background = _notionBackgroundColor(block.color);
    if (background != null &&
        block.type != 'callout' &&
        block.type != 'code' &&
        block.type != 'equation') {
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: child,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12.0 * block.depth,
        headingLevel > 0 ? 18 : 5,
        0,
        5,
      ),
      child: child,
    );
  }
}

class _NotionRichText extends StatefulWidget {
  const _NotionRichText({
    required this.fallback,
    required this.spans,
    required this.style,
  });

  final String fallback;
  final List<NotionRichTextSpan> spans;
  final TextStyle? style;

  @override
  State<_NotionRichText> createState() => _NotionRichTextState();
}

class _NotionRichTextState extends State<_NotionRichText> {
  final Map<String, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _recognizer(String url) => _recognizers.putIfAbsent(
    url,
    () => TapGestureRecognizer()
      ..onTap = () async {
        final opened = await launchTrustedUrl(
          url,
          allowedHosts: _trustedNotionContentHosts,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this link safely.')),
          );
        }
      },
  );

  @override
  Widget build(BuildContext context) {
    final spans = widget.spans.isEmpty
        ? [NotionRichTextSpan(text: widget.fallback)]
        : widget.spans;
    return SelectableText.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final span in spans)
            TextSpan(
              text: span.text,
              style: _inlineStyle(context, widget.style, span),
              recognizer: span.href == null ? null : _recognizer(span.href!),
            ),
        ],
      ),
    );
  }
}

TextStyle _inlineStyle(
  BuildContext context,
  TextStyle? base,
  NotionRichTextSpan span,
) {
  final decorations = <TextDecoration>[
    if (span.underline || span.href != null) TextDecoration.underline,
    if (span.strikethrough) TextDecoration.lineThrough,
  ];
  return (base ?? const TextStyle()).copyWith(
    fontWeight: span.bold ? FontWeight.w700 : null,
    fontStyle: span.italic ? FontStyle.italic : null,
    decoration: decorations.isEmpty
        ? null
        : TextDecoration.combine(decorations),
    fontFamily: span.code ? 'monospace' : null,
    color: _notionTextColor(span.color),
    backgroundColor: span.code
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : _notionBackgroundColor(span.color),
  );
}

Color? _notionTextColor(String? color) => switch (color) {
  'gray' => Colors.grey.shade700,
  'brown' => Colors.brown.shade700,
  'orange' => Colors.orange.shade800,
  'yellow' => Colors.amber.shade800,
  'green' => Colors.green.shade700,
  'blue' => Colors.blue.shade700,
  'purple' => Colors.purple.shade700,
  'pink' => Colors.pink.shade600,
  'red' => Colors.red.shade700,
  _ => null,
};

Color? _notionBackgroundColor(String? color) => switch (color) {
  'gray_background' => Colors.grey.withValues(alpha: 0.16),
  'brown_background' => Colors.brown.withValues(alpha: 0.14),
  'orange_background' => Colors.orange.withValues(alpha: 0.15),
  'yellow_background' => Colors.amber.withValues(alpha: 0.18),
  'green_background' => Colors.green.withValues(alpha: 0.14),
  'blue_background' => Colors.blue.withValues(alpha: 0.14),
  'purple_background' => Colors.purple.withValues(alpha: 0.14),
  'pink_background' => Colors.pink.withValues(alpha: 0.14),
  'red_background' => Colors.red.withValues(alpha: 0.14),
  _ => null,
};

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