import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';

import 'academic_models.dart';
import '../sync/sync_models.dart';

enum AcademicSource { portal, moodle, manual, fuc }

enum AcademicRecordKind {
  enrollment,
  academicHistory,
  timetable,
  evaluation,
  examRegistration,
  moodleCourse,
  announcement,
  portalNotification,
  tuitionCharge,
  fucProfile,
  lessonSummary,
  lectureTask,
  grade,
  gradeFormula,
  absence,
  schoolCalendar,
  reminderPreference,
}

enum LectureTaskStatus { pending, completed, dismissed }

class LectureTask {
  const LectureTask({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceLectureId,
    required this.sourceLectureTitle,
    required this.confidence,
    required this.supportingSegment,
    required this.status,
    this.subjectId,
    this.subjectName,
    this.dueAt,
    this.timestampSeconds,
  });

  final String id;
  final String title;
  final String description;
  final String sourceLectureId;
  final String sourceLectureTitle;
  final String? subjectId;
  final String? subjectName;
  final DateTime? dueAt;
  final LectureActionConfidence confidence;
  final String supportingSegment;
  final double? timestampSeconds;
  final LectureTaskStatus status;

  bool get needsReview =>
      confidence == LectureActionConfidence.ambiguous || dueAt == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'sourceLectureId': sourceLectureId,
    'sourceLectureTitle': sourceLectureTitle,
    'subjectId': subjectId,
    'subjectName': subjectName,
    'dueAt': dueAt?.toIso8601String(),
    'confidence': confidence.name,
    'supportingSegment': supportingSegment,
    'timestampSeconds': timestampSeconds,
    'status': status.name,
  };

  factory LectureTask.fromJson(Map<String, dynamic> json) => LectureTask(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    sourceLectureId: json['sourceLectureId'] as String? ?? '',
    sourceLectureTitle: json['sourceLectureTitle'] as String? ?? '',
    subjectId: json['subjectId'] as String?,
    subjectName: json['subjectName'] as String?,
    dueAt: DateTime.tryParse(json['dueAt'] as String? ?? ''),
    confidence: LectureActionConfidence.values.firstWhere(
      (value) => value.name == json['confidence'],
      orElse: () => LectureActionConfidence.ambiguous,
    ),
    supportingSegment: json['supportingSegment'] as String? ?? '',
    timestampSeconds: (json['timestampSeconds'] as num?)?.toDouble(),
    status: LectureTaskStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => LectureTaskStatus.pending,
    ),
  );

  LectureTask copyWith({
    String? title,
    String? description,
    DateTime? dueAt,
    bool clearDueAt = false,
    LectureTaskStatus? status,
  }) => LectureTask(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    sourceLectureId: sourceLectureId,
    sourceLectureTitle: sourceLectureTitle,
    subjectId: subjectId,
    subjectName: subjectName,
    dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
    confidence: confidence,
    supportingSegment: supportingSegment,
    timestampSeconds: timestampSeconds,
    status: status ?? this.status,
  );
}

class PortalNotification {
  const PortalNotification({
    required this.id,
    required this.title,
    required this.sender,
    required this.createdAt,
    required this.message,
    required this.sourceUrl,
    this.attachments = const [],
  });

  final String id;
  final String title;
  final String sender;
  final DateTime createdAt;
  final String message;
  final List<String> attachments;
  final String sourceUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sender': sender,
    'createdAt': createdAt.toIso8601String(),
    'message': message,
    'attachments': attachments,
    'sourceUrl': sourceUrl,
    'read': false,
  };
}

class AbsenceSummary {
  const AbsenceSummary({
    required this.id,
    required this.subjectName,
    required this.absences,
    required this.sourceUrl,
    this.subjectCode,
    this.subjectId,
    this.totalPlannedClasses,
    this.excusedAbsences,
    this.academicYear,
    this.measuredInHours = false,
  });

  final String id;
  final String subjectName;
  final String? subjectCode;
  final String? subjectId;
  final double absences;
  final double? totalPlannedClasses;
  final double? excusedAbsences;
  final String? academicYear;
  final bool measuredInHours;
  final String sourceUrl;

  double? get percentage =>
      totalPlannedClasses == null || totalPlannedClasses! <= 0
      ? null
      : absences / totalPlannedClasses! * 100;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectName': subjectName,
    'subjectCode': subjectCode,
    'subjectId': subjectId,
    'absences': absences,
    'totalPlannedClasses': totalPlannedClasses,
    'excusedAbsences': excusedAbsences,
    'academicYear': academicYear,
    'measuredInHours': measuredInHours,
    'sourceUrl': sourceUrl,
  };

  factory AbsenceSummary.fromJson(Map<String, dynamic> json) => AbsenceSummary(
    id: json['id'] as String? ?? '',
    subjectName: json['subjectName'] as String? ?? '',
    subjectCode: json['subjectCode'] as String?,
    subjectId: json['subjectId'] as String?,
    absences: (json['absences'] as num?)?.toDouble() ?? 0,
    totalPlannedClasses: (json['totalPlannedClasses'] as num?)?.toDouble(),
    excusedAbsences: (json['excusedAbsences'] as num?)?.toDouble(),
    academicYear: json['academicYear'] as String?,
    measuredInHours: json['measuredInHours'] as bool? ?? false,
    sourceUrl: json['sourceUrl'] as String? ?? '',
  );

  AbsenceSummary copyWith({String? subjectId, double? totalPlannedClasses}) =>
      AbsenceSummary(
        id: id,
        subjectName: subjectName,
        subjectCode: subjectCode,
        subjectId: subjectId ?? this.subjectId,
        absences: absences,
        totalPlannedClasses: totalPlannedClasses ?? this.totalPlannedClasses,
        excusedAbsences: excusedAbsences,
        academicYear: academicYear,
        measuredInHours: measuredInHours,
        sourceUrl: sourceUrl,
      );
}

class SchoolCalendarEntry {
  const SchoolCalendarEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.sourceUrl,
    this.category,
    this.academicYear,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String sourceUrl;
  final String? category;
  final String? academicYear;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'sourceUrl': sourceUrl,
    'category': category,
    'academicYear': academicYear,
  };

  factory SchoolCalendarEntry.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['start'] as String? ?? '');
    return SchoolCalendarEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      start: start ?? DateTime.fromMillisecondsSinceEpoch(0),
      end:
          DateTime.tryParse(json['end'] as String? ?? '') ??
          start ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sourceUrl: json['sourceUrl'] as String? ?? '',
      category: json['category'] as String?,
      academicYear: json['academicYear'] as String?,
    );
  }
}

enum TuitionPaymentState { pending, partial, paid, overdue, cancelled, unknown }

/// A read-only, locally cached Portal charge. Payment references are deliberately
/// reduced to an availability flag and masked hint before this model is created.
class TuitionCharge {
  const TuitionCharge({
    required this.id,
    required this.title,
    required this.state,
    required this.sourceUrl,
    this.academicYear,
    this.installment,
    this.amount,
    this.outstandingAmount,
    this.dueAt,
    this.paidAt,
    this.hasLateInterest = false,
    this.paymentReferenceAvailable = false,
    this.paymentReferenceHint,
    this.reminderMinutes,
    this.overdueReminder = false,
  });

  final String id;
  final String title;
  final TuitionPaymentState state;
  final String sourceUrl;
  final String? academicYear;
  final String? installment;
  final double? amount;
  final double? outstandingAmount;
  final DateTime? dueAt;
  final DateTime? paidAt;
  final bool hasLateInterest;
  final bool paymentReferenceAvailable;
  final String? paymentReferenceHint;
  final int? reminderMinutes;
  final bool overdueReminder;

  bool isOpenAt(DateTime instant) =>
      state != TuitionPaymentState.paid &&
      state != TuitionPaymentState.cancelled;

  bool isOverdueAt(DateTime instant) =>
      state == TuitionPaymentState.overdue ||
      (isOpenAt(instant) && dueAt != null && dueAt!.isBefore(instant));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'state': state.name,
    'sourceUrl': sourceUrl,
    'academicYear': academicYear,
    'installment': installment,
    'amount': amount,
    'outstandingAmount': outstandingAmount,
    'dueAt': dueAt?.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'hasLateInterest': hasLateInterest,
    // Never persist the full Portal payment reference.
    'paymentReferenceAvailable': paymentReferenceAvailable,
    'paymentReferenceHint': paymentReferenceHint,
    'reminderMinutes': reminderMinutes,
    'overdueReminder': overdueReminder,
  };

  factory TuitionCharge.fromJson(Map<String, dynamic> json) => TuitionCharge(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Portal charge',
    state: TuitionPaymentState.values.firstWhere(
      (item) => item.name == json['state'],
      orElse: () => TuitionPaymentState.unknown,
    ),
    sourceUrl: json['sourceUrl'] as String? ?? '',
    academicYear: json['academicYear'] as String?,
    installment: json['installment'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    outstandingAmount: (json['outstandingAmount'] as num?)?.toDouble(),
    dueAt: DateTime.tryParse(json['dueAt'] as String? ?? ''),
    paidAt: DateTime.tryParse(json['paidAt'] as String? ?? ''),
    hasLateInterest: json['hasLateInterest'] as bool? ?? false,
    paymentReferenceAvailable:
        json['paymentReferenceAvailable'] as bool? ?? false,
    paymentReferenceHint: json['paymentReferenceHint'] as String?,
    reminderMinutes: (json['reminderMinutes'] as num?)?.toInt(),
    overdueReminder: json['overdueReminder'] as bool? ?? false,
  );

  TuitionCharge copyWith({
    int? reminderMinutes,
    bool clearReminder = false,
    bool? overdueReminder,
  }) => TuitionCharge(
    id: id,
    title: title,
    state: state,
    sourceUrl: sourceUrl,
    academicYear: academicYear,
    installment: installment,
    amount: amount,
    outstandingAmount: outstandingAmount,
    dueAt: dueAt,
    paidAt: paidAt,
    hasLateInterest: hasLateInterest,
    paymentReferenceAvailable: paymentReferenceAvailable,
    paymentReferenceHint: paymentReferenceHint,
    reminderMinutes: clearReminder
        ? null
        : reminderMinutes ?? this.reminderMinutes,
    overdueReminder: overdueReminder ?? this.overdueReminder,
  );
}

class FucProfile {
  const FucProfile({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.academicYear,
    required this.sourceUrl,
    this.responsibleLecturer,
    this.lecturers = const [],
    this.workload,
    this.objectives = const [],
    this.syllabus = const [],
    this.bibliography = const [],
    this.methodologies = const [],
    this.evaluationRules = const [],
  });

  final String id;
  final String subjectCode;
  final String subjectName;
  final String academicYear;
  final String? responsibleLecturer;
  final List<String> lecturers;
  final String? workload;
  final List<String> objectives;
  final List<String> syllabus;
  final List<String> bibliography;
  final List<String> methodologies;
  final List<String> evaluationRules;
  final String sourceUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'academicYear': academicYear,
    'responsibleLecturer': responsibleLecturer,
    'lecturers': lecturers,
    'workload': workload,
    'objectives': objectives,
    'syllabus': syllabus,
    'bibliography': bibliography,
    'methodologies': methodologies,
    'evaluationRules': evaluationRules,
    'sourceUrl': sourceUrl,
  };
}

class OfficialLessonSummary {
  const OfficialLessonSummary({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.date,
    required this.text,
    required this.sourceUrl,
    this.className,
    this.lessonType,
    this.lecturer,
  });

  final String id;
  final String subjectCode;
  final String subjectName;
  final DateTime date;
  final String text;
  final String? className;
  final String? lessonType;
  final String? lecturer;
  final String sourceUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'date': date.toIso8601String(),
    'text': text,
    'className': className,
    'lessonType': lessonType,
    'lecturer': lecturer,
    'sourceUrl': sourceUrl,
  };
}

class AcademicSearchHit {
  const AcademicSearchHit({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.kind,
    required this.source,
    required this.score,
    this.subjectId,
    this.date,
    this.url,
  });

  final String id;
  final String title;
  final String excerpt;
  final AcademicRecordKind kind;
  final AcademicSource source;
  final int score;
  final String? subjectId;
  final DateTime? date;
  final String? url;
}

class AcademicGroundedAnswer {
  const AcademicGroundedAnswer({
    required this.answer,
    required this.citationIds,
    required this.insufficientEvidence,
  });

  final String answer;
  final List<String> citationIds;
  final bool insufficientEvidence;

  factory AcademicGroundedAnswer.fromJson(Map<String, dynamic> json) =>
      AcademicGroundedAnswer(
        answer: json['answer'] as String? ?? '',
        citationIds: (json['citationIds'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        insufficientEvidence: json['insufficientEvidence'] as bool? ?? false,
      );
}

class AcademicRecord {
  const AcademicRecord({
    required this.key,
    required this.source,
    required this.kind,
    required this.externalId,
    required this.title,
    required this.payload,
    required this.syncedAt,
    this.subjectId,
    this.startsAt,
    this.endsAt,
    this.changedFields = const [],
    this.lastChangedAt,
  });

  final String key;
  final AcademicSource source;
  final AcademicRecordKind kind;
  final String externalId;
  final String title;
  final String? subjectId;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final Map<String, dynamic> payload;
  final DateTime syncedAt;
  final List<String> changedFields;
  final DateTime? lastChangedAt;

  String get fingerprint => jsonEncode(_canonicalize(payload));

  AcademicRecord copyWith({
    String? subjectId,
    Map<String, dynamic>? payload,
    List<String>? changedFields,
    DateTime? lastChangedAt,
  }) => AcademicRecord(
    key: key,
    source: source,
    kind: kind,
    externalId: externalId,
    title: title,
    subjectId: subjectId ?? this.subjectId,
    startsAt: startsAt,
    endsAt: endsAt,
    payload: payload ?? this.payload,
    syncedAt: syncedAt,
    changedFields: changedFields ?? this.changedFields,
    lastChangedAt: lastChangedAt ?? this.lastChangedAt,
  );

  static String keyFor(
    AcademicSource source,
    AcademicRecordKind kind,
    String externalId,
  ) => '${source.name}:${kind.name}:$externalId';
}

dynamic _canonicalize(dynamic value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList();
  return value;
}

class EnrollmentSubject {
  const EnrollmentSubject({
    required this.externalId,
    required this.code,
    required this.name,
    required this.academicYear,
    required this.semester,
    this.subjectId,
    this.sourceUrl,
    this.status = 'current',
    this.ects,
    this.courseContext,
  });

  final String externalId;
  final String code;
  final String name;
  final String academicYear;
  final String semester;
  final String? subjectId;
  final String? sourceUrl;
  final String status;
  final double? ects;
  final String? courseContext;

  Map<String, dynamic> toJson() => {
    'externalId': externalId,
    'code': code,
    'name': name,
    'academicYear': academicYear,
    'semester': semester,
    'subjectId': subjectId,
    'sourceUrl': sourceUrl,
    'status': status,
    'ects': ects,
    'courseContext': courseContext,
  };

  EnrollmentSubject copyWith({String? subjectId}) => EnrollmentSubject(
    externalId: externalId,
    code: code,
    name: name,
    academicYear: academicYear,
    semester: semester,
    subjectId: subjectId ?? this.subjectId,
    sourceUrl: sourceUrl,
    status: status,
    ects: ects,
    courseContext: courseContext,
  );
}

class TimetableSlot {
  const TimetableSlot({
    required this.externalId,
    required this.subjectCode,
    required this.subjectName,
    required this.start,
    required this.end,
    this.subjectId,
    this.portalSubjectId,
    this.className,
    this.lessonType,
    this.room,
    this.lecturer,
    this.sourceUrl,
    this.exceptional = false,
  });

  final String externalId;
  final String subjectCode;
  final String subjectName;
  final String? subjectId;
  final String? portalSubjectId;
  final DateTime start;
  final DateTime end;
  final String? className;
  final String? lessonType;
  final String? room;
  final String? lecturer;
  final String? sourceUrl;
  final bool exceptional;

  Map<String, dynamic> toJson() => {
    'externalId': externalId,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'subjectId': subjectId,
    'portalSubjectId': portalSubjectId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'className': className,
    'lessonType': lessonType,
    'room': room,
    'lecturer': lecturer,
    'sourceUrl': sourceUrl,
    'exceptional': exceptional,
  };

  factory TimetableSlot.fromJson(Map<String, dynamic> json) => TimetableSlot(
    externalId: json['externalId'] as String? ?? '',
    subjectCode: json['subjectCode'] as String? ?? '',
    subjectName: json['subjectName'] as String? ?? '',
    subjectId: json['subjectId'] as String?,
    portalSubjectId: json['portalSubjectId'] as String?,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    className: json['className'] as String?,
    lessonType: json['lessonType'] as String?,
    room: json['room'] as String?,
    lecturer: json['lecturer'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    exceptional: json['exceptional'] as bool? ?? false,
  );

  TimetableSlot copyWith({String? subjectId}) => TimetableSlot(
    externalId: externalId,
    subjectCode: subjectCode,
    subjectName: subjectName,
    subjectId: subjectId ?? this.subjectId,
    portalSubjectId: portalSubjectId,
    start: start,
    end: end,
    className: className,
    lessonType: lessonType,
    room: room,
    lecturer: lecturer,
    sourceUrl: sourceUrl,
    exceptional: exceptional,
  );
}

enum ExamRegistrationState {
  unknown,
  scheduled,
  registrationAvailable,
  registered,
  notRegistered,
  registrationClosed,
}

class AcademicProvenance {
  const AcademicProvenance({
    required this.source,
    required this.externalId,
    this.url,
  });

  final AcademicSource source;
  final String externalId;
  final String? url;

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'externalId': externalId,
    'url': url,
  };

  factory AcademicProvenance.fromJson(Map<String, dynamic> json) =>
      AcademicProvenance(
        source: AcademicSource.values.byName(json['source'] as String),
        externalId: json['externalId'] as String? ?? '',
        url: json['url'] as String?,
      );
}

class EvaluationEvent {
  const EvaluationEvent({
    required this.externalId,
    required this.title,
    required this.type,
    required this.start,
    required this.provenance,
    this.subjectCode,
    this.subjectName,
    this.subjectId,
    this.end,
    this.location,
    this.registrationState = ExamRegistrationState.unknown,
    this.reminderMinutes,
    this.changedFields = const [],
  });

  final String externalId;
  final String title;
  final String type;
  final String? subjectCode;
  final String? subjectName;
  final String? subjectId;
  final DateTime start;
  final DateTime? end;
  final String? location;
  final ExamRegistrationState registrationState;
  final List<AcademicProvenance> provenance;
  final int? reminderMinutes;
  final List<String> changedFields;

  Map<String, dynamic> toJson() => {
    'externalId': externalId,
    'title': title,
    'type': type,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'subjectId': subjectId,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
    'location': location,
    'registrationState': registrationState.name,
    'provenance': provenance.map((item) => item.toJson()).toList(),
    'reminderMinutes': reminderMinutes,
  };

  factory EvaluationEvent.fromJson(
    Map<String, dynamic> json, {
    List<String> changedFields = const [],
  }) => EvaluationEvent(
    externalId: json['externalId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    type: json['type'] as String? ?? 'Evaluation',
    subjectCode: json['subjectCode'] as String?,
    subjectName: json['subjectName'] as String?,
    subjectId: json['subjectId'] as String?,
    start: DateTime.parse(json['start'] as String),
    end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
    location: json['location'] as String?,
    registrationState: ExamRegistrationState.values.firstWhere(
      (item) => item.name == json['registrationState'],
      orElse: () => ExamRegistrationState.unknown,
    ),
    provenance: (json['provenance'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AcademicProvenance.fromJson)
        .toList(),
    reminderMinutes: json['reminderMinutes'] as int?,
    changedFields: changedFields,
  );

  EvaluationEvent copyWith({
    String? subjectId,
    ExamRegistrationState? registrationState,
    int? reminderMinutes,
    bool clearReminder = false,
    List<AcademicProvenance>? provenance,
  }) => EvaluationEvent(
    externalId: externalId,
    title: title,
    type: type,
    subjectCode: subjectCode,
    subjectName: subjectName,
    subjectId: subjectId ?? this.subjectId,
    start: start,
    end: end,
    location: location,
    registrationState: registrationState ?? this.registrationState,
    provenance: provenance ?? this.provenance,
    reminderMinutes: clearReminder
        ? null
        : reminderMinutes ?? this.reminderMinutes,
    changedFields: changedFields,
  );
}

class MoodleCourse {
  const MoodleCourse({
    required this.externalId,
    required this.name,
    required this.shortName,
    required this.url,
    this.subjectId,
  });

  final String externalId;
  final String name;
  final String shortName;
  final String url;
  final String? subjectId;

  Map<String, dynamic> toJson() => {
    'externalId': externalId,
    'name': name,
    'shortName': shortName,
    'url': url,
    'subjectId': subjectId,
  };
}

class MoodleAnnouncement {
  const MoodleAnnouncement({
    required this.externalId,
    required this.courseId,
    required this.title,
    required this.createdAt,
    required this.url,
    this.preview,
    this.subjectId,
  });

  final String externalId;
  final String courseId;
  final String title;
  final String? preview;
  final DateTime createdAt;
  final String url;
  final String? subjectId;

  Map<String, dynamic> toJson() => {
    'externalId': externalId,
    'courseId': courseId,
    'title': title,
    'preview': preview,
    'createdAt': createdAt.toIso8601String(),
    'url': url,
    'subjectId': subjectId,
  };
}

enum GradeValueSource { officialPortal, fuc, manual, inferred }

class GradeComponent {
  const GradeComponent({
    required this.externalId,
    required this.subjectName,
    required this.name,
    required this.source,
    this.subjectCode,
    this.subjectId,
    this.value,
    this.weight,
    this.minimum,
    this.academicYear,
    this.isFinal = false,
    this.isHistorical = false,
    this.ects,
    this.academicStatus,
    this.courseContext,
    this.confirmed = true,
    this.sourceUrl,
  });

  final String externalId;
  final String? subjectCode;
  final String subjectName;
  final String? subjectId;
  final String name;
  final double? value;
  final double? weight;
  final double? minimum;
  final String? academicYear;
  final bool isFinal;
  final bool isHistorical;
  final double? ects;
  final String? academicStatus;
  final String? courseContext;
  final GradeValueSource source;
  final bool confirmed;
  final String? sourceUrl;

  Map<String, dynamic> toJson() => {
    'externalId': externalId,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'subjectId': subjectId,
    'name': name,
    'value': value,
    'weight': weight,
    'minimum': minimum,
    'academicYear': academicYear,
    'isFinal': isFinal,
    'isHistorical': isHistorical,
    'ects': ects,
    'academicStatus': academicStatus,
    'courseContext': courseContext,
    'source': source.name,
    'confirmed': confirmed,
    'sourceUrl': sourceUrl,
  };

  factory GradeComponent.fromJson(Map<String, dynamic> json) => GradeComponent(
    externalId: json['externalId'] as String? ?? '',
    subjectCode: json['subjectCode'] as String?,
    subjectName: json['subjectName'] as String? ?? '',
    subjectId: json['subjectId'] as String?,
    name: json['name'] as String? ?? '',
    value: (json['value'] as num?)?.toDouble(),
    weight: (json['weight'] as num?)?.toDouble(),
    minimum: (json['minimum'] as num?)?.toDouble(),
    academicYear: json['academicYear'] as String?,
    isFinal: json['isFinal'] as bool? ?? false,
    isHistorical: json['isHistorical'] as bool? ?? false,
    ects: (json['ects'] as num?)?.toDouble(),
    academicStatus: json['academicStatus'] as String?,
    courseContext: json['courseContext'] as String?,
    source: GradeValueSource.values.firstWhere(
      (item) => item.name == json['source'],
      orElse: () => GradeValueSource.manual,
    ),
    confirmed: json['confirmed'] as bool? ?? true,
    sourceUrl: json['sourceUrl'] as String?,
  );

  GradeComponent copyWith({
    String? subjectId,
    double? value,
    bool keepValue = true,
    bool? confirmed,
  }) => GradeComponent(
    externalId: externalId,
    subjectCode: subjectCode,
    subjectName: subjectName,
    subjectId: subjectId ?? this.subjectId,
    name: name,
    value: keepValue ? value ?? this.value : value,
    weight: weight,
    minimum: minimum,
    academicYear: academicYear,
    isFinal: isFinal,
    isHistorical: isHistorical,
    ects: ects,
    academicStatus: academicStatus,
    courseContext: courseContext,
    source: source,
    confirmed: confirmed ?? this.confirmed,
    sourceUrl: sourceUrl,
  );
}

class AssessmentFormula {
  const AssessmentFormula({
    required this.id,
    required this.label,
    required this.components,
    this.subjectCode,
    this.subjectName,
    this.subjectId,
    this.minimumFinalGrade = 9.5,
    this.confirmed = true,
    this.source = GradeValueSource.manual,
  });

  final String id;
  final String label;
  final List<GradeComponent> components;
  final String? subjectCode;
  final String? subjectName;
  final String? subjectId;
  final double minimumFinalGrade;
  final bool confirmed;
  final GradeValueSource source;

  String get structureFingerprint => jsonEncode(
    _canonicalize({
      'label': label,
      'components': components.map((item) => item.toJson()).toList(),
      'minimumFinalGrade': minimumFinalGrade,
      'source': source.name,
    }),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'components': components.map((item) => item.toJson()).toList(),
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'subjectId': subjectId,
    'minimumFinalGrade': minimumFinalGrade,
    'confirmed': confirmed,
    'source': source.name,
  };

  factory AssessmentFormula.fromJson(Map<String, dynamic> json) =>
      AssessmentFormula(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? 'Evaluation formula',
        components: (json['components'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GradeComponent.fromJson)
            .toList(),
        subjectCode: json['subjectCode'] as String?,
        subjectName: json['subjectName'] as String?,
        subjectId: json['subjectId'] as String?,
        minimumFinalGrade:
            (json['minimumFinalGrade'] as num?)?.toDouble() ?? 9.5,
        confirmed: json['confirmed'] as bool? ?? false,
        source: GradeValueSource.values.firstWhere(
          (item) => item.name == json['source'],
          orElse: () => GradeValueSource.inferred,
        ),
      );

  AssessmentFormula copyWith({
    String? subjectId,
    bool? confirmed,
    List<GradeComponent>? components,
  }) => AssessmentFormula(
    id: id,
    label: label,
    components: components ?? this.components,
    subjectCode: subjectCode,
    subjectName: subjectName,
    subjectId: subjectId ?? this.subjectId,
    minimumFinalGrade: minimumFinalGrade,
    confirmed: confirmed ?? this.confirmed,
    source: source,
  );
}

class GradeCalculation {
  const GradeCalculation({
    required this.currentAverage,
    required this.completedWeight,
    required this.remainingWeight,
    required this.requiredAverage,
    required this.possible,
    required this.blockers,
  });

  final double? currentAverage;
  final double completedWeight;
  final double remainingWeight;
  final double? requiredAverage;
  final bool possible;
  final List<String> blockers;
}

class GradeCalculator {
  const GradeCalculator._();

  static GradeCalculation calculate(
    AssessmentFormula formula, {
    required double target,
  }) {
    final weighted = formula.components.where((item) => item.weight != null);
    final completed = weighted.where((item) => item.value != null).toList();
    final remaining = weighted.where((item) => item.value == null).toList();
    final completedWeight = completed.fold<double>(
      0,
      (sum, item) => sum + item.weight!,
    );
    final remainingWeight = remaining.fold<double>(
      0,
      (sum, item) => sum + item.weight!,
    );
    final points = completed.fold<double>(
      0,
      (sum, item) => sum + item.value! * item.weight!,
    );
    final blockers = <String>[
      for (final item in completed)
        if (item.minimum != null && item.value! < item.minimum!)
          '${item.name} is below its ${item.minimum} minimum',
    ];
    final currentAverage = completedWeight == 0
        ? null
        : points / completedWeight;
    double? required;
    var possible = blockers.isEmpty;
    if (remainingWeight == 0) {
      possible = possible && points >= max(target, formula.minimumFinalGrade);
    } else {
      required =
          (max(target, formula.minimumFinalGrade) - points) / remainingWeight;
      final remainingMinimum = remaining
          .map((item) => item.minimum ?? 0)
          .fold<double>(0, max);
      required = max(required, remainingMinimum);
      possible = possible && required <= 20;
      if (required < 0) required = 0;
    }
    return GradeCalculation(
      currentAverage: currentAverage,
      completedWeight: completedWeight,
      remainingWeight: remainingWeight,
      requiredAverage: required,
      possible: possible,
      blockers: blockers,
    );
  }

  static MapEntry<AssessmentFormula, GradeCalculation>? bestAlternative(
    Iterable<AssessmentFormula> formulas, {
    required double target,
  }) {
    final results =
        formulas
            .where((formula) => formula.confirmed)
            .map(
              (formula) =>
                  MapEntry(formula, calculate(formula, target: target)),
            )
            .where((entry) => entry.value.possible)
            .toList()
          ..sort(
            (a, b) => (a.value.requiredAverage ?? 0).compareTo(
              b.value.requiredAverage ?? 0,
            ),
          );
    return results.isEmpty ? null : results.first;
  }
}

class SubjectMatch {
  const SubjectMatch({required this.candidates});
  final List<AcademicSubject> candidates;
  bool get isExact => candidates.length == 1;
  bool get isAmbiguous => candidates.length > 1;
  AcademicSubject? get subject => isExact ? candidates.single : null;
}

class SubjectMapper {
  const SubjectMapper._();

  static SubjectMatch match(
    String code,
    String name,
    Iterable<AcademicSubject> subjects,
  ) {
    final needles = {normalize(code), normalize(name)}..remove('');
    final matches = subjects.where((subject) {
      final values = {
        normalize(subject.name),
        ...subject.aliases.map(normalize),
      };
      return values.any(needles.contains);
    }).toList();
    return SubjectMatch(candidates: matches);
  }

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâã]'), 'a')
      .replaceAll(RegExp(r'[éê]'), 'e')
      .replaceAll(RegExp(r'[í]'), 'i')
      .replaceAll(RegExp(r'[óôõ]'), 'o')
      .replaceAll(RegExp(r'[ú]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

class TimetableContext {
  const TimetableContext({
    required this.slots,
    required this.subjectIds,
    required this.explanation,
  });

  final List<TimetableSlot> slots;
  final Set<String> subjectIds;
  final String explanation;
  bool get isUnique => subjectIds.length == 1;
  bool get isAmbiguous => subjectIds.length > 1;
  String? get subjectId => isUnique ? subjectIds.single : null;
}

class TimetableMatcher {
  const TimetableMatcher._();

  static TimetableContext match({
    required DateTime meetingStart,
    required DateTime meetingEnd,
    required Iterable<TimetableSlot> slots,
  }) {
    final overlaps = slots
        .where(
          (slot) =>
              slot.start.isBefore(meetingEnd) && slot.end.isAfter(meetingStart),
        )
        .toList();
    final ids = overlaps
        .map((slot) => slot.subjectId)
        .whereType<String>()
        .toSet();
    return TimetableContext(
      slots: overlaps,
      subjectIds: ids,
      explanation: overlaps.isEmpty
          ? 'Timetable: no overlapping slot'
          : ids.length == 1
          ? 'Timetable: unique overlap with ${overlaps.first.subjectName}'
          : 'Timetable: conflicting overlaps (${overlaps.map((item) => item.subjectName).join(', ')})',
    );
  }

  static ClassificationResult combine(
    ClassificationResult semantic,
    TimetableContext context,
    Iterable<AcademicSubject> subjects,
  ) {
    if (context.slots.isEmpty || context.subjectIds.isEmpty) {
      return _withReason(semantic, context.explanation);
    }
    if (context.isAmbiguous) {
      return ClassificationResult(
        decision: ClassificationDecision.uncertain,
        subjectId: semantic.subjectId,
        subjectName: semantic.subjectName,
        confidence: min(semantic.confidence, 0.84),
        candidates: semantic.candidates,
        reasoningSummary: [...semantic.reasoningSummary, context.explanation],
        suggestedLectureTitle: semantic.suggestedLectureTitle,
      );
    }
    if (semantic.decision == ClassificationDecision.notALecture) {
      return _withReason(
        semantic,
        '${context.explanation}; semantic evidence says not a lecture',
      );
    }
    final timetableId = context.subjectId!;
    final timetableSubject = subjects
        .where((item) => item.notionId == timetableId)
        .firstOrNull;
    if (semantic.subjectId == timetableId) {
      return ClassificationResult(
        decision: ClassificationDecision.match,
        subjectId: semantic.subjectId,
        subjectName: semantic.subjectName ?? timetableSubject?.name,
        confidence: min(1, semantic.confidence * 0.75 + 0.25),
        candidates: semantic.candidates,
        reasoningSummary: [
          ...semantic.reasoningSummary,
          '${context.explanation}; corroborates semantic match',
        ],
        suggestedLectureTitle: semantic.suggestedLectureTitle,
      );
    }
    if (semantic.subjectId == null) {
      return ClassificationResult(
        decision: ClassificationDecision.uncertain,
        subjectId: timetableId,
        subjectName: timetableSubject?.name,
        confidence: max(semantic.confidence, 0.65),
        candidates: semantic.candidates,
        reasoningSummary: [
          ...semantic.reasoningSummary,
          '${context.explanation}; timetable-only suggestion requires review',
        ],
        suggestedLectureTitle: semantic.suggestedLectureTitle,
      );
    }
    return ClassificationResult(
      decision: ClassificationDecision.uncertain,
      subjectId: semantic.subjectId,
      subjectName: semantic.subjectName,
      confidence: min(semantic.confidence, 0.84),
      candidates: semantic.candidates,
      reasoningSummary: [
        ...semantic.reasoningSummary,
        '${context.explanation}; conflicts with semantic subject ${semantic.subjectName ?? semantic.subjectId}',
      ],
      suggestedLectureTitle: semantic.suggestedLectureTitle,
    );
  }

  static ClassificationResult _withReason(
    ClassificationResult value,
    String reason,
  ) => ClassificationResult(
    decision: value.decision,
    subjectId: value.subjectId,
    subjectName: value.subjectName,
    confidence: value.confidence,
    candidates: value.candidates,
    reasoningSummary: [...value.reasoningSummary, reason],
    suggestedLectureTitle: value.suggestedLectureTitle,
  );
}

class EvaluationMerger {
  const EvaluationMerger._();

  static List<EvaluationEvent> merge(Iterable<EvaluationEvent> events) {
    final result = <EvaluationEvent>[];
    for (final event in events) {
      final index = result.indexWhere((other) => _sameEvent(other, event));
      if (index < 0) {
        result.add(event);
        continue;
      }
      final current = result[index];
      final provenance = <AcademicProvenance>[
        ...current.provenance,
        for (final item in event.provenance)
          if (!current.provenance.any(
            (old) =>
                old.source == item.source && old.externalId == item.externalId,
          ))
            item,
      ];
      final preferred =
          event.provenance.any((item) => item.source == AcademicSource.portal)
          ? event
          : current;
      result[index] = preferred.copyWith(provenance: provenance);
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  static bool _sameEvent(EvaluationEvent a, EvaluationEvent b) {
    final sameSubject = a.subjectId != null && b.subjectId != null
        ? a.subjectId == b.subjectId
        : SubjectMapper.normalize(a.subjectCode ?? a.subjectName ?? '') ==
              SubjectMapper.normalize(b.subjectCode ?? b.subjectName ?? '');
    return sameSubject &&
        SubjectMapper.normalize(a.type) == SubjectMapper.normalize(b.type) &&
        a.start.difference(b.start).abs() <= const Duration(minutes: 15);
  }
}
