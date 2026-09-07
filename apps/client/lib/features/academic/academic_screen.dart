import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../core/providers.dart';
import '../../domain/academic/academic_hub_actions.dart';
import '../../domain/academic/academic_hub_models.dart';
import '../../domain/academic/academic_models.dart';
import '../../domain/sync/sync_models.dart';
import '../shared/page_frame.dart';

class AcademicScreen extends ConsumerStatefulWidget {
  const AcademicScreen({super.key});

  @override
  ConsumerState<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends ConsumerState<AcademicScreen> {
  var _section = 0;
  late DateTime _weekStart = _startOfWeek(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final recordsValue = ref.watch(academicRecordsProvider);
    final sync = ref.watch(syncControllerProvider);
    return PageFrame(
      title: 'Academic',
      subtitle:
          'Portal, timetable, evaluations, Moodle, and grades — cached locally',
      actions: [
        OutlinedButton.icon(
          onPressed: () => _showConnections(context),
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
            _SyncResultBanner(
              loading: sync.isLoading,
              error: sync.error,
              completed: sync.valueOrNull != null,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.view_week_rounded),
                    label: Text('Timetable'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.event_rounded),
                    label: Text('Evaluations'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.calculate_rounded),
                    label: Text('Grades'),
                  ),
                  ButtonSegment(
                    value: 3,
                    icon: Icon(Icons.campaign_rounded),
                    label: Text('Moodle'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.single),
              ),
            ),
            const SizedBox(height: 22),
            switch (_section) {
              0 => _TimetableSection(
                records: records,
                weekStart: _weekStart,
                onWeekChanged: (value) => setState(() => _weekStart = value),
              ),
              1 => _EvaluationSection(
                records: records,
                subjects:
                    ref.watch(activeSubjectsProvider).valueOrNull ?? const [],
              ),
              2 => _GradesSection(
                records: records,
                subjects:
                    ref.watch(activeSubjectsProvider).valueOrNull ?? const [],
              ),
              _ => _MoodleSection(
                records: records,
                subjects:
                    ref.watch(activeSubjectsProvider).valueOrNull ?? const [],
              ),
            },
          ],
        ),
      ),
    );
  }

  Future<void> _showConnections(BuildContext context) async {
    final actions = ref.read(academicHubActionsProvider);
    final existingUser = await actions.readPortalUsername();
    if (!context.mounted) return;
    final user = TextEditingController(text: existingUser);
    final password = TextEditingController();
    final token = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Academic connections'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ISEP Portal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: user,
                  decoration: const InputDecoration(
                    labelText: 'Portal username or ISEP email',
                    helperText:
                        'Use the same account as portal.isep.ipp.pt. ISEP email suffix is removed automatically.',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText:
                        'Stored only in OS secure storage. Leave blank to keep current password.',
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Moodle ISEP',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: token,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Web Services token',
                    helperText:
                        'Token access is safer than storing another Moodle password.',
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
              try {
                if (user.text.trim().isNotEmpty) {
                  await actions.connectPortal(
                    username: user.text,
                    password: password.text.isEmpty ? null : password.text,
                  );
                }
                if (token.text.trim().isNotEmpty) {
                  await actions.connectMoodle(token.text);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } on AcademicActionFailure catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.message)));
              }
            },
            child: const Text('Test and save'),
          ),
        ],
      ),
    );
    user.dispose();
    password.dispose();
    token.dispose();
  }
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
    final events =
        EvaluationMerger.merge(
              eventRecords.map(
                (record) => EvaluationEvent.fromJson(
                  record.payload,
                  changedFields: record.changedFields,
                ),
              ),
            )
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
