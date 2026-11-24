import 'academic_hub_models.dart';

List<TimetableSlot> upcomingClasses(
  Iterable<AcademicRecord> records,
  DateTime now, {
  Duration horizon = const Duration(days: 4),
}) {
  return currentAndUpcomingClasses(
    records,
    now,
    horizon: horizon,
  ).where((slot) => slot.start.isAfter(now)).toList();
}

List<TimetableSlot> currentAndUpcomingClasses(
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
      if (slot.end.isAfter(slot.start) &&
          slot.end.isAfter(now) &&
          slot.start.isBefore(cutoff)) {
        upcoming.add(slot);
      }
    } on FormatException {
      // Ignore malformed cache entries; the academic refresh owns repair.
    } on TypeError {
      // Older malformed cache entries can also have incorrect field types.
    }
  }
  upcoming.sort((a, b) {
    final startOrder = a.start.compareTo(b.start);
    return startOrder != 0 ? startOrder : a.externalId.compareTo(b.externalId);
  });
  return upcoming;
}

TimetableSlot? nextUpcomingClass(
  Iterable<AcademicRecord> records,
  DateTime now,
) {
  final slots = upcomingClasses(records, now);
  return slots.isEmpty ? null : slots.first;
}
