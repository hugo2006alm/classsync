import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../core/providers.dart';
import '../../domain/academic/academic_hub_models.dart';
import '../../domain/academic/academic_models.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/page_frame.dart';
import 'academic_connections_dialog.dart';

class AcademicScreen extends ConsumerStatefulWidget {
  const AcademicScreen({super.key, this.initialSection = 0});

  final int initialSection;

  @override
  ConsumerState<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends ConsumerState<AcademicScreen> {
  late int _section = widget.initialSection.clamp(0, 7).toInt();
  late DateTime _weekStart = _startOfWeek(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final recordsValue = ref.watch(academicRecordsProvider);
    final sync = ref.watch(syncControllerProvider);
    final connections = ref.watch(academicConnectionStateProvider).valueOrNull;
    return PageFrame(
      title: 'Academic',
      subtitle:
          'Portal, timetable, evaluations, Moodle, and grades — cached locally',
      actions: [
        OutlinedButton.icon(
          onPressed: () => showAcademicConnectionsDialog(context, ref),
          icon: const Icon(Icons.link_rounded),
          label: const Text('Connections'),
        ),
        FilledButton.icon(
          onPressed: sync.isLoading
              ? null
              : () => ref
                    .read(syncControllerProvider.notifier)
                    .run(SyncReason.manual),
          icon: sync.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          label: const Text('Refresh'),
        ),
      ],
      child: recordsValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyState(
          icon: Icons.storage_rounded,
          title: 'Could not open academic cache',
          message: error.toString(),
        ),
        data: (records) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (connections != null && !connections.anyConfigured) ...[
              _Banner(
                icon: Icons.link_off_rounded,
                text:
                    'Academic sources are not connected yet. Connect ISEP Portal and/or Moodle to replace empty placeholders with your real timetable, grades, notices, and assignments.',
              ),
              const SizedBox(height: 12),
            ],
            _SyncResultBanner(
              loading: sync.isLoading,
              error: sync.error,
              completed: sync.valueOrNull != null,
            ),
            const SizedBox(height: 16),
            _AcademicSectionNavigation(
              selected: _section,
              onSelected: (value) => setState(() => _section = value),
            ),
            const SizedBox(height: 22),
            switch (_section) {
              0 =>
                connections?.portalConfigured == false
                    ? _SourceSetupState(
                        source: 'ISEP Portal',
                        detail:
                            'Connect Portal to load your official schedule.',
                        onConnect: () =>
                            showAcademicConnectionsDialog(context, ref),
                      )
                    : _TimetableSection(
                        records: records,
                        weekStart: _weekStart,
                        onWeekChanged: (value) =>
                            setState(() => _weekStart = value),
                      ),
              1 => _TasksSection(records: records),
              2 =>
                connections?.anyConfigured == false
                    ? _SourceSetupState(
                        source: 'Portal or Moodle',
                        detail:
                            'Connect a source to load exams and assignments.',
                        onConnect: () =>
                            showAcademicConnectionsDialog(context, ref),
                      )
                    : _EvaluationSection(
                        records: records,
                        subjects:
                            ref.watch(activeSubjectsProvider).valueOrNull ??
                            const [],
                      ),
              3 =>
                connections?.portalConfigured == false
                    ? _SourceSetupState(
                        source: 'ISEP Portal',
                        detail:
                            'Connect Portal to load grades, history, and ECTS progress.',
                        onConnect: () =>
                            showAcademicConnectionsDialog(context, ref),
                      )
                    : _ProgressSection(
                        records: records,
                        subjects:
                            ref.watch(activeSubjectsProvider).valueOrNull ??
                            const [],
                      ),
              4 =>
                connections?.anyConfigured == false
                    ? _SourceSetupState(
                        source: 'Portal or Moodle',
                        detail:
                            'Connect a source to receive official notices and course announcements.',
                        onConnect: () =>
                            showAcademicConnectionsDialog(context, ref),
                      )
                    : _UpdatesSection(
                        records: records,
                        subjects:
                            ref.watch(activeSubjectsProvider).valueOrNull ??
                            const [],
                      ),
              5 =>
                connections?.portalConfigured == false
                    ? _SourceSetupState(
                        source: 'ISEP Portal',
                        detail:
                            'Connect Portal to load FUC data and official lesson summaries.',
                        onConnect: () =>
                            showAcademicConnectionsDialog(context, ref),
                      )
                    : _CourseContextSection(records: records),
              6 => _AcademicSearchSection(
                subjects: ref.watch(subjectsProvider).valueOrNull ?? const [],
              ),
              _ =>
                connections?.portalConfigured == false
                    ? _SourceSetupState(
                        source: 'ISEP Portal',
                        detail:
                            'Connect Portal to load tuition, fees, and payment deadlines.',
                        onConnect: () =>
                            showAcademicConnectionsDialog(context, ref),
                      )
                    : _FinanceSection(records: records),
            },
          ],
        ),
      ),
    );
  }
}

class _AcademicSectionNavigation extends StatelessWidget {
  const _AcademicSectionNavigation({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  static const _study = [
    _AcademicDestination(0, Icons.view_week_rounded, 'Timetable'),
    _AcademicDestination(1, Icons.task_alt_rounded, 'Tasks'),
    _AcademicDestination(2, Icons.event_rounded, 'Evaluations'),
    _AcademicDestination(3, Icons.calculate_rounded, 'Progress'),
  ];

  static const _reference = [
    _AcademicDestination(4, Icons.campaign_rounded, 'Updates'),
    _AcademicDestination(5, Icons.menu_book_rounded, 'Course context'),
    _AcademicDestination(6, Icons.manage_search_rounded, 'Search & ask'),
    _AcademicDestination(7, Icons.account_balance_wallet_outlined, 'Finance'),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        _AcademicNavCard(
          index: '01',
          title: 'Study',
          subtitle: 'Plan, tasks, assessment',
          destinations: _study,
          selected: selected,
          onSelected: onSelected,
        ),
        _AcademicNavCard(
          index: '02',
          title: 'Reference & admin',
          subtitle: 'Official context and services',
          destinations: _reference,
          selected: selected,
          onSelected: onSelected,
        ),
      ];
      if (constraints.maxWidth >= 900) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards.first),
            const SizedBox(width: 12),
            Expanded(child: cards.last),
          ],
        );
      }
      return Column(
        children: [cards.first, const SizedBox(height: 10), cards.last],
      );
    },
  );
}

class _AcademicNavCard extends StatelessWidget {
  const _AcademicNavCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final String index;
  final String title;
  final String subtitle;
  final List<_AcademicDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: colors.tertiary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          index,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.tertiary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: theme.textTheme.titleMedium),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final destination in destinations)
                          ChoiceChip(
                            avatar: Icon(destination.icon, size: 18),
                            label: Text(destination.label),
                            selected: selected == destination.value,
                            showCheckmark: false,
                            onSelected: (_) => onSelected(destination.value),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademicDestination {
  const _AcademicDestination(this.value, this.icon, this.label);

  final int value;
  final IconData icon;
  final String label;
}

class _SyncResultBanner extends StatelessWidget {
  const _SyncResultBanner({
    required this.loading,
    required this.error,
    required this.completed,
  });
  final bool loading;
  final Object? error;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LinearProgressIndicator();
    if (error != null) {
      return _Banner(
        icon: Icons.error_outline_rounded,
        text: error.toString(),
        error: true,
      );
    }
    if (!completed) return const SizedBox.shrink();
    return const _Banner(
      icon: Icons.cloud_done_rounded,
      text: 'Sync completed. Academic cache refreshed from configured sources.',
    );
  }
}

class _SourceSetupState extends StatelessWidget {
  const _SourceSetupState({
    required this.source,
    required this.detail,
    required this.onConnect,
  });
  final String source;
  final String detail;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.link_off_rounded,
    title: '$source is not configured',
    message: detail,
    action: FilledButton.icon(
      onPressed: onConnect,
      icon: const Icon(Icons.link_rounded),
      label: const Text('Open connections'),
    ),
  );
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.records});
  final List<AcademicRecord> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskRecords = records
        .where((record) => record.kind == AcademicRecordKind.lectureTask)
        .toList();
    taskRecords.sort((a, b) {
      final status = (a.payload['status'] as String? ?? '').compareTo(
        b.payload['status'] as String? ?? '',
      );
      if (status != 0) return status;
      return (a.startsAt ?? DateTime(9999)).compareTo(
        b.startsAt ?? DateTime(9999),
      );
    });
    if (taskRecords.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No lecture actions yet',
        message:
            'Explicit assignments and deadlines appear here after a lecture is summarized. Ambiguous items wait for your review.',
      );
    }
    final grouped = groupBy(
      taskRecords,
      (record) => record.payload['subjectName'] as String? ?? 'Other',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Banner(
          icon: Icons.fact_check_outlined,
          text:
              'Only explicit lecture instructions become tasks. Completing, dismissing, or editing one survives summary regeneration.',
        ),
        const SizedBox(height: 14),
        for (final entry in grouped.entries) ...[
          SectionHeader(entry.key),
          Card(
            child: Column(
              children: [
                for (final record in entry.value) _TaskTile(record: record),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.record});
  final AcademicRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = LectureTask.fromJson(record.payload);
    final completed = task.status == LectureTaskStatus.completed;
    final dismissed = task.status == LectureTaskStatus.dismissed;
    return ExpansionTile(
      leading: Icon(
        completed
            ? Icons.check_circle_rounded
            : dismissed
            ? Icons.cancel_outlined
            : task.needsReview
            ? Icons.help_outline_rounded
            : Icons.radio_button_unchecked_rounded,
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: completed || dismissed
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      subtitle: Text(
        [
          if (task.dueAt != null)
            DateFormat.yMMMd().add_Hm().format(task.dueAt!),
          if (task.dueAt == null) 'No confirmed deadline',
          if (task.needsReview) 'Needs review',
        ].join(' · '),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            task.description.isEmpty
                ? task.supportingSegment
                : task.description,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Evidence: “${task.supportingSegment}”${task.timestampSeconds == null ? '' : ' · ${task.timestampSeconds!.round()}s'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _editTask(context, ref, record, task),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            TextButton.icon(
              onPressed: () => ref
                  .read(academicHubActionsProvider)
                  .updateLectureTask(
                    record,
                    status: completed
                        ? LectureTaskStatus.pending
                        : LectureTaskStatus.completed,
                  ),
              icon: Icon(completed ? Icons.undo_rounded : Icons.check_rounded),
              label: Text(completed ? 'Reopen' : 'Complete'),
            ),
            TextButton.icon(
              onPressed: () => ref
                  .read(academicHubActionsProvider)
                  .updateLectureTask(
                    record,
                    status: dismissed
                        ? LectureTaskStatus.pending
                        : LectureTaskStatus.dismissed,
                  ),
              icon: const Icon(Icons.close_rounded),
              label: Text(dismissed ? 'Restore' : 'Dismiss'),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _editTask(
  BuildContext context,
  WidgetRef ref,
  AcademicRecord record,
  LectureTask task,
) async {
  final title = TextEditingController(text: task.title);
  final description = TextEditingController(text: task.description);
  var dueAt = task.dueAt;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Review lecture task'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Task'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Details'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  dueAt == null
                      ? 'No confirmed deadline'
                      : DateFormat.yMMMd().add_Hm().format(dueAt!),
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: dueAt ?? DateTime.now(),
                  );
                  if (date != null) setDialogState(() => dueAt = date);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(academicHubActionsProvider)
                  .updateLectureTask(
                    record,
                    title: title.text.trim(),
                    description: description.text.trim(),
                    dueAt: dueAt,
                    clearDueAt: dueAt == null,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  description.dispose();
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.records, required this.subjects});
  final List<AcademicRecord> records;
  final List<AcademicSubject> subjects;

  @override
  Widget build(BuildContext context) {
    final history = records
        .where((item) => item.kind == AcademicRecordKind.academicHistory)
        .map((item) => GradeComponent.fromJson(item.payload))
        .toList();
    final registrations = records
        .where((item) => item.kind == AcademicRecordKind.examRegistration)
        .toList();
    final enrolled = records
        .where((item) => item.kind == AcademicRecordKind.enrollment)
        .toList();
    final earned = history
        .where((item) {
          final status = SubjectMapper.normalize(item.academicStatus ?? '');
          return (item.value != null && item.value! >= 10) ||
              status.contains('aprov') ||
              status.contains('credit');
        })
        .fold<double>(0, (sum, item) => sum + (item.ects ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${earned.toStringAsFixed(1)} ECTS confirmed',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${enrolled.length} currently enrolled · ${history.length} history records · read-only Portal data',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (registrations.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader('Exam registration'),
          Card(
            child: Column(
              children: [
                for (final record in registrations)
                  ListTile(
                    leading: const Icon(Icons.how_to_reg_outlined),
                    title: Text(record.title),
                    subtitle: Text(
                      [
                        record.payload['state'] as String? ?? 'unknown',
                        if (record.endsAt != null)
                          'closes ${DateFormat.yMMMd().format(record.endsAt!)}',
                        if (record.payload['fee'] case final String fee) fee,
                      ].join(' · '),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _GradesSection(records: records, subjects: subjects),
      ],
    );
  }
}

class _FinanceSection extends ConsumerWidget {
  const _FinanceSection({required this.records});
  final List<AcademicRecord> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final charges =
        records
            .where((item) => item.kind == AcademicRecordKind.tuitionCharge)
            .toList()
          ..sort((a, b) {
            final aCharge = TuitionCharge.fromJson(a.payload);
            final bCharge = TuitionCharge.fromJson(b.payload);
            final overdue = bCharge.isOverdueAt(now) == aCharge.isOverdueAt(now)
                ? 0
                : bCharge.isOverdueAt(now)
                ? 1
                : -1;
            if (overdue != 0) return overdue;
            return (aCharge.dueAt ?? DateTime(9999)).compareTo(
              bCharge.dueAt ?? DateTime(9999),
            );
          });
    final open = charges
        .map((record) => TuitionCharge.fromJson(record.payload))
        .where((charge) => charge.isOpenAt(now))
        .toList();
    final outstanding = open.fold<double>(
      0,
      (sum, charge) => sum + (charge.outstandingAmount ?? charge.amount ?? 0),
    );
    final overdueCount = open.where((charge) => charge.isOverdueAt(now)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  overdueCount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.account_balance_wallet_outlined,
                  size: 36,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_euro(outstanding)} currently open',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        overdueCount > 0
                            ? '$overdueCount overdue item${overdueCount == 1 ? '' : 's'} · verify in Portal'
                            : '${open.length} open item${open.length == 1 ? '' : 's'} · read-only Portal data',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _Banner(
          icon: Icons.lock_outline_rounded,
          text:
              'ClassSync only tracks official Portal charges. It never makes, guarantees, or stores payment details.',
        ),
        const SizedBox(height: 14),
        if (charges.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No tuition or fee items cached',
            message:
                'Refresh after Portal exposes your financial page. No payment is made through ClassSync.',
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < charges.length; index++) ...[
                  _TuitionChargeTile(record: charges[index]),
                  if (index < charges.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TuitionChargeTile extends ConsumerWidget {
  const _TuitionChargeTile({required this.record});
  final AcademicRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = TuitionCharge.fromJson(record.payload);
    final now = DateTime.now();
    final overdue = charge.isOverdueAt(now);
    final paid = charge.state == TuitionPaymentState.paid;
    final amount = charge.outstandingAmount ?? charge.amount;
    final state = overdue
        ? 'Overdue'
        : paid
        ? 'Paid'
        : charge.state.name;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: overdue
            ? Theme.of(context).colorScheme.errorContainer
            : null,
        child: Icon(
          paid
              ? Icons.check_rounded
              : overdue
              ? Icons.priority_high_rounded
              : Icons.receipt_long_outlined,
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(record.title)),
          if (record.changedFields.isNotEmpty)
            const Tooltip(
              message: 'Official amount, date, or payment state changed',
              child: Icon(Icons.change_circle_rounded),
            ),
        ],
      ),
      subtitle: Text(
        [
          state,
          if (amount != null) _euro(amount),
          if (charge.dueAt != null)
            'due ${DateFormat.yMMMd().format(charge.dueAt!)}',
          if (charge.academicYear != null) charge.academicYear!,
          if (charge.hasLateInterest) 'late interest reported',
          if (charge.paymentReferenceHint != null)
            'ref ${charge.paymentReferenceHint}',
        ].join(' · '),
      ),
      onTap: charge.sourceUrl.isEmpty
          ? null
          : () => unawaited(
              ref.read(academicHubActionsProvider).openSource(charge.sourceUrl),
            ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Payment reminder',
        icon: Icon(
          charge.reminderMinutes == null && !charge.overdueReminder
              ? Icons.notifications_none_rounded
              : Icons.notifications_active_rounded,
        ),
        onSelected: (value) => unawaited(
          ref.read(academicHubActionsProvider).setTuitionReminder(
            record,
            switch (value) {
              'day' => 1440,
              'week' => 10080,
              _ => null,
            },
            overdueReminder: value == 'overdue'
                ? !charge.overdueReminder
                : charge.overdueReminder,
          ),
        ),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'day', child: Text('1 day before')),
          const PopupMenuItem(value: 'week', child: Text('1 week before')),
          PopupMenuItem(
            value: 'overdue',
            child: Text(
              charge.overdueReminder
                  ? 'Turn overdue alert off'
                  : 'Alert when overdue',
            ),
          ),
          const PopupMenuItem(
            value: 'off',
            child: Text('Turn due reminder off'),
          ),
        ],
      ),
    );
  }
}

String _euro(double amount) => NumberFormat.currency(
  locale: 'pt_PT',
  symbol: '€',
  decimalDigits: 2,
).format(amount);

class _UpdatesSection extends ConsumerWidget {
  const _UpdatesSection({required this.records, required this.subjects});
  final List<AcademicRecord> records;
  final List<AcademicSubject> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices =
        records
            .where((item) => item.kind == AcademicRecordKind.portalNotification)
            .toList()
          ..sort(
            (a, b) => (b.startsAt ?? DateTime(0)).compareTo(
              a.startsAt ?? DateTime(0),
            ),
          );
    bool updateEnabled(String source) =>
        records
                .where(
                  (item) =>
                      item.kind == AcademicRecordKind.reminderPreference &&
                      item.externalId == 'updates:$source',
                )
                .firstOrNull
                ?.payload['enabled']
            as bool? ??
        true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: updateEnabled('portalNotification'),
                onChanged: (value) => ref
                    .read(academicHubActionsProvider)
                    .setAcademicUpdateNotifications(
                      'portalNotification',
                      value,
                    ),
                title: const Text('Portal notice alerts'),
                subtitle: const Text('New official electronic notices'),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                value: updateEnabled('moodleAnnouncement'),
                onChanged: (value) => ref
                    .read(academicHubActionsProvider)
                    .setAcademicUpdateNotifications(
                      'moodleAnnouncement',
                      value,
                    ),
                title: const Text('Moodle announcement alerts'),
                subtitle: const Text('Stored independently from Portal alerts'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (notices.isNotEmpty) ...[
          const SectionHeader('Official Portal notices'),
          Card(
            child: Column(
              children: [
                for (final notice in notices)
                  ListTile(
                    leading: Icon(
                      notice.payload['read'] == true
                          ? Icons.drafts_outlined
                          : Icons.mark_email_unread_outlined,
                    ),
                    title: Text(notice.title),
                    subtitle: Text(
                      [
                        if ((notice.payload['sender'] as String? ?? '')
                            .isNotEmpty)
                          notice.payload['sender'] as String,
                        if (notice.startsAt != null)
                          DateFormat.yMMMd().format(notice.startsAt!),
                        notice.payload['message'] as String? ?? '',
                      ].join(' · '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => ref
                        .read(academicHubActionsProvider)
                        .markPortalNotificationRead(notice),
                    trailing: const Tooltip(
                      message: 'Official Portal source',
                      child: Icon(Icons.verified_outlined),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        _MoodleSection(records: records, subjects: subjects),
      ],
    );
  }
}

class _CourseContextSection extends StatelessWidget {
  const _CourseContextSection({required this.records});
  final List<AcademicRecord> records;

  @override
  Widget build(BuildContext context) {
    final profiles = records
        .where((item) => item.kind == AcademicRecordKind.fucProfile)
        .toList();
    final lessons = records
        .where((item) => item.kind == AcademicRecordKind.lessonSummary)
        .toList();
    if (profiles.isEmpty && lessons.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No course context cached yet',
        message:
            'Refresh Portal to import FUC details and official lesson summaries.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profiles.isNotEmpty) ...[
          const SectionHeader('FUC · approved course information'),
          for (final profile in profiles)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(profile.title),
                subtitle: Text(
                  '${profile.payload['subjectCode'] ?? ''} · ${profile.payload['academicYear'] ?? ''}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final entry in const {
                    'objectives': 'Objectives & outcomes',
                    'syllabus': 'Syllabus',
                    'methodologies': 'Methodologies',
                    'evaluationRules': 'Evaluation rules',
                    'bibliography': 'Bibliography',
                  }.entries)
                    if ((profile.payload[entry.key] as List<dynamic>? ??
                            const [])
                        .isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        subtitle: Text(
                          (profile.payload[entry.key] as List<dynamic>).join(
                            '\n',
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
        if (lessons.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionHeader('Official lesson summaries'),
          Card(
            child: Column(
              children: [
                for (final lesson in lessons)
                  ListTile(
                    leading: Icon(
                      lesson.payload['coverageNeedsReview'] == true
                          ? Icons.rule_folder_outlined
                          : Icons.fact_check_outlined,
                    ),
                    title: Text(lesson.title),
                    subtitle: Text(
                      [
                        if (lesson.startsAt != null)
                          DateFormat.yMMMd().format(lesson.startsAt!),
                        lesson.payload['text'] as String? ?? '',
                        if (lesson.payload['coverageNeedsReview'] == true)
                          'Generated notes may not cover the official summary; review both.',
                      ].join(' · '),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: lesson.payload['matchedLectureId'] == null
                        ? const Tooltip(
                            message: 'No lecture match',
                            child: Icon(Icons.link_off_rounded),
                          )
                        : const Tooltip(
                            message: 'Matched by subject and time',
                            child: Icon(Icons.compare_arrows_rounded),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AcademicSearchSection extends ConsumerStatefulWidget {
  const _AcademicSearchSection({required this.subjects});
  final List<AcademicSubject> subjects;

  @override
  ConsumerState<_AcademicSearchSection> createState() =>
      _AcademicSearchSectionState();
}

class _AcademicSearchSectionState
    extends ConsumerState<_AcademicSearchSection> {
  final _query = TextEditingController();
  List<AcademicSearchHit> _hits = const [];
  AcademicGroundedAnswer? _answer;
  String? _subjectId;
  String? _semester;
  AcademicRecordKind? _kind;
  int? _recentDays;
  bool _busy = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run({required bool ask}) async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _busy = true;
      _answer = null;
    });
    try {
      final service = ref.read(academicResearchServiceProvider);
      final semesterIds = _semester == null
          ? null
          : widget.subjects
                .where((subject) => subject.semesterLabel == _semester)
                .map((subject) => subject.notionId)
                .toSet();
      final from = _recentDays == null
          ? null
          : DateTime.now().subtract(Duration(days: _recentDays!));
      final kinds = _kind == null ? null : {_kind!};
      final hits = await service.search(
        query,
        subjectId: _subjectId,
        subjectIds: semesterIds,
        kinds: kinds,
        from: from,
      );
      final answer = ask
          ? await service.ask(
              query,
              subjectId: _subjectId,
              subjectIds: semesterIds,
              kinds: kinds,
              from: from,
            )
          : null;
      if (mounted) {
        setState(() {
          _hits = hits;
          _answer = answer;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _query,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _run(ask: false),
        decoration: const InputDecoration(
          labelText: 'Search your study content',
          hintText: 'A concept, deadline, formula, or teacher remark',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 760
              ? (constraints.maxWidth - 24) / 4
              : constraints.maxWidth;
          final semesters =
              widget.subjects
                  .map((subject) => subject.semesterLabel)
                  .toSet()
                  .toList()
                ..sort();
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String?>(
                  initialValue: _subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All subjects'),
                    ),
                    ...widget.subjects.map(
                      (subject) => DropdownMenuItem<String?>(
                        value: subject.notionId,
                        child: Text(subject.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _subjectId = value),
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String?>(
                  initialValue: _semester,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All semesters'),
                    ),
                    ...semesters.map(
                      (semester) => DropdownMenuItem<String?>(
                        value: semester,
                        child: Text(semester),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _semester = value),
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<AcademicRecordKind?>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Content type'),
                  items: const [
                    DropdownMenuItem<AcademicRecordKind?>(
                      value: null,
                      child: Text('All content'),
                    ),
                    DropdownMenuItem(
                      value: AcademicRecordKind.lessonSummary,
                      child: Text('Lecture summaries'),
                    ),
                    DropdownMenuItem(
                      value: AcademicRecordKind.fucProfile,
                      child: Text('FUC / syllabus'),
                    ),
                    DropdownMenuItem(
                      value: AcademicRecordKind.lectureTask,
                      child: Text('Tasks'),
                    ),
                    DropdownMenuItem(
                      value: AcademicRecordKind.announcement,
                      child: Text('Announcements'),
                    ),
                    DropdownMenuItem(
                      value: AcademicRecordKind.portalNotification,
                      child: Text('Portal notices'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _kind = value),
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<int?>(
                  initialValue: _recentDays,
                  decoration: const InputDecoration(labelText: 'Date'),
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Any date'),
                    ),
                    DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                    DropdownMenuItem(value: 180, child: Text('Last 6 months')),
                    DropdownMenuItem(value: 365, child: Text('Last year')),
                  ],
                  onChanged: (value) => setState(() => _recentDays = value),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(ask: false),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search locally'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(ask: true),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Ask from evidence'),
          ),
        ],
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator(),
        ),
      if (_answer case final answer?) ...[
        const SizedBox(height: 14),
        Card(
          color: answer.insufficientEvidence
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  answer.insufficientEvidence
                      ? 'Evidence is incomplete'
                      : 'Grounded answer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(answer.answer),
                if (answer.citationIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sources: ${answer.citationIds.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 14),
      if (_hits.isEmpty && !_busy)
        const EmptyState(
          icon: Icons.manage_search_rounded,
          title: 'Search stays local by default',
          message:
              'Keyword search does not call Gemini. “Ask from evidence” sends only the matching excerpts and returns source ids.',
        ),
      for (final hit in _hits)
        Card(
          child: ListTile(
            leading: Icon(
              hit.source == AcademicSource.portal
                  ? Icons.verified_outlined
                  : Icons.notes_rounded,
            ),
            title: Text(hit.title),
            subtitle: Text(
              hit.excerpt,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('${hit.score}'),
          ),
        ),
    ],
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.error = false});
  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Card(
    color: error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.surfaceContainerHigh,
    child: ListTile(leading: Icon(icon), title: Text(text)),
  );
}

class _TimetableSection extends StatelessWidget {
  const _TimetableSection({
    required this.records,
    required this.weekStart,
    required this.onWeekChanged,
  });
  final List<AcademicRecord> records;
  final DateTime weekStart;
  final ValueChanged<DateTime> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 7));
    final slots =
        records
            .where((item) => item.kind == AcademicRecordKind.timetable)
            .map((item) => TimetableSlot.fromJson(item.payload))
            .where(
              (item) =>
                  !item.start.isBefore(weekStart) && item.start.isBefore(end),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
              onPressed: () =>
                  onWeekChanged(weekStart.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${DateFormat.MMMd().format(weekStart)} – ${DateFormat.yMMMd().format(end.subtract(const Duration(days: 1)))}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: () => onWeekChanged(end),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (slots.isEmpty)
          const EmptyState(
            icon: Icons.view_week_outlined,
            title: 'No timetable slots cached for this week',
            message: 'Refresh Portal data or move to another week.',
          )
        else
          for (final day in List.generate(
            7,
            (index) => weekStart.add(Duration(days: index)),
          ))
            if (slots.any((slot) => _sameDay(slot.start, day))) ...[
              SectionHeader(DateFormat.EEEE().format(day)),
              Card(
                child: Column(
                  children: [
                    for (final slot in slots.where(
                      (item) => _sameDay(item.start, day),
                    ))
                      ListTile(
                        leading: Text(DateFormat.Hm().format(slot.start)),
                        title: Text(slot.subjectName),
                        subtitle: Text(
                          [
                            if (slot.lessonType != null) slot.lessonType!,
                            if (slot.className != null) slot.className!,
                            if (slot.room != null) slot.room!,
                            if (slot.lecturer != null) slot.lecturer!,
                          ].join(' · '),
                        ),
                        trailing: slot.subjectId == null
                            ? const Tooltip(
                                message: 'Subject mapping needs review',
                                child: Icon(Icons.link_off_rounded),
                              )
                            : Text(DateFormat.Hm().format(slot.end)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
      ],
    );
  }
}

class _EvaluationSection extends ConsumerWidget {
  const _EvaluationSection({required this.records, required this.subjects});
  final List<AcademicRecord> records;
  final List<AcademicSubject> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventRecords = records
        .where((item) => item.kind == AcademicRecordKind.evaluation)
        .toList();
    final taskEvents = records
        .where((item) => item.kind == AcademicRecordKind.lectureTask)
        .map((record) => LectureTask.fromJson(record.payload))
        .where(
          (task) =>
              task.dueAt != null && task.status == LectureTaskStatus.pending,
        )
        .map(
          (task) => EvaluationEvent(
            externalId: task.id,
            title: task.title,
            type: 'Lecture task',
            subjectName: task.subjectName,
            subjectId: task.subjectId,
            start: task.dueAt!,
            provenance: [
              AcademicProvenance(
                source: AcademicSource.manual,
                externalId: task.sourceLectureId,
              ),
            ],
          ),
        );
    final events =
        EvaluationMerger.merge([
              ...eventRecords.map(
                (record) => EvaluationEvent.fromJson(
                  record.payload,
                  changedFields: record.changedFields,
                ),
              ),
              ...taskEvents,
            ])
            .where(
              (item) => item.start.isAfter(
                DateTime.now().subtract(const Duration(days: 1)),
              ),
            )
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: events.isEmpty
                    ? null
                    : () => _setTypeReminder(context, ref, events),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Reminder defaults'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addEvaluation(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Manual evaluation'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const EmptyState(
            icon: Icons.event_available_outlined,
            title: 'No upcoming evaluations',
            message:
                'Portal exams, Moodle assignments, and manual events share this offline agenda.',
          )
        else ...[
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Calendar view'),
              subtitle: const Text('Select a date to inspect its evaluations'),
              children: [_EvaluationCalendar(events: events)],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < events.length; index++) ...[
                  _EvaluationTile(
                    event: events[index],
                    onOpen: (url) => unawaited(
                      ref.read(academicHubActionsProvider).openSource(url),
                    ),
                    onReminder: (minutes) {
                      final source = events[index].provenance.first;
                      final record = eventRecords
                          .where(
                            (item) =>
                                item.source == source.source &&
                                item.externalId == source.externalId,
                          )
                          .firstOrNull;
                      if (record != null) {
                        unawaited(
                          ref
                              .read(academicHubActionsProvider)
                              .setEvaluationReminder(record, minutes),
                        );
                      }
                    },
                  ),
                  if (index < events.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _setTypeReminder(
    BuildContext context,
    WidgetRef ref,
    List<EvaluationEvent> events,
  ) async {
    final types = events.map((item) => item.type).toSet().toList()..sort();
    var type = types.first;
    int? minutes = 1440;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reminder default by type'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Evaluation type',
                  ),
                  items: [
                    for (final value in types)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => type = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: minutes,
                  decoration: const InputDecoration(
                    labelText: 'Default reminder',
                  ),
                  items: const [
                    DropdownMenuItem(value: 60, child: Text('1 hour before')),
                    DropdownMenuItem(value: 1440, child: Text('1 day before')),
                    DropdownMenuItem(
                      value: 10080,
                      child: Text('1 week before'),
                    ),
                    DropdownMenuItem(value: null, child: Text('Off')),
                  ],
                  onChanged: (value) => setState(() => minutes = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(academicHubActionsProvider)
                    .setEvaluationTypeReminder(type, minutes);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEvaluation(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    var selectedSubject = subjects.firstOrNull;
    var date = DateTime.now().add(const Duration(days: 7));
    var time = const TimeOfDay(hour: 9, minute: 0);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Manual evaluation'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AcademicSubject>(
                  initialValue: selectedSubject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => selectedSubject = value,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final value = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1460),
                            ),
                            initialDate: date,
                          );
                          if (value != null) setState(() => date = value);
                        },
                        child: Text(DateFormat.yMMMd().format(date)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final value = await showTimePicker(
                            context: context,
                            initialTime: time,
                          );
                          if (value != null) setState(() => time = value);
                        },
                        child: Text(time.format(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || selectedSubject == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a title and subject.')),
                  );
                  return;
                }
                final start = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                final id = 'manual-${DateTime.now().microsecondsSinceEpoch}';
                await ref
                    .read(academicHubActionsProvider)
                    .addManualEvaluation(
                      EvaluationEvent(
                        externalId: id,
                        title: title.text.trim(),
                        type: 'Manual evaluation',
                        subjectId: selectedSubject!.notionId,
                        subjectName: selectedSubject!.name,
                        start: start,
                        provenance: [
                          AcademicProvenance(
                            source: AcademicSource.manual,
                            externalId: id,
                          ),
                        ],
                      ),
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
  }
}

class _EvaluationCalendar extends StatefulWidget {
  const _EvaluationCalendar({required this.events});

  final List<EvaluationEvent> events;

  @override
  State<_EvaluationCalendar> createState() => _EvaluationCalendarState();
}

class _EvaluationCalendarState extends State<_EvaluationCalendar> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.events.first.start;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final earliest = widget.events
        .map((item) => item.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = widget.events
        .map((item) => item.start)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final firstDate = earliest.isBefore(now.subtract(const Duration(days: 365)))
        ? earliest
        : now.subtract(const Duration(days: 365));
    final lastDate = latest.isAfter(now.add(const Duration(days: 1460)))
        ? latest
        : now.add(const Duration(days: 1460));
    final selectedEvents = widget.events
        .where((item) => _sameDay(item.start, _selected))
        .toList();
    return Column(
      children: [
        CalendarDatePicker(
          initialDate: _selected,
          firstDate: firstDate,
          lastDate: lastDate,
          onDateChanged: (value) => setState(() => _selected = value),
        ),
        if (selectedEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No evaluations on this date.'),
          )
        else
          for (final event in selectedEvents)
            ListTile(
              leading: const Icon(Icons.event_rounded),
              title: Text(event.title),
              subtitle: Text(
                '${DateFormat.Hm().format(event.start)} · ${event.type}',
              ),
            ),
      ],
    );
  }
}

class _EvaluationTile extends StatelessWidget {
  const _EvaluationTile({
    required this.event,
    required this.onReminder,
    required this.onOpen,
  });
  final EvaluationEvent event;
  final ValueChanged<int?> onReminder;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: SizedBox(
      width: 54,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(DateFormat.MMM().format(event.start).toUpperCase()),
          Text(
            '${event.start.day}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ),
    title: Row(
      children: [
        Expanded(child: Text(event.title)),
        if (event.changedFields.isNotEmpty)
          const Tooltip(
            message: 'Official date/details changed since last sync',
            child: Icon(Icons.change_circle_rounded),
          ),
      ],
    ),
    subtitle: Text(
      [
        DateFormat.Hm().format(event.start),
        if (event.location != null) event.location!,
        event.provenance.map((item) => item.source.name).join(' + '),
        if (event.registrationState != ExamRegistrationState.unknown)
          'registration: ${event.registrationState.name}',
      ].join(' · '),
    ),
    onTap: () {
      final url = event.provenance
          .map((item) => item.url)
          .whereType<String>()
          .firstOrNull;
      if (url != null) {
        onOpen(url);
      }
    },
    trailing: PopupMenuButton<int>(
      tooltip: 'Reminder',
      icon: Icon(
        event.reminderMinutes == null
            ? Icons.notifications_none_rounded
            : Icons.notifications_active_rounded,
      ),
      onSelected: (value) => onReminder(value < 0 ? null : value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 60, child: Text('1 hour before')),
        PopupMenuItem(value: 1440, child: Text('1 day before')),
        PopupMenuItem(value: 10080, child: Text('1 week before')),
        PopupMenuItem(value: -1, child: Text('Off')),
      ],
    ),
  );
}

class _GradesSection extends ConsumerWidget {
  const _GradesSection({required this.records, required this.subjects});
  final List<AcademicRecord> records;
  final List<AcademicSubject> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = records
        .where((item) => item.kind == AcademicRecordKind.grade)
        .map((item) => GradeComponent.fromJson(item.payload))
        .toList();
    final grouped = <String, List<GradeComponent>>{};
    for (final grade in grades) {
      (grouped[grade.subjectId ?? grade.subjectName] ??= []).add(grade);
    }
    final formulaRecords = records
        .where((item) => item.kind == AcademicRecordKind.gradeFormula)
        .toList();
    final formulas = <String, List<AcademicRecord>>{};
    for (final record in formulaRecords) {
      final formula = AssessmentFormula.fromJson(record.payload);
      (formulas[record.subjectId ?? formula.subjectName ?? 'Unknown'] ??= [])
          .add(record);
    }
    final subjectKeys = {...grouped.keys, ...formulas.keys}.toList();
    final officialCount = grades
        .where((item) => item.source == GradeValueSource.officialPortal)
        .length;
    final manualCount = grades
        .where((item) => item.source == GradeValueSource.manual)
        .length;
    final earnedEcts = grades
        .where((item) => item.isHistorical && item.ects != null)
        .fold<double>(0, (sum, item) => sum + item.ects!);
    final changes =
        ref
            .watch(academicChangesProvider)
            .valueOrNull
            ?.where((item) => item.kind == AcademicRecordKind.grade.name)
            .where((item) => item.recordKey.startsWith('portal:grade:'))
            .toList() ??
        const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: subjects.isEmpty ? null : () => _addGrade(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Manual component'),
          ),
        ),
        const SizedBox(height: 12),
        if (subjectKeys.isNotEmpty) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_rounded),
              title: const Text('Semester overview'),
              subtitle: Text(
                '${subjectKeys.length} subjects · $officialCount official values · '
                '$manualCount provisional values · ${earnedEcts.toStringAsFixed(1)} earned ECTS',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (changes.isNotEmpty) ...[
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(
                '${changes.length} official grade change${changes.length == 1 ? '' : 's'} retained',
              ),
              children: [
                for (final change in changes)
                  Builder(
                    builder: (context) {
                      final previous = GradeComponent.fromJson(
                        jsonDecode(change.previousPayloadJson)
                            as Map<String, dynamic>,
                      );
                      return ListTile(
                        title: Text(
                          '${previous.subjectName} · ${previous.name}',
                        ),
                        subtitle: Text(
                          'Previous official value · ${DateFormat.yMMMd().add_Hm().format(change.changedAt.toLocal())}',
                        ),
                        trailing: Text(
                          previous.value?.toStringAsFixed(2) ?? '—',
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (subjectKeys.isEmpty)
          const EmptyState(
            icon: Icons.calculate_outlined,
            title: 'No grades cached',
            message:
                'Portal values stay official. Manual provisional values are always labeled.',
          )
        else
          for (final key in subjectKeys) ...[
            _SubjectGrades(
              title:
                  grouped[key]?.firstOrNull?.subjectName ??
                  AssessmentFormula.fromJson(
                    formulas[key]!.first.payload,
                  ).subjectName ??
                  'Subject',
              grades: grouped[key] ?? const [],
              formulaRecords: formulas[key] ?? const [],
              onConfirmFormula: (record) =>
                  ref.read(academicHubActionsProvider).confirmFormula(record),
            ),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  Future<void> _addGrade(BuildContext context, WidgetRef ref) async {
    var subject = subjects.first;
    final name = TextEditingController();
    final value = TextEditingController();
    final weight = TextEditingController();
    final minimum = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manual grade component'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AcademicSubject>(
                  initialValue: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (item) {
                    if (item != null) subject = item;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Component'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Grade (0–20, blank if remaining)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Weight (%)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minimum,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Minimum grade (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final parsedWeight = _parseNumber(weight.text);
              final parsedValue = value.text.trim().isEmpty
                  ? null
                  : _parseNumber(value.text);
              if (name.text.trim().isEmpty ||
                  parsedWeight == null ||
                  parsedWeight <= 0 ||
                  parsedWeight > 100 ||
                  (parsedValue != null &&
                      (parsedValue < 0 || parsedValue > 20))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a component, weight 1–100, and grade 0–20.',
                    ),
                  ),
                );
                return;
              }
              await ref
                  .read(academicHubActionsProvider)
                  .addManualGrade(
                    GradeComponent(
                      externalId:
                          'manual-${DateTime.now().microsecondsSinceEpoch}',
                      subjectName: subject.name,
                      subjectId: subject.notionId,
                      name: name.text.trim(),
                      value: parsedValue,
                      weight: parsedWeight / 100,
                      minimum: _parseNumber(minimum.text),
                      source: GradeValueSource.manual,
                    ),
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    value.dispose();
    weight.dispose();
    minimum.dispose();
  }
}

class _SubjectGrades extends StatelessWidget {
  const _SubjectGrades({
    required this.title,
    required this.grades,
    required this.formulaRecords,
    required this.onConfirmFormula,
  });
  final String title;
  final List<GradeComponent> grades;
  final List<AcademicRecord> formulaRecords;
  final Future<void> Function(AcademicRecord) onConfirmFormula;

  @override
  Widget build(BuildContext context) {
    final current = grades.where((item) => !item.isHistorical).toList();
    final historical = grades.where((item) => item.isHistorical).toList();
    final weighted = current
        .where((item) => item.weight != null && item.confirmed)
        .toList();
    final formula = AssessmentFormula(
      id: 'current',
      label: 'Confirmed formula',
      components: weighted,
    );
    final targets = weighted.isEmpty
        ? const <double, GradeCalculation>{}
        : {
            for (final target in [9.5, 14.0, 16.0, 18.0])
              target: GradeCalculator.calculate(formula, target: target),
          };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final item in current)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text(
                  [
                    _gradeSourceLabel(item.source),
                    if (item.weight != null)
                      '${(item.weight! * 100).toStringAsFixed(0)}%',
                    if (item.minimum != null) 'minimum ${item.minimum}',
                    if (!item.confirmed) 'formula requires confirmation',
                  ].join(' · '),
                ),
                trailing: Text(item.value?.toStringAsFixed(2) ?? 'Remaining'),
              ),
            if (targets.isNotEmpty) ...[
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in targets.entries)
                    Chip(
                      label: Text(
                        entry.value.possible
                            ? 'Target ${entry.key}: ${entry.value.requiredAverage?.toStringAsFixed(2) ?? 'done'} needed'
                            : 'Target ${entry.key}: impossible',
                      ),
                    ),
                ],
              ),
            ] else
              const Text('Add confirmed weights to calculate targets.'),
            if (formulaRecords.isNotEmpty) ...[
              const Divider(),
              Text(
                'FUC evaluation formulas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final record in formulaRecords)
                _FormulaSummary(
                  record: record,
                  grades: current,
                  onConfirm: () => onConfirmFormula(record),
                ),
            ],
            if (historical.isNotEmpty) ...[
              const Divider(),
              Text(
                'Official history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final item in historical)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item.academicYear ?? 'Historical'} · ${item.name}',
                  ),
                  subtitle: Text(
                    [
                      'Official Portal result',
                      if (item.ects != null) '${item.ects} ECTS',
                    ].join(' · '),
                  ),
                  trailing: Text(item.value?.toStringAsFixed(1) ?? '—'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormulaSummary extends StatelessWidget {
  const _FormulaSummary({
    required this.record,
    required this.grades,
    required this.onConfirm,
  });

  final AcademicRecord record;
  final List<GradeComponent> grades;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final formula = AssessmentFormula.fromJson(record.payload);
    final components = formula.components.map((component) {
      final value = grades
          .where(
            (grade) =>
                SubjectMapper.normalize(grade.name) ==
                SubjectMapper.normalize(component.name),
          )
          .map((item) => item.value)
          .whereType<double>()
          .firstOrNull;
      return component.copyWith(value: value, keepValue: false);
    }).toList();
    final effective = formula.copyWith(components: components);
    final weight = components.fold<double>(
      0,
      (sum, component) => sum + (component.weight ?? 0),
    );
    final targets = !formula.confirmed || (weight - 1).abs() > 0.001
        ? const <double, GradeCalculation>{}
        : {
            for (final target in [9.5, 14.0, 16.0, 18.0])
              target: GradeCalculator.calculate(effective, target: target),
          };
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(formula.label)),
                if (!formula.confirmed)
                  FilledButton.tonal(
                    onPressed: (weight - 1).abs() <= 0.001 ? onConfirm : null,
                    child: const Text('Review and confirm'),
                  )
                else
                  const Chip(label: Text('Confirmed')),
              ],
            ),
            for (final component in components)
              Text(
                '${component.name}: ${((component.weight ?? 0) * 100).toStringAsFixed(0)}%'
                '${component.minimum == null ? '' : ' · minimum ${component.minimum}'}'
                '${component.value == null ? ' · remaining' : ' · ${component.value!.toStringAsFixed(2)}'}',
              ),
            if ((weight - 1).abs() > 0.001)
              Text(
                'Weights total ${(weight * 100).toStringAsFixed(0)}%; confirmation is blocked.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!formula.confirmed)
              const Text(
                'Imported from FUC. Calculations stay disabled until you confirm this structure.',
              ),
            if (targets.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in targets.entries)
                    Chip(
                      label: Text(
                        entry.value.possible
                            ? '${entry.key}: ${entry.value.requiredAverage?.toStringAsFixed(2) ?? 'done'} needed'
                            : '${entry.key}: impossible',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MoodleSection extends ConsumerWidget {
  const _MoodleSection({required this.records, required this.subjects});
  final List<AcademicRecord> records;
  final List<AcademicSubject> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = records
        .where((item) => item.kind == AcademicRecordKind.moodleCourse)
        .toList();
    final news =
        records
            .where((item) => item.kind == AcademicRecordKind.announcement)
            .toList()
          ..sort(
            (a, b) => (b.startsAt ?? DateTime(0)).compareTo(
              a.startsAt ?? DateTime(0),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Courses (${courses.length})'),
        if (courses.isEmpty)
          const EmptyState(
            icon: Icons.school_outlined,
            title: 'No Moodle courses cached',
            message: 'Add a Moodle Web Services token under Connections.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final course in courses)
                ActionChip(
                  avatar: Icon(
                    course.subjectId == null
                        ? Icons.link_off_rounded
                        : Icons.check_rounded,
                    size: 18,
                  ),
                  label: Text(course.title),
                  tooltip: course.subjectId == null
                      ? 'Choose the matching ClassSync subject'
                      : 'Open Moodle course',
                  onPressed: course.subjectId == null
                      ? () => _mapCourse(context, ref, course)
                      : () => unawaited(
                          ref
                              .read(academicHubActionsProvider)
                              .openSource(
                                course.payload['url'] as String? ?? '',
                              ),
                        ),
                ),
            ],
          ),
        const SizedBox(height: 24),
        const SectionHeader('Announcements'),
        if (news.isEmpty)
          const Text('No announcements cached.')
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < news.length; index++) ...[
                  ListTile(
                    title: Text(news[index].title),
                    subtitle: Text(
                      [
                        if (news[index].startsAt != null)
                          DateFormat.yMMMd().format(
                            news[index].startsAt!.toLocal(),
                          ),
                        if (news[index].payload['preview']
                            case final String preview when preview.isNotEmpty)
                          preview,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => unawaited(
                      ref
                          .read(academicHubActionsProvider)
                          .openSource(
                            news[index].payload['url'] as String? ?? '',
                          ),
                    ),
                  ),
                  if (index < news.length - 1) const Divider(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _mapCourse(
    BuildContext context,
    WidgetRef ref,
    AcademicRecord course,
  ) async {
    if (subjects.isEmpty) return;
    var selected = subjects.first;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Map ${course.title}'),
        content: DropdownButtonFormField<AcademicSubject>(
          initialValue: selected,
          decoration: const InputDecoration(labelText: 'ClassSync subject'),
          items: [
            for (final subject in subjects)
              DropdownMenuItem(value: subject, child: Text(subject.name)),
          ],
          onChanged: (value) {
            if (value != null) selected = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(academicHubActionsProvider)
                  .setMoodleCourseSubject(course, selected);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save mapping'),
          ),
        ],
      ),
    );
  }
}

DateTime _startOfWeek(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  return local.subtract(Duration(days: local.weekday - DateTime.monday));
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

double? _parseNumber(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

String _gradeSourceLabel(GradeValueSource source) => switch (source) {
  GradeValueSource.officialPortal => 'Official Portal value',
  GradeValueSource.fuc => 'FUC-derived',
  GradeValueSource.manual => 'Manual provisional value',
  GradeValueSource.inferred => 'Inferred — review required',
};
