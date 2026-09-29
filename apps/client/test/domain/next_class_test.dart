import 'package:classsync/domain/academic/academic_hub_models.dart';
import 'package:classsync/domain/academic/next_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 29, 12);
  AcademicRecord record(String id, DateTime start) {
    final slot = TimetableSlot(
      externalId: id,
      subjectCode: id,
      subjectName: id,
      start: start,
      end: start.add(const Duration(minutes: 90)),
    );
    return AcademicRecord(
      key: id,
      source: AcademicSource.portal,
      kind: AcademicRecordKind.timetable,
      externalId: id,
      title: id,
      payload: slot.toJson(),
      syncedAt: now,
    );
  }

  test('selects earliest future class in four-day overview window', () {
    final records = [
      record('later', now.add(const Duration(days: 2))),
      record('past', now.subtract(const Duration(minutes: 1))),
      record('first', now.add(const Duration(hours: 2))),
      record('outside', now.add(const Duration(days: 5))),
    ];
    expect(nextUpcomingClass(records, now)?.subjectName, 'first');
    expect(
      upcomingClasses(records, now, horizon: const Duration(days: 35)),
      hasLength(3),
    );
  });

  test('skips malformed cached timetable entries', () {
    final good = record('good', now.add(const Duration(hours: 1)));
    final bad = good.copyWith(payload: {'start': 42});
    expect(nextUpcomingClass([bad, good], now)?.subjectName, 'good');
  });
}
