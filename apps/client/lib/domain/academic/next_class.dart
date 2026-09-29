import 'academic_hub_models.dart';

List<TimetableSlot> upcomingClasses(
  Iterable<AcademicRecord> records,
  DateTime now, {
  Duration horizon = const Duration(days: 4),
}) {
  final cutoff = now.add(horizon);
  final upcoming = <TimetableSlot>[];
  for (final record in records) {
    if (record.kind != AcademicRecordKind.timetable) continue;
    try {
      final slot = TimetableSlot.fromJson(record.payload);
      final start = slot.start.toLocal();
      if (start.isAfter(now) && start.isBefore(cutoff)) upcoming.add(slot);
    } on FormatException {
      // Ignore malformed cache entries; the academic refresh owns repair.
    } on TypeError {
      // Older malformed cache entries can also have incorrect field types.
    }
  }
  upcoming.sort((a, b) => a.start.compareTo(b.start));
  return upcoming;
}

TimetableSlot? nextUpcomingClass(
  Iterable<AcademicRecord> records,
  DateTime now,
) {
  final slots = upcomingClasses(records, now);
  return slots.isEmpty ? null : slots.first;
}
