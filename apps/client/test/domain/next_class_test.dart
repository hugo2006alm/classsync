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

  test('keeps current and overlapping classes until their exact end', () {
    final day = DateTime(2026, 9, 29);
    DateTime at(int hour, [int minute = 0]) =>
        day.add(Duration(hours: hour, minutes: minute));
    final records = [
      record('first', at(10)),
      record('overlap', at(10, 20)),
      record('second', at(11, 50)),
    ];
    List<String> visibleAt(DateTime instant) => currentAndUpcomingClasses(
      records,
      instant,
    ).map((slot) => slot.externalId).toList();

    expect(visibleAt(at(9, 55)), ['first', 'overlap', 'second']);
    expect(visibleAt(at(10, 7)), ['first', 'overlap', 'second']);
    expect(nextUpcomingClass(records, at(10, 7))?.externalId, 'overlap');
    expect(visibleAt(at(11, 30)), ['overlap', 'second']);
    expect(visibleAt(at(11, 50)), ['second']);
    expect(nextUpcomingClass(records, at(11, 50)), isNull);
    expect(visibleAt(at(13, 20)), isEmpty);
  });

  test('skips malformed cached timetable entries', () {
    final good = record('good', now.add(const Duration(hours: 1)));
    final bad = good.copyWith(payload: {'start': 42});
    expect(nextUpcomingClass([bad, good], now)?.subjectName, 'good');
  });
}
