import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/database/classsync_database.dart';
import '../../domain/academic/academic_hub_models.dart';
import '../../domain/academic/next_class.dart';

class NextClassWidget {
  static const _channel = MethodChannel('classsync/widget');

  static Future<bool> requestPin() async =>
      await _channel.invokeMethod<bool>('pin') ?? false;

  static StreamSubscription<List<AcademicRecord>> observe(
    ClassSyncDatabase database,
  ) => database
      .watchAcademicRecords(kinds: {AcademicRecordKind.timetable})
      .listen((records) {
        unawaited(_publish(records));
      });

  static Future<void> _publish(List<AcademicRecord> records) async {
    final slots =
        upcomingClasses(
              records,
              DateTime.now(),
              horizon: const Duration(days: 35),
            )
            .take(120)
            .map(
              (slot) => {
                'start': slot.start.millisecondsSinceEpoch,
                'end': slot.end.millisecondsSinceEpoch,
                'subject': slot.subjectName,
                'type': slot.lessonType ?? '',
                'class': slot.className ?? '',
                'room': slot.room ?? '',
                'teacher': slot.lecturer ?? '',
              },
            )
            .toList();
    try {
      await _channel.invokeMethod<void>('save', slots);
    } on PlatformException {
      // Widget is optional; never interrupt academic sync.
    }
  }
}
