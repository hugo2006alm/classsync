import 'dart:convert';

class AcademicSubject {
  const AcademicSubject({
    required this.notionId,
    required this.name,
    required this.year,
    required this.semester,
    required this.status,
    required this.lastSyncedAt,
    this.notionUrl,
    this.aliases = const [],
    this.professors = const [],
    this.scheduleHints = const [],
    this.summaryCount = 0,
    this.latestSummaryTitle,
  });

  final String notionId;
  final String name;
  final String year;
  final String semester;
  final String status;
  final String? notionUrl;
  final List<String> aliases;
  final List<String> professors;
  final List<String> scheduleHints;
  final DateTime lastSyncedAt;
  final int summaryCount;
  final String? latestSummaryTitle;

  bool get isActive => status.toLowerCase() == 'in progress';
  String get semesterLabel => '$year · $semester';
}

class AcademicSemester {
  const AcademicSemester({required this.year, required this.semester});

  final String year;
  final String semester;

  String get label => '$year · $semester';

  static AcademicSemester? derive(Iterable<AcademicSubject> subjects) {
    final active = subjects.where((subject) => subject.isActive).toList();
    if (active.isEmpty) return null;
    final first = active.first;
    final sameSemester = active.every(
      (subject) =>
          subject.year == first.year && subject.semester == first.semester,
    );
    return sameSemester
        ? AcademicSemester(year: first.year, semester: first.semester)
        : null;
  }
}

class TranscriptSentence {
  const TranscriptSentence({
    required this.text,
    this.speakerName,
    this.startTimeSeconds,
    this.endTimeSeconds,
  });

  final String text;
  final String? speakerName;
  final double? startTimeSeconds;
  final double? endTimeSeconds;
}

class LectureTranscript {
  const LectureTranscript({
    required this.firefliesId,
    required this.title,
    required this.date,
    required this.sentences,
    this.firefliesUrl,
    this.participants = const [],
  });

  final String firefliesId;
  final String title;
  final DateTime date;
  final String? firefliesUrl;
  final List<String> participants;
  final List<TranscriptSentence> sentences;

  String get plainText => sentences
      .map(
        (sentence) => [
          if (sentence.speakerName case final speaker?) '$speaker:',
          sentence.text,
        ].join(' '),
      )
      .join('\n');

  String toStoredJson() => jsonEncode({
    'firefliesId': firefliesId,
    'title': title,
    'date': date.toIso8601String(),
    'firefliesUrl': firefliesUrl,
    'participants': participants,
    'sentences': sentences
        .map(
          (sentence) => {
            'text': sentence.text,
            'speakerName': sentence.speakerName,
            'startTimeSeconds': sentence.startTimeSeconds,
            'endTimeSeconds': sentence.endTimeSeconds,
          },
        )
        .toList(),
  });

  factory LectureTranscript.fromStoredJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return LectureTranscript(
      firefliesId: map['firefliesId'] as String,
      title: map['title'] as String,
      date: DateTime.parse(map['date'] as String),
      firefliesUrl: map['firefliesUrl'] as String?,
      participants: (map['participants'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      sentences: (map['sentences'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (sentence) => TranscriptSentence(
              text: sentence['text'] as String? ?? '',
              speakerName: sentence['speakerName'] as String?,
              startTimeSeconds: (sentence['startTimeSeconds'] as num?)
                  ?.toDouble(),
              endTimeSeconds: (sentence['endTimeSeconds'] as num?)?.toDouble(),
            ),
          )
          .toList(),
    );
  }
}

class LectureSummarySection {
  const LectureSummarySection({
    required this.title,
    required this.content,
    this.keyPoints = const [],
    this.examples = const [],
    this.code = const [],
    this.formulas = const [],
  });

  final String title;
  final String content;
  final List<String> keyPoints;
  final List<String> examples;
  final List<String> code;
  final List<String> formulas;

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'keyPoints': keyPoints,
    'examples': examples,
    'code': code,
    'formulas': formulas,
  };

  factory LectureSummarySection.fromJson(Map<String, dynamic> json) =>
      LectureSummarySection(
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        keyPoints: _stringList(json['keyPoints']),
        examples: _stringList(json['examples']),
        code: _stringList(json['code']),
        formulas: _stringList(json['formulas']),
      );
}

class LectureSummary {
  const LectureSummary({
    required this.title,
    required this.context,
    required this.sections,
    this.objectives = const [],
    this.examHints = const [],
    this.uncertainties = const [],
    this.conclusions = const [],
    this.tags = const [],
  });

  final String title;
  final String context;
  final List<String> objectives;
  final List<LectureSummarySection> sections;
  final List<String> examHints;
  final List<String> uncertainties;
  final List<String> conclusions;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'title': title,
    'context': context,
    'objectives': objectives,
    'sections': sections.map((section) => section.toJson()).toList(),
    'examHints': examHints,
    'uncertainties': uncertainties,
    'conclusions': conclusions,
    'tags': tags,
  };

  String encode() => jsonEncode(toJson());

  factory LectureSummary.fromJson(Map<String, dynamic> json) => LectureSummary(
    title: json['title'] as String? ?? 'Resumo da aula',
    context: json['context'] as String? ?? '',
    objectives: _stringList(json['objectives']),
    sections: (json['sections'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LectureSummarySection.fromJson)
        .toList(),
    examHints: _stringList(json['examHints']),
    uncertainties: _stringList(json['uncertainties']),
    conclusions: _stringList(json['conclusions']),
    tags: _stringList(json['tags']),
  );

  factory LectureSummary.decode(String source) =>
      LectureSummary.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

List<String> _stringList(dynamic value) => (value as List<dynamic>? ?? const [])
    .map((item) => item.toString())
    .toList();
