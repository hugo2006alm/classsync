import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';

import 'academic_models.dart';
import '../sync/sync_models.dart';

enum AcademicSource { portal, moodle, manual, fuc }

enum AcademicRecordKind {
  enrollment,
  timetable,
  evaluation,
  moodleCourse,
  announcement,
  grade,
  gradeFormula,
  reminderPreference,
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
  });

  final String externalId;
  final String code;
  final String name;
  final String academicYear;
  final String semester;
  final String? subjectId;
  final String? sourceUrl;

  Map<String, dynamic> toJson() => {
    'externalId': externalId,
    'code': code,
    'name': name,
    'academicYear': academicYear,
    'semester': semester,
    'subjectId': subjectId,
    'sourceUrl': sourceUrl,
  };

  EnrollmentSubject copyWith({String? subjectId}) => EnrollmentSubject(
    externalId: externalId,
    code: code,
    name: name,
    academicYear: academicYear,
    semester: semester,
    subjectId: subjectId ?? this.subjectId,
    sourceUrl: sourceUrl,
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
