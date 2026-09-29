// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classsync_database.dart';

// ignore_for_file: type=lint
class $CachedSubjectsTable extends CachedSubjects
    with TableInfo<$CachedSubjectsTable, CachedSubjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _notionIdMeta = const VerificationMeta(
    'notionId',
  );
  @override
  late final GeneratedColumn<String> notionId = GeneratedColumn<String>(
    'notion_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semesterMeta = const VerificationMeta(
    'semester',
  );
  @override
  late final GeneratedColumn<String> semester = GeneratedColumn<String>(
    'semester',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notionUrlMeta = const VerificationMeta(
    'notionUrl',
  );
  @override
  late final GeneratedColumn<String> notionUrl = GeneratedColumn<String>(
    'notion_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aliasesJsonMeta = const VerificationMeta(
    'aliasesJson',
  );
  @override
  late final GeneratedColumn<String> aliasesJson = GeneratedColumn<String>(
    'aliases_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _professorsJsonMeta = const VerificationMeta(
    'professorsJson',
  );
  @override
  late final GeneratedColumn<String> professorsJson = GeneratedColumn<String>(
    'professors_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _scheduleHintsJsonMeta = const VerificationMeta(
    'scheduleHintsJson',
  );
  @override
  late final GeneratedColumn<String> scheduleHintsJson =
      GeneratedColumn<String>(
        'schedule_hints_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    notionId,
    name,
    year,
    semester,
    status,
    notionUrl,
    aliasesJson,
    professorsJson,
    scheduleHintsJson,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSubjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('notion_id')) {
      context.handle(
        _notionIdMeta,
        notionId.isAcceptableOrUnknown(data['notion_id']!, _notionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_notionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('semester')) {
      context.handle(
        _semesterMeta,
        semester.isAcceptableOrUnknown(data['semester']!, _semesterMeta),
      );
    } else if (isInserting) {
      context.missing(_semesterMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notion_url')) {
      context.handle(
        _notionUrlMeta,
        notionUrl.isAcceptableOrUnknown(data['notion_url']!, _notionUrlMeta),
      );
    }
    if (data.containsKey('aliases_json')) {
      context.handle(
        _aliasesJsonMeta,
        aliasesJson.isAcceptableOrUnknown(
          data['aliases_json']!,
          _aliasesJsonMeta,
        ),
      );
    }
    if (data.containsKey('professors_json')) {
      context.handle(
        _professorsJsonMeta,
        professorsJson.isAcceptableOrUnknown(
          data['professors_json']!,
          _professorsJsonMeta,
        ),
      );
    }
    if (data.containsKey('schedule_hints_json')) {
      context.handle(
        _scheduleHintsJsonMeta,
        scheduleHintsJson.isAcceptableOrUnknown(
          data['schedule_hints_json']!,
          _scheduleHintsJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {notionId};
  @override
  CachedSubjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSubjectRow(
      notionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notion_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}year'],
      )!,
      semester: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semester'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notionUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notion_url'],
      ),
      aliasesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases_json'],
      )!,
      professorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}professors_json'],
      )!,
      scheduleHintsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_hints_json'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedSubjectsTable createAlias(String alias) {
    return $CachedSubjectsTable(attachedDatabase, alias);
  }
}

class CachedSubjectRow extends DataClass
    implements Insertable<CachedSubjectRow> {
  final String notionId;
  final String name;
  final String year;
  final String semester;
  final String status;
  final String? notionUrl;
  final String aliasesJson;
  final String professorsJson;
  final String scheduleHintsJson;
  final DateTime lastSyncedAt;
  const CachedSubjectRow({
    required this.notionId,
    required this.name,
    required this.year,
    required this.semester,
    required this.status,
    this.notionUrl,
    required this.aliasesJson,
    required this.professorsJson,
    required this.scheduleHintsJson,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['notion_id'] = Variable<String>(notionId);
    map['name'] = Variable<String>(name);
    map['year'] = Variable<String>(year);
    map['semester'] = Variable<String>(semester);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notionUrl != null) {
      map['notion_url'] = Variable<String>(notionUrl);
    }
    map['aliases_json'] = Variable<String>(aliasesJson);
    map['professors_json'] = Variable<String>(professorsJson);
    map['schedule_hints_json'] = Variable<String>(scheduleHintsJson);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedSubjectsCompanion toCompanion(bool nullToAbsent) {
    return CachedSubjectsCompanion(
      notionId: Value(notionId),
      name: Value(name),
      year: Value(year),
      semester: Value(semester),
      status: Value(status),
      notionUrl: notionUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(notionUrl),
      aliasesJson: Value(aliasesJson),
      professorsJson: Value(professorsJson),
      scheduleHintsJson: Value(scheduleHintsJson),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory CachedSubjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSubjectRow(
      notionId: serializer.fromJson<String>(json['notionId']),
      name: serializer.fromJson<String>(json['name']),
      year: serializer.fromJson<String>(json['year']),
      semester: serializer.fromJson<String>(json['semester']),
      status: serializer.fromJson<String>(json['status']),
      notionUrl: serializer.fromJson<String?>(json['notionUrl']),
      aliasesJson: serializer.fromJson<String>(json['aliasesJson']),
      professorsJson: serializer.fromJson<String>(json['professorsJson']),
      scheduleHintsJson: serializer.fromJson<String>(json['scheduleHintsJson']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'notionId': serializer.toJson<String>(notionId),
      'name': serializer.toJson<String>(name),
      'year': serializer.toJson<String>(year),
      'semester': serializer.toJson<String>(semester),
      'status': serializer.toJson<String>(status),
      'notionUrl': serializer.toJson<String?>(notionUrl),
      'aliasesJson': serializer.toJson<String>(aliasesJson),
      'professorsJson': serializer.toJson<String>(professorsJson),
      'scheduleHintsJson': serializer.toJson<String>(scheduleHintsJson),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  CachedSubjectRow copyWith({
    String? notionId,
    String? name,
    String? year,
    String? semester,
    String? status,
    Value<String?> notionUrl = const Value.absent(),
    String? aliasesJson,
    String? professorsJson,
    String? scheduleHintsJson,
    DateTime? lastSyncedAt,
  }) => CachedSubjectRow(
    notionId: notionId ?? this.notionId,
    name: name ?? this.name,
    year: year ?? this.year,
    semester: semester ?? this.semester,
    status: status ?? this.status,
    notionUrl: notionUrl.present ? notionUrl.value : this.notionUrl,
    aliasesJson: aliasesJson ?? this.aliasesJson,
    professorsJson: professorsJson ?? this.professorsJson,
    scheduleHintsJson: scheduleHintsJson ?? this.scheduleHintsJson,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  CachedSubjectRow copyWithCompanion(CachedSubjectsCompanion data) {
    return CachedSubjectRow(
      notionId: data.notionId.present ? data.notionId.value : this.notionId,
      name: data.name.present ? data.name.value : this.name,
      year: data.year.present ? data.year.value : this.year,
      semester: data.semester.present ? data.semester.value : this.semester,
      status: data.status.present ? data.status.value : this.status,
      notionUrl: data.notionUrl.present ? data.notionUrl.value : this.notionUrl,
      aliasesJson: data.aliasesJson.present
          ? data.aliasesJson.value
          : this.aliasesJson,
      professorsJson: data.professorsJson.present
          ? data.professorsJson.value
          : this.professorsJson,
      scheduleHintsJson: data.scheduleHintsJson.present
          ? data.scheduleHintsJson.value
          : this.scheduleHintsJson,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSubjectRow(')
          ..write('notionId: $notionId, ')
          ..write('name: $name, ')
          ..write('year: $year, ')
          ..write('semester: $semester, ')
          ..write('status: $status, ')
          ..write('notionUrl: $notionUrl, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('professorsJson: $professorsJson, ')
          ..write('scheduleHintsJson: $scheduleHintsJson, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    notionId,
    name,
    year,
    semester,
    status,
    notionUrl,
    aliasesJson,
    professorsJson,
    scheduleHintsJson,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSubjectRow &&
          other.notionId == this.notionId &&
          other.name == this.name &&
          other.year == this.year &&
          other.semester == this.semester &&
          other.status == this.status &&
          other.notionUrl == this.notionUrl &&
          other.aliasesJson == this.aliasesJson &&
          other.professorsJson == this.professorsJson &&
          other.scheduleHintsJson == this.scheduleHintsJson &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedSubjectsCompanion extends UpdateCompanion<CachedSubjectRow> {
  final Value<String> notionId;
  final Value<String> name;
  final Value<String> year;
  final Value<String> semester;
  final Value<String> status;
  final Value<String?> notionUrl;
  final Value<String> aliasesJson;
  final Value<String> professorsJson;
  final Value<String> scheduleHintsJson;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedSubjectsCompanion({
    this.notionId = const Value.absent(),
    this.name = const Value.absent(),
    this.year = const Value.absent(),
    this.semester = const Value.absent(),
    this.status = const Value.absent(),
    this.notionUrl = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.professorsJson = const Value.absent(),
    this.scheduleHintsJson = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSubjectsCompanion.insert({
    required String notionId,
    required String name,
    required String year,
    required String semester,
    required String status,
    this.notionUrl = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.professorsJson = const Value.absent(),
    this.scheduleHintsJson = const Value.absent(),
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : notionId = Value(notionId),
       name = Value(name),
       year = Value(year),
       semester = Value(semester),
       status = Value(status),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedSubjectRow> custom({
    Expression<String>? notionId,
    Expression<String>? name,
    Expression<String>? year,
    Expression<String>? semester,
    Expression<String>? status,
    Expression<String>? notionUrl,
    Expression<String>? aliasesJson,
    Expression<String>? professorsJson,
    Expression<String>? scheduleHintsJson,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (notionId != null) 'notion_id': notionId,
      if (name != null) 'name': name,
      if (year != null) 'year': year,
      if (semester != null) 'semester': semester,
      if (status != null) 'status': status,
      if (notionUrl != null) 'notion_url': notionUrl,
      if (aliasesJson != null) 'aliases_json': aliasesJson,
      if (professorsJson != null) 'professors_json': professorsJson,
      if (scheduleHintsJson != null) 'schedule_hints_json': scheduleHintsJson,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSubjectsCompanion copyWith({
    Value<String>? notionId,
    Value<String>? name,
    Value<String>? year,
    Value<String>? semester,
    Value<String>? status,
    Value<String?>? notionUrl,
    Value<String>? aliasesJson,
    Value<String>? professorsJson,
    Value<String>? scheduleHintsJson,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedSubjectsCompanion(
      notionId: notionId ?? this.notionId,
      name: name ?? this.name,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      status: status ?? this.status,
      notionUrl: notionUrl ?? this.notionUrl,
      aliasesJson: aliasesJson ?? this.aliasesJson,
      professorsJson: professorsJson ?? this.professorsJson,
      scheduleHintsJson: scheduleHintsJson ?? this.scheduleHintsJson,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (notionId.present) {
      map['notion_id'] = Variable<String>(notionId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (semester.present) {
      map['semester'] = Variable<String>(semester.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notionUrl.present) {
      map['notion_url'] = Variable<String>(notionUrl.value);
    }
    if (aliasesJson.present) {
      map['aliases_json'] = Variable<String>(aliasesJson.value);
    }
    if (professorsJson.present) {
      map['professors_json'] = Variable<String>(professorsJson.value);
    }
    if (scheduleHintsJson.present) {
      map['schedule_hints_json'] = Variable<String>(scheduleHintsJson.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSubjectsCompanion(')
          ..write('notionId: $notionId, ')
          ..write('name: $name, ')
          ..write('year: $year, ')
          ..write('semester: $semester, ')
          ..write('status: $status, ')
          ..write('notionUrl: $notionUrl, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('professorsJson: $professorsJson, ')
          ..write('scheduleHintsJson: $scheduleHintsJson, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncJobsTable extends SyncJobs
    with TableInfo<$SyncJobsTable, SyncJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firefliesIdMeta = const VerificationMeta(
    'firefliesId',
  );
  @override
  late final GeneratedColumn<String> firefliesId = GeneratedColumn<String>(
    'fireflies_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _meetingTitleMeta = const VerificationMeta(
    'meetingTitle',
  );
  @override
  late final GeneratedColumn<String> meetingTitle = GeneratedColumn<String>(
    'meeting_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingDateMeta = const VerificationMeta(
    'meetingDate',
  );
  @override
  late final GeneratedColumn<DateTime> meetingDate = GeneratedColumn<DateTime>(
    'meeting_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firefliesUrlMeta = const VerificationMeta(
    'firefliesUrl',
  );
  @override
  late final GeneratedColumn<String> firefliesUrl = GeneratedColumn<String>(
    'fireflies_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('discovered'),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('fireflies'),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectNameMeta = const VerificationMeta(
    'subjectName',
  );
  @override
  late final GeneratedColumn<String> subjectName = GeneratedColumn<String>(
    'subject_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _classificationConfidenceMeta =
      const VerificationMeta('classificationConfidence');
  @override
  late final GeneratedColumn<double> classificationConfidence =
      GeneratedColumn<double>(
        'classification_confidence',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _classificationCandidatesJsonMeta =
      const VerificationMeta('classificationCandidatesJson');
  @override
  late final GeneratedColumn<String> classificationCandidatesJson =
      GeneratedColumn<String>(
        'classification_candidates_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _transcriptJsonMeta = const VerificationMeta(
    'transcriptJson',
  );
  @override
  late final GeneratedColumn<String> transcriptJson = GeneratedColumn<String>(
    'transcript_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryTitleMeta = const VerificationMeta(
    'summaryTitle',
  );
  @override
  late final GeneratedColumn<String> summaryTitle = GeneratedColumn<String>(
    'summary_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryPartialsJsonMeta =
      const VerificationMeta('summaryPartialsJson');
  @override
  late final GeneratedColumn<String> summaryPartialsJson =
      GeneratedColumn<String>(
        'summary_partials_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notionPageIdMeta = const VerificationMeta(
    'notionPageId',
  );
  @override
  late final GeneratedColumn<String> notionPageId = GeneratedColumn<String>(
    'notion_page_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notionUrlMeta = const VerificationMeta(
    'notionUrl',
  );
  @override
  late final GeneratedColumn<String> notionUrl = GeneratedColumn<String>(
    'notion_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reprocessModeMeta = const VerificationMeta(
    'reprocessMode',
  );
  @override
  late final GeneratedColumn<String> reprocessMode = GeneratedColumn<String>(
    'reprocess_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorTypeMeta = const VerificationMeta(
    'lastErrorType',
  );
  @override
  late final GeneratedColumn<String> lastErrorType = GeneratedColumn<String>(
    'last_error_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMessageMeta = const VerificationMeta(
    'lastErrorMessage',
  );
  @override
  late final GeneratedColumn<String> lastErrorMessage = GeneratedColumn<String>(
    'last_error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discoveredAtMeta = const VerificationMeta(
    'discoveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> discoveredAt = GeneratedColumn<DateTime>(
    'discovered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseOwnerMeta = const VerificationMeta(
    'leaseOwner',
  );
  @override
  late final GeneratedColumn<String> leaseOwner = GeneratedColumn<String>(
    'lease_owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseExpiresAtMeta = const VerificationMeta(
    'leaseExpiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> leaseExpiresAt =
      GeneratedColumn<DateTime>(
        'lease_expires_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    firefliesId,
    meetingTitle,
    meetingDate,
    firefliesUrl,
    status,
    sourceType,
    subjectId,
    subjectName,
    classificationConfidence,
    classificationCandidatesJson,
    transcriptJson,
    summaryTitle,
    summaryJson,
    summaryPartialsJson,
    notionPageId,
    notionUrl,
    reprocessMode,
    attemptCount,
    nextRetryAt,
    lastErrorType,
    lastErrorMessage,
    discoveredAt,
    startedAt,
    updatedAt,
    completedAt,
    leaseOwner,
    leaseExpiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('fireflies_id')) {
      context.handle(
        _firefliesIdMeta,
        firefliesId.isAcceptableOrUnknown(
          data['fireflies_id']!,
          _firefliesIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firefliesIdMeta);
    }
    if (data.containsKey('meeting_title')) {
      context.handle(
        _meetingTitleMeta,
        meetingTitle.isAcceptableOrUnknown(
          data['meeting_title']!,
          _meetingTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_meetingTitleMeta);
    }
    if (data.containsKey('meeting_date')) {
      context.handle(
        _meetingDateMeta,
        meetingDate.isAcceptableOrUnknown(
          data['meeting_date']!,
          _meetingDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_meetingDateMeta);
    }
    if (data.containsKey('fireflies_url')) {
      context.handle(
        _firefliesUrlMeta,
        firefliesUrl.isAcceptableOrUnknown(
          data['fireflies_url']!,
          _firefliesUrlMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('subject_name')) {
      context.handle(
        _subjectNameMeta,
        subjectName.isAcceptableOrUnknown(
          data['subject_name']!,
          _subjectNameMeta,
        ),
      );
    }
    if (data.containsKey('classification_confidence')) {
      context.handle(
        _classificationConfidenceMeta,
        classificationConfidence.isAcceptableOrUnknown(
          data['classification_confidence']!,
          _classificationConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('classification_candidates_json')) {
      context.handle(
        _classificationCandidatesJsonMeta,
        classificationCandidatesJson.isAcceptableOrUnknown(
          data['classification_candidates_json']!,
          _classificationCandidatesJsonMeta,
        ),
      );
    }
    if (data.containsKey('transcript_json')) {
      context.handle(
        _transcriptJsonMeta,
        transcriptJson.isAcceptableOrUnknown(
          data['transcript_json']!,
          _transcriptJsonMeta,
        ),
      );
    }
    if (data.containsKey('summary_title')) {
      context.handle(
        _summaryTitleMeta,
        summaryTitle.isAcceptableOrUnknown(
          data['summary_title']!,
          _summaryTitleMeta,
        ),
      );
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    if (data.containsKey('summary_partials_json')) {
      context.handle(
        _summaryPartialsJsonMeta,
        summaryPartialsJson.isAcceptableOrUnknown(
          data['summary_partials_json']!,
          _summaryPartialsJsonMeta,
        ),
      );
    }
    if (data.containsKey('notion_page_id')) {
      context.handle(
        _notionPageIdMeta,
        notionPageId.isAcceptableOrUnknown(
          data['notion_page_id']!,
          _notionPageIdMeta,
        ),
      );
    }
    if (data.containsKey('notion_url')) {
      context.handle(
        _notionUrlMeta,
        notionUrl.isAcceptableOrUnknown(data['notion_url']!, _notionUrlMeta),
      );
    }
    if (data.containsKey('reprocess_mode')) {
      context.handle(
        _reprocessModeMeta,
        reprocessMode.isAcceptableOrUnknown(
          data['reprocess_mode']!,
          _reprocessModeMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error_type')) {
      context.handle(
        _lastErrorTypeMeta,
        lastErrorType.isAcceptableOrUnknown(
          data['last_error_type']!,
          _lastErrorTypeMeta,
        ),
      );
    }
    if (data.containsKey('last_error_message')) {
      context.handle(
        _lastErrorMessageMeta,
        lastErrorMessage.isAcceptableOrUnknown(
          data['last_error_message']!,
          _lastErrorMessageMeta,
        ),
      );
    }
    if (data.containsKey('discovered_at')) {
      context.handle(
        _discoveredAtMeta,
        discoveredAt.isAcceptableOrUnknown(
          data['discovered_at']!,
          _discoveredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_discoveredAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('lease_owner')) {
      context.handle(
        _leaseOwnerMeta,
        leaseOwner.isAcceptableOrUnknown(data['lease_owner']!, _leaseOwnerMeta),
      );
    }
    if (data.containsKey('lease_expires_at')) {
      context.handle(
        _leaseExpiresAtMeta,
        leaseExpiresAt.isAcceptableOrUnknown(
          data['lease_expires_at']!,
          _leaseExpiresAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncJobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      firefliesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fireflies_id'],
      )!,
      meetingTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_title'],
      )!,
      meetingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}meeting_date'],
      )!,
      firefliesUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fireflies_url'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      subjectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_name'],
      ),
      classificationConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}classification_confidence'],
      ),
      classificationCandidatesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}classification_candidates_json'],
      ),
      transcriptJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_json'],
      ),
      summaryTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_title'],
      ),
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      ),
      summaryPartialsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_partials_json'],
      ),
      notionPageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notion_page_id'],
      ),
      notionUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notion_url'],
      ),
      reprocessMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reprocess_mode'],
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastErrorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_type'],
      ),
      lastErrorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_message'],
      ),
      discoveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}discovered_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      leaseOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_owner'],
      ),
      leaseExpiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_expires_at'],
      ),
    );
  }

  @override
  $SyncJobsTable createAlias(String alias) {
    return $SyncJobsTable(attachedDatabase, alias);
  }
}

class SyncJobRow extends DataClass implements Insertable<SyncJobRow> {
  final String id;
  final String firefliesId;
  final String meetingTitle;
  final DateTime meetingDate;
  final String? firefliesUrl;
  final String status;
  final String sourceType;
  final String? subjectId;
  final String? subjectName;
  final double? classificationConfidence;
  final String? classificationCandidatesJson;
  final String? transcriptJson;
  final String? summaryTitle;
  final String? summaryJson;
  final String? summaryPartialsJson;
  final String? notionPageId;
  final String? notionUrl;
  final String? reprocessMode;
  final int attemptCount;
  final DateTime? nextRetryAt;
  final String? lastErrorType;
  final String? lastErrorMessage;
  final DateTime discoveredAt;
  final DateTime? startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? leaseOwner;
  final DateTime? leaseExpiresAt;
  const SyncJobRow({
    required this.id,
    required this.firefliesId,
    required this.meetingTitle,
    required this.meetingDate,
    this.firefliesUrl,
    required this.status,
    required this.sourceType,
    this.subjectId,
    this.subjectName,
    this.classificationConfidence,
    this.classificationCandidatesJson,
    this.transcriptJson,
    this.summaryTitle,
    this.summaryJson,
    this.summaryPartialsJson,
    this.notionPageId,
    this.notionUrl,
    this.reprocessMode,
    required this.attemptCount,
    this.nextRetryAt,
    this.lastErrorType,
    this.lastErrorMessage,
    required this.discoveredAt,
    this.startedAt,
    required this.updatedAt,
    this.completedAt,
    this.leaseOwner,
    this.leaseExpiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['fireflies_id'] = Variable<String>(firefliesId);
    map['meeting_title'] = Variable<String>(meetingTitle);
    map['meeting_date'] = Variable<DateTime>(meetingDate);
    if (!nullToAbsent || firefliesUrl != null) {
      map['fireflies_url'] = Variable<String>(firefliesUrl);
    }
    map['status'] = Variable<String>(status);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    if (!nullToAbsent || subjectName != null) {
      map['subject_name'] = Variable<String>(subjectName);
    }
    if (!nullToAbsent || classificationConfidence != null) {
      map['classification_confidence'] = Variable<double>(
        classificationConfidence,
      );
    }
    if (!nullToAbsent || classificationCandidatesJson != null) {
      map['classification_candidates_json'] = Variable<String>(
        classificationCandidatesJson,
      );
    }
    if (!nullToAbsent || transcriptJson != null) {
      map['transcript_json'] = Variable<String>(transcriptJson);
    }
    if (!nullToAbsent || summaryTitle != null) {
      map['summary_title'] = Variable<String>(summaryTitle);
    }
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    if (!nullToAbsent || summaryPartialsJson != null) {
      map['summary_partials_json'] = Variable<String>(summaryPartialsJson);
    }
    if (!nullToAbsent || notionPageId != null) {
      map['notion_page_id'] = Variable<String>(notionPageId);
    }
    if (!nullToAbsent || notionUrl != null) {
      map['notion_url'] = Variable<String>(notionUrl);
    }
    if (!nullToAbsent || reprocessMode != null) {
      map['reprocess_mode'] = Variable<String>(reprocessMode);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || lastErrorType != null) {
      map['last_error_type'] = Variable<String>(lastErrorType);
    }
    if (!nullToAbsent || lastErrorMessage != null) {
      map['last_error_message'] = Variable<String>(lastErrorMessage);
    }
    map['discovered_at'] = Variable<DateTime>(discoveredAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || leaseOwner != null) {
      map['lease_owner'] = Variable<String>(leaseOwner);
    }
    if (!nullToAbsent || leaseExpiresAt != null) {
      map['lease_expires_at'] = Variable<DateTime>(leaseExpiresAt);
    }
    return map;
  }

  SyncJobsCompanion toCompanion(bool nullToAbsent) {
    return SyncJobsCompanion(
      id: Value(id),
      firefliesId: Value(firefliesId),
      meetingTitle: Value(meetingTitle),
      meetingDate: Value(meetingDate),
      firefliesUrl: firefliesUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(firefliesUrl),
      status: Value(status),
      sourceType: Value(sourceType),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      subjectName: subjectName == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectName),
      classificationConfidence: classificationConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(classificationConfidence),
      classificationCandidatesJson:
          classificationCandidatesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(classificationCandidatesJson),
      transcriptJson: transcriptJson == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptJson),
      summaryTitle: summaryTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryTitle),
      summaryJson: summaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryJson),
      summaryPartialsJson: summaryPartialsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryPartialsJson),
      notionPageId: notionPageId == null && nullToAbsent
          ? const Value.absent()
          : Value(notionPageId),
      notionUrl: notionUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(notionUrl),
      reprocessMode: reprocessMode == null && nullToAbsent
          ? const Value.absent()
          : Value(reprocessMode),
      attemptCount: Value(attemptCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastErrorType: lastErrorType == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorType),
      lastErrorMessage: lastErrorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorMessage),
      discoveredAt: Value(discoveredAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      leaseOwner: leaseOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseOwner),
      leaseExpiresAt: leaseExpiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseExpiresAt),
    );
  }

  factory SyncJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncJobRow(
      id: serializer.fromJson<String>(json['id']),
      firefliesId: serializer.fromJson<String>(json['firefliesId']),
      meetingTitle: serializer.fromJson<String>(json['meetingTitle']),
      meetingDate: serializer.fromJson<DateTime>(json['meetingDate']),
      firefliesUrl: serializer.fromJson<String?>(json['firefliesUrl']),
      status: serializer.fromJson<String>(json['status']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      subjectName: serializer.fromJson<String?>(json['subjectName']),
      classificationConfidence: serializer.fromJson<double?>(
        json['classificationConfidence'],
      ),
      classificationCandidatesJson: serializer.fromJson<String?>(
        json['classificationCandidatesJson'],
      ),
      transcriptJson: serializer.fromJson<String?>(json['transcriptJson']),
      summaryTitle: serializer.fromJson<String?>(json['summaryTitle']),
      summaryJson: serializer.fromJson<String?>(json['summaryJson']),
      summaryPartialsJson: serializer.fromJson<String?>(
        json['summaryPartialsJson'],
      ),
      notionPageId: serializer.fromJson<String?>(json['notionPageId']),
      notionUrl: serializer.fromJson<String?>(json['notionUrl']),
      reprocessMode: serializer.fromJson<String?>(json['reprocessMode']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastErrorType: serializer.fromJson<String?>(json['lastErrorType']),
      lastErrorMessage: serializer.fromJson<String?>(json['lastErrorMessage']),
      discoveredAt: serializer.fromJson<DateTime>(json['discoveredAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      leaseOwner: serializer.fromJson<String?>(json['leaseOwner']),
      leaseExpiresAt: serializer.fromJson<DateTime?>(json['leaseExpiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'firefliesId': serializer.toJson<String>(firefliesId),
      'meetingTitle': serializer.toJson<String>(meetingTitle),
      'meetingDate': serializer.toJson<DateTime>(meetingDate),
      'firefliesUrl': serializer.toJson<String?>(firefliesUrl),
      'status': serializer.toJson<String>(status),
      'sourceType': serializer.toJson<String>(sourceType),
      'subjectId': serializer.toJson<String?>(subjectId),
      'subjectName': serializer.toJson<String?>(subjectName),
      'classificationConfidence': serializer.toJson<double?>(
        classificationConfidence,
      ),
      'classificationCandidatesJson': serializer.toJson<String?>(
        classificationCandidatesJson,
      ),
      'transcriptJson': serializer.toJson<String?>(transcriptJson),
      'summaryTitle': serializer.toJson<String?>(summaryTitle),
      'summaryJson': serializer.toJson<String?>(summaryJson),
      'summaryPartialsJson': serializer.toJson<String?>(summaryPartialsJson),
      'notionPageId': serializer.toJson<String?>(notionPageId),
      'notionUrl': serializer.toJson<String?>(notionUrl),
      'reprocessMode': serializer.toJson<String?>(reprocessMode),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastErrorType': serializer.toJson<String?>(lastErrorType),
      'lastErrorMessage': serializer.toJson<String?>(lastErrorMessage),
      'discoveredAt': serializer.toJson<DateTime>(discoveredAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'leaseOwner': serializer.toJson<String?>(leaseOwner),
      'leaseExpiresAt': serializer.toJson<DateTime?>(leaseExpiresAt),
    };
  }

  SyncJobRow copyWith({
    String? id,
    String? firefliesId,
    String? meetingTitle,
    DateTime? meetingDate,
    Value<String?> firefliesUrl = const Value.absent(),
    String? status,
    String? sourceType,
    Value<String?> subjectId = const Value.absent(),
    Value<String?> subjectName = const Value.absent(),
    Value<double?> classificationConfidence = const Value.absent(),
    Value<String?> classificationCandidatesJson = const Value.absent(),
    Value<String?> transcriptJson = const Value.absent(),
    Value<String?> summaryTitle = const Value.absent(),
    Value<String?> summaryJson = const Value.absent(),
    Value<String?> summaryPartialsJson = const Value.absent(),
    Value<String?> notionPageId = const Value.absent(),
    Value<String?> notionUrl = const Value.absent(),
    Value<String?> reprocessMode = const Value.absent(),
    int? attemptCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<String?> lastErrorType = const Value.absent(),
    Value<String?> lastErrorMessage = const Value.absent(),
    DateTime? discoveredAt,
    Value<DateTime?> startedAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> leaseOwner = const Value.absent(),
    Value<DateTime?> leaseExpiresAt = const Value.absent(),
  }) => SyncJobRow(
    id: id ?? this.id,
    firefliesId: firefliesId ?? this.firefliesId,
    meetingTitle: meetingTitle ?? this.meetingTitle,
    meetingDate: meetingDate ?? this.meetingDate,
    firefliesUrl: firefliesUrl.present ? firefliesUrl.value : this.firefliesUrl,
    status: status ?? this.status,
    sourceType: sourceType ?? this.sourceType,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    subjectName: subjectName.present ? subjectName.value : this.subjectName,
    classificationConfidence: classificationConfidence.present
        ? classificationConfidence.value
        : this.classificationConfidence,
    classificationCandidatesJson: classificationCandidatesJson.present
        ? classificationCandidatesJson.value
        : this.classificationCandidatesJson,
    transcriptJson: transcriptJson.present
        ? transcriptJson.value
        : this.transcriptJson,
    summaryTitle: summaryTitle.present ? summaryTitle.value : this.summaryTitle,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
    summaryPartialsJson: summaryPartialsJson.present
        ? summaryPartialsJson.value
        : this.summaryPartialsJson,
    notionPageId: notionPageId.present ? notionPageId.value : this.notionPageId,
    notionUrl: notionUrl.present ? notionUrl.value : this.notionUrl,
    reprocessMode: reprocessMode.present
        ? reprocessMode.value
        : this.reprocessMode,
    attemptCount: attemptCount ?? this.attemptCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastErrorType: lastErrorType.present
        ? lastErrorType.value
        : this.lastErrorType,
    lastErrorMessage: lastErrorMessage.present
        ? lastErrorMessage.value
        : this.lastErrorMessage,
    discoveredAt: discoveredAt ?? this.discoveredAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    leaseOwner: leaseOwner.present ? leaseOwner.value : this.leaseOwner,
    leaseExpiresAt: leaseExpiresAt.present
        ? leaseExpiresAt.value
        : this.leaseExpiresAt,
  );
  SyncJobRow copyWithCompanion(SyncJobsCompanion data) {
    return SyncJobRow(
      id: data.id.present ? data.id.value : this.id,
      firefliesId: data.firefliesId.present
          ? data.firefliesId.value
          : this.firefliesId,
      meetingTitle: data.meetingTitle.present
          ? data.meetingTitle.value
          : this.meetingTitle,
      meetingDate: data.meetingDate.present
          ? data.meetingDate.value
          : this.meetingDate,
      firefliesUrl: data.firefliesUrl.present
          ? data.firefliesUrl.value
          : this.firefliesUrl,
      status: data.status.present ? data.status.value : this.status,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      subjectName: data.subjectName.present
          ? data.subjectName.value
          : this.subjectName,
      classificationConfidence: data.classificationConfidence.present
          ? data.classificationConfidence.value
          : this.classificationConfidence,
      classificationCandidatesJson: data.classificationCandidatesJson.present
          ? data.classificationCandidatesJson.value
          : this.classificationCandidatesJson,
      transcriptJson: data.transcriptJson.present
          ? data.transcriptJson.value
          : this.transcriptJson,
      summaryTitle: data.summaryTitle.present
          ? data.summaryTitle.value
          : this.summaryTitle,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      summaryPartialsJson: data.summaryPartialsJson.present
          ? data.summaryPartialsJson.value
          : this.summaryPartialsJson,
      notionPageId: data.notionPageId.present
          ? data.notionPageId.value
          : this.notionPageId,
      notionUrl: data.notionUrl.present ? data.notionUrl.value : this.notionUrl,
      reprocessMode: data.reprocessMode.present
          ? data.reprocessMode.value
          : this.reprocessMode,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastErrorType: data.lastErrorType.present
          ? data.lastErrorType.value
          : this.lastErrorType,
      lastErrorMessage: data.lastErrorMessage.present
          ? data.lastErrorMessage.value
          : this.lastErrorMessage,
      discoveredAt: data.discoveredAt.present
          ? data.discoveredAt.value
          : this.discoveredAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      leaseOwner: data.leaseOwner.present
          ? data.leaseOwner.value
          : this.leaseOwner,
      leaseExpiresAt: data.leaseExpiresAt.present
          ? data.leaseExpiresAt.value
          : this.leaseExpiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncJobRow(')
          ..write('id: $id, ')
          ..write('firefliesId: $firefliesId, ')
          ..write('meetingTitle: $meetingTitle, ')
          ..write('meetingDate: $meetingDate, ')
          ..write('firefliesUrl: $firefliesUrl, ')
          ..write('status: $status, ')
          ..write('sourceType: $sourceType, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectName: $subjectName, ')
          ..write('classificationConfidence: $classificationConfidence, ')
          ..write(
            'classificationCandidatesJson: $classificationCandidatesJson, ',
          )
          ..write('transcriptJson: $transcriptJson, ')
          ..write('summaryTitle: $summaryTitle, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('summaryPartialsJson: $summaryPartialsJson, ')
          ..write('notionPageId: $notionPageId, ')
          ..write('notionUrl: $notionUrl, ')
          ..write('reprocessMode: $reprocessMode, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastErrorType: $lastErrorType, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('discoveredAt: $discoveredAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseExpiresAt: $leaseExpiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    firefliesId,
    meetingTitle,
    meetingDate,
    firefliesUrl,
    status,
    sourceType,
    subjectId,
    subjectName,
    classificationConfidence,
    classificationCandidatesJson,
    transcriptJson,
    summaryTitle,
    summaryJson,
    summaryPartialsJson,
    notionPageId,
    notionUrl,
    reprocessMode,
    attemptCount,
    nextRetryAt,
    lastErrorType,
    lastErrorMessage,
    discoveredAt,
    startedAt,
    updatedAt,
    completedAt,
    leaseOwner,
    leaseExpiresAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncJobRow &&
          other.id == this.id &&
          other.firefliesId == this.firefliesId &&
          other.meetingTitle == this.meetingTitle &&
          other.meetingDate == this.meetingDate &&
          other.firefliesUrl == this.firefliesUrl &&
          other.status == this.status &&
          other.sourceType == this.sourceType &&
          other.subjectId == this.subjectId &&
          other.subjectName == this.subjectName &&
          other.classificationConfidence == this.classificationConfidence &&
          other.classificationCandidatesJson ==
              this.classificationCandidatesJson &&
          other.transcriptJson == this.transcriptJson &&
          other.summaryTitle == this.summaryTitle &&
          other.summaryJson == this.summaryJson &&
          other.summaryPartialsJson == this.summaryPartialsJson &&
          other.notionPageId == this.notionPageId &&
          other.notionUrl == this.notionUrl &&
          other.reprocessMode == this.reprocessMode &&
          other.attemptCount == this.attemptCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastErrorType == this.lastErrorType &&
          other.lastErrorMessage == this.lastErrorMessage &&
          other.discoveredAt == this.discoveredAt &&
          other.startedAt == this.startedAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.leaseOwner == this.leaseOwner &&
          other.leaseExpiresAt == this.leaseExpiresAt);
}

class SyncJobsCompanion extends UpdateCompanion<SyncJobRow> {
  final Value<String> id;
  final Value<String> firefliesId;
  final Value<String> meetingTitle;
  final Value<DateTime> meetingDate;
  final Value<String?> firefliesUrl;
  final Value<String> status;
  final Value<String> sourceType;
  final Value<String?> subjectId;
  final Value<String?> subjectName;
  final Value<double?> classificationConfidence;
  final Value<String?> classificationCandidatesJson;
  final Value<String?> transcriptJson;
  final Value<String?> summaryTitle;
  final Value<String?> summaryJson;
  final Value<String?> summaryPartialsJson;
  final Value<String?> notionPageId;
  final Value<String?> notionUrl;
  final Value<String?> reprocessMode;
  final Value<int> attemptCount;
  final Value<DateTime?> nextRetryAt;
  final Value<String?> lastErrorType;
  final Value<String?> lastErrorMessage;
  final Value<DateTime> discoveredAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<String?> leaseOwner;
  final Value<DateTime?> leaseExpiresAt;
  final Value<int> rowid;
  const SyncJobsCompanion({
    this.id = const Value.absent(),
    this.firefliesId = const Value.absent(),
    this.meetingTitle = const Value.absent(),
    this.meetingDate = const Value.absent(),
    this.firefliesUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.classificationConfidence = const Value.absent(),
    this.classificationCandidatesJson = const Value.absent(),
    this.transcriptJson = const Value.absent(),
    this.summaryTitle = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.summaryPartialsJson = const Value.absent(),
    this.notionPageId = const Value.absent(),
    this.notionUrl = const Value.absent(),
    this.reprocessMode = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastErrorType = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.discoveredAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseExpiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncJobsCompanion.insert({
    required String id,
    required String firefliesId,
    required String meetingTitle,
    required DateTime meetingDate,
    this.firefliesUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.classificationConfidence = const Value.absent(),
    this.classificationCandidatesJson = const Value.absent(),
    this.transcriptJson = const Value.absent(),
    this.summaryTitle = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.summaryPartialsJson = const Value.absent(),
    this.notionPageId = const Value.absent(),
    this.notionUrl = const Value.absent(),
    this.reprocessMode = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastErrorType = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    required DateTime discoveredAt,
    this.startedAt = const Value.absent(),
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseExpiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       firefliesId = Value(firefliesId),
       meetingTitle = Value(meetingTitle),
       meetingDate = Value(meetingDate),
       discoveredAt = Value(discoveredAt),
       updatedAt = Value(updatedAt);
  static Insertable<SyncJobRow> custom({
    Expression<String>? id,
    Expression<String>? firefliesId,
    Expression<String>? meetingTitle,
    Expression<DateTime>? meetingDate,
    Expression<String>? firefliesUrl,
    Expression<String>? status,
    Expression<String>? sourceType,
    Expression<String>? subjectId,
    Expression<String>? subjectName,
    Expression<double>? classificationConfidence,
    Expression<String>? classificationCandidatesJson,
    Expression<String>? transcriptJson,
    Expression<String>? summaryTitle,
    Expression<String>? summaryJson,
    Expression<String>? summaryPartialsJson,
    Expression<String>? notionPageId,
    Expression<String>? notionUrl,
    Expression<String>? reprocessMode,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextRetryAt,
    Expression<String>? lastErrorType,
    Expression<String>? lastErrorMessage,
    Expression<DateTime>? discoveredAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? leaseOwner,
    Expression<DateTime>? leaseExpiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (firefliesId != null) 'fireflies_id': firefliesId,
      if (meetingTitle != null) 'meeting_title': meetingTitle,
      if (meetingDate != null) 'meeting_date': meetingDate,
      if (firefliesUrl != null) 'fireflies_url': firefliesUrl,
      if (status != null) 'status': status,
      if (sourceType != null) 'source_type': sourceType,
      if (subjectId != null) 'subject_id': subjectId,
      if (subjectName != null) 'subject_name': subjectName,
      if (classificationConfidence != null)
        'classification_confidence': classificationConfidence,
      if (classificationCandidatesJson != null)
        'classification_candidates_json': classificationCandidatesJson,
      if (transcriptJson != null) 'transcript_json': transcriptJson,
      if (summaryTitle != null) 'summary_title': summaryTitle,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (summaryPartialsJson != null)
        'summary_partials_json': summaryPartialsJson,
      if (notionPageId != null) 'notion_page_id': notionPageId,
      if (notionUrl != null) 'notion_url': notionUrl,
      if (reprocessMode != null) 'reprocess_mode': reprocessMode,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastErrorType != null) 'last_error_type': lastErrorType,
      if (lastErrorMessage != null) 'last_error_message': lastErrorMessage,
      if (discoveredAt != null) 'discovered_at': discoveredAt,
      if (startedAt != null) 'started_at': startedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (leaseOwner != null) 'lease_owner': leaseOwner,
      if (leaseExpiresAt != null) 'lease_expires_at': leaseExpiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? firefliesId,
    Value<String>? meetingTitle,
    Value<DateTime>? meetingDate,
    Value<String?>? firefliesUrl,
    Value<String>? status,
    Value<String>? sourceType,
    Value<String?>? subjectId,
    Value<String?>? subjectName,
    Value<double?>? classificationConfidence,
    Value<String?>? classificationCandidatesJson,
    Value<String?>? transcriptJson,
    Value<String?>? summaryTitle,
    Value<String?>? summaryJson,
    Value<String?>? summaryPartialsJson,
    Value<String?>? notionPageId,
    Value<String?>? notionUrl,
    Value<String?>? reprocessMode,
    Value<int>? attemptCount,
    Value<DateTime?>? nextRetryAt,
    Value<String?>? lastErrorType,
    Value<String?>? lastErrorMessage,
    Value<DateTime>? discoveredAt,
    Value<DateTime?>? startedAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<String?>? leaseOwner,
    Value<DateTime?>? leaseExpiresAt,
    Value<int>? rowid,
  }) {
    return SyncJobsCompanion(
      id: id ?? this.id,
      firefliesId: firefliesId ?? this.firefliesId,
      meetingTitle: meetingTitle ?? this.meetingTitle,
      meetingDate: meetingDate ?? this.meetingDate,
      firefliesUrl: firefliesUrl ?? this.firefliesUrl,
      status: status ?? this.status,
      sourceType: sourceType ?? this.sourceType,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      classificationConfidence:
          classificationConfidence ?? this.classificationConfidence,
      classificationCandidatesJson:
          classificationCandidatesJson ?? this.classificationCandidatesJson,
      transcriptJson: transcriptJson ?? this.transcriptJson,
      summaryTitle: summaryTitle ?? this.summaryTitle,
      summaryJson: summaryJson ?? this.summaryJson,
      summaryPartialsJson: summaryPartialsJson ?? this.summaryPartialsJson,
      notionPageId: notionPageId ?? this.notionPageId,
      notionUrl: notionUrl ?? this.notionUrl,
      reprocessMode: reprocessMode ?? this.reprocessMode,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastErrorType: lastErrorType ?? this.lastErrorType,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseExpiresAt: leaseExpiresAt ?? this.leaseExpiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (firefliesId.present) {
      map['fireflies_id'] = Variable<String>(firefliesId.value);
    }
    if (meetingTitle.present) {
      map['meeting_title'] = Variable<String>(meetingTitle.value);
    }
    if (meetingDate.present) {
      map['meeting_date'] = Variable<DateTime>(meetingDate.value);
    }
    if (firefliesUrl.present) {
      map['fireflies_url'] = Variable<String>(firefliesUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (subjectName.present) {
      map['subject_name'] = Variable<String>(subjectName.value);
    }
    if (classificationConfidence.present) {
      map['classification_confidence'] = Variable<double>(
        classificationConfidence.value,
      );
    }
    if (classificationCandidatesJson.present) {
      map['classification_candidates_json'] = Variable<String>(
        classificationCandidatesJson.value,
      );
    }
    if (transcriptJson.present) {
      map['transcript_json'] = Variable<String>(transcriptJson.value);
    }
    if (summaryTitle.present) {
      map['summary_title'] = Variable<String>(summaryTitle.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (summaryPartialsJson.present) {
      map['summary_partials_json'] = Variable<String>(
        summaryPartialsJson.value,
      );
    }
    if (notionPageId.present) {
      map['notion_page_id'] = Variable<String>(notionPageId.value);
    }
    if (notionUrl.present) {
      map['notion_url'] = Variable<String>(notionUrl.value);
    }
    if (reprocessMode.present) {
      map['reprocess_mode'] = Variable<String>(reprocessMode.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (lastErrorType.present) {
      map['last_error_type'] = Variable<String>(lastErrorType.value);
    }
    if (lastErrorMessage.present) {
      map['last_error_message'] = Variable<String>(lastErrorMessage.value);
    }
    if (discoveredAt.present) {
      map['discovered_at'] = Variable<DateTime>(discoveredAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (leaseOwner.present) {
      map['lease_owner'] = Variable<String>(leaseOwner.value);
    }
    if (leaseExpiresAt.present) {
      map['lease_expires_at'] = Variable<DateTime>(leaseExpiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncJobsCompanion(')
          ..write('id: $id, ')
          ..write('firefliesId: $firefliesId, ')
          ..write('meetingTitle: $meetingTitle, ')
          ..write('meetingDate: $meetingDate, ')
          ..write('firefliesUrl: $firefliesUrl, ')
          ..write('status: $status, ')
          ..write('sourceType: $sourceType, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectName: $subjectName, ')
          ..write('classificationConfidence: $classificationConfidence, ')
          ..write(
            'classificationCandidatesJson: $classificationCandidatesJson, ',
          )
          ..write('transcriptJson: $transcriptJson, ')
          ..write('summaryTitle: $summaryTitle, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('summaryPartialsJson: $summaryPartialsJson, ')
          ..write('notionPageId: $notionPageId, ')
          ..write('notionUrl: $notionUrl, ')
          ..write('reprocessMode: $reprocessMode, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastErrorType: $lastErrorType, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('discoveredAt: $discoveredAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseExpiresAt: $leaseExpiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JobEventsTable extends JobEvents
    with TableInfo<$JobEventsTable, JobEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JobEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sync_jobs (id)',
    ),
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, jobId, stage, message, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'job_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<JobEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JobEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JobEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $JobEventsTable createAlias(String alias) {
    return $JobEventsTable(attachedDatabase, alias);
  }
}

class JobEventRow extends DataClass implements Insertable<JobEventRow> {
  final int id;
  final String jobId;
  final String stage;
  final String message;
  final DateTime createdAt;
  const JobEventRow({
    required this.id,
    required this.jobId,
    required this.stage,
    required this.message,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['job_id'] = Variable<String>(jobId);
    map['stage'] = Variable<String>(stage);
    map['message'] = Variable<String>(message);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  JobEventsCompanion toCompanion(bool nullToAbsent) {
    return JobEventsCompanion(
      id: Value(id),
      jobId: Value(jobId),
      stage: Value(stage),
      message: Value(message),
      createdAt: Value(createdAt),
    );
  }

  factory JobEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JobEventRow(
      id: serializer.fromJson<int>(json['id']),
      jobId: serializer.fromJson<String>(json['jobId']),
      stage: serializer.fromJson<String>(json['stage']),
      message: serializer.fromJson<String>(json['message']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'jobId': serializer.toJson<String>(jobId),
      'stage': serializer.toJson<String>(stage),
      'message': serializer.toJson<String>(message),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  JobEventRow copyWith({
    int? id,
    String? jobId,
    String? stage,
    String? message,
    DateTime? createdAt,
  }) => JobEventRow(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    stage: stage ?? this.stage,
    message: message ?? this.message,
    createdAt: createdAt ?? this.createdAt,
  );
  JobEventRow copyWithCompanion(JobEventsCompanion data) {
    return JobEventRow(
      id: data.id.present ? data.id.value : this.id,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      stage: data.stage.present ? data.stage.value : this.stage,
      message: data.message.present ? data.message.value : this.message,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JobEventRow(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('stage: $stage, ')
          ..write('message: $message, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, jobId, stage, message, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JobEventRow &&
          other.id == this.id &&
          other.jobId == this.jobId &&
          other.stage == this.stage &&
          other.message == this.message &&
          other.createdAt == this.createdAt);
}

class JobEventsCompanion extends UpdateCompanion<JobEventRow> {
  final Value<int> id;
  final Value<String> jobId;
  final Value<String> stage;
  final Value<String> message;
  final Value<DateTime> createdAt;
  const JobEventsCompanion({
    this.id = const Value.absent(),
    this.jobId = const Value.absent(),
    this.stage = const Value.absent(),
    this.message = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  JobEventsCompanion.insert({
    this.id = const Value.absent(),
    required String jobId,
    required String stage,
    required String message,
    required DateTime createdAt,
  }) : jobId = Value(jobId),
       stage = Value(stage),
       message = Value(message),
       createdAt = Value(createdAt);
  static Insertable<JobEventRow> custom({
    Expression<int>? id,
    Expression<String>? jobId,
    Expression<String>? stage,
    Expression<String>? message,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jobId != null) 'job_id': jobId,
      if (stage != null) 'stage': stage,
      if (message != null) 'message': message,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  JobEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? jobId,
    Value<String>? stage,
    Value<String>? message,
    Value<DateTime>? createdAt,
  }) {
    return JobEventsCompanion(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      stage: stage ?? this.stage,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JobEventsCompanion(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('stage: $stage, ')
          ..write('message: $message, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorAtMeta = const VerificationMeta(
    'cursorAt',
  );
  @override
  late final GeneratedColumn<DateTime> cursorAt = GeneratedColumn<DateTime>(
    'cursor_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [source, cursorAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('cursor_at')) {
      context.handle(
        _cursorAtMeta,
        cursorAt.isAcceptableOrUnknown(data['cursor_at']!, _cursorAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cursorAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {source};
  @override
  SyncCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorRow(
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      cursorAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cursor_at'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursorRow extends DataClass implements Insertable<SyncCursorRow> {
  final String source;
  final DateTime cursorAt;
  const SyncCursorRow({required this.source, required this.cursorAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source'] = Variable<String>(source);
    map['cursor_at'] = Variable<DateTime>(cursorAt);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      source: Value(source),
      cursorAt: Value(cursorAt),
    );
  }

  factory SyncCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorRow(
      source: serializer.fromJson<String>(json['source']),
      cursorAt: serializer.fromJson<DateTime>(json['cursorAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'source': serializer.toJson<String>(source),
      'cursorAt': serializer.toJson<DateTime>(cursorAt),
    };
  }

  SyncCursorRow copyWith({String? source, DateTime? cursorAt}) => SyncCursorRow(
    source: source ?? this.source,
    cursorAt: cursorAt ?? this.cursorAt,
  );
  SyncCursorRow copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursorRow(
      source: data.source.present ? data.source.value : this.source,
      cursorAt: data.cursorAt.present ? data.cursorAt.value : this.cursorAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRow(')
          ..write('source: $source, ')
          ..write('cursorAt: $cursorAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(source, cursorAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorRow &&
          other.source == this.source &&
          other.cursorAt == this.cursorAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursorRow> {
  final Value<String> source;
  final Value<DateTime> cursorAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.source = const Value.absent(),
    this.cursorAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String source,
    required DateTime cursorAt,
    this.rowid = const Value.absent(),
  }) : source = Value(source),
       cursorAt = Value(cursorAt);
  static Insertable<SyncCursorRow> custom({
    Expression<String>? source,
    Expression<DateTime>? cursorAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (source != null) 'source': source,
      if (cursorAt != null) 'cursor_at': cursorAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? source,
    Value<DateTime>? cursorAt,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      source: source ?? this.source,
      cursorAt: cursorAt ?? this.cursorAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (cursorAt.present) {
      map['cursor_at'] = Variable<DateTime>(cursorAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('source: $source, ')
          ..write('cursorAt: $cursorAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsRecordsTable extends SettingsRecords
    with TableInfo<$SettingsRecordsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _setupCompleteMeta = const VerificationMeta(
    'setupComplete',
  );
  @override
  late final GeneratedColumn<bool> setupComplete = GeneratedColumn<bool>(
    'setup_complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("setup_complete" IN (0, 1))',
    ),
  );
  static const VerificationMeta _automaticSyncMeta = const VerificationMeta(
    'automaticSync',
  );
  @override
  late final GeneratedColumn<bool> automaticSync = GeneratedColumn<bool>(
    'automatic_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("automatic_sync" IN (0, 1))',
    ),
  );
  static const VerificationMeta _launchWithWindowsMeta = const VerificationMeta(
    'launchWithWindows',
  );
  @override
  late final GeneratedColumn<bool> launchWithWindows = GeneratedColumn<bool>(
    'launch_with_windows',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("launch_with_windows" IN (0, 1))',
    ),
  );
  static const VerificationMeta _syncOnLaunchMeta = const VerificationMeta(
    'syncOnLaunch',
  );
  @override
  late final GeneratedColumn<bool> syncOnLaunch = GeneratedColumn<bool>(
    'sync_on_launch',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_on_launch" IN (0, 1))',
    ),
  );
  static const VerificationMeta _backgroundMobileSyncMeta =
      const VerificationMeta('backgroundMobileSync');
  @override
  late final GeneratedColumn<bool> backgroundMobileSync = GeneratedColumn<bool>(
    'background_mobile_sync',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("background_mobile_sync" IN (0, 1))',
    ),
  );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _pollingMinutesMeta = const VerificationMeta(
    'pollingMinutes',
  );
  @override
  late final GeneratedColumn<int> pollingMinutes = GeneratedColumn<int>(
    'polling_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overlapHoursMeta = const VerificationMeta(
    'overlapHours',
  );
  @override
  late final GeneratedColumn<int> overlapHours = GeneratedColumn<int>(
    'overlap_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workerCountMeta = const VerificationMeta(
    'workerCount',
  );
  @override
  late final GeneratedColumn<int> workerCount = GeneratedColumn<int>(
    'worker_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keepTranscriptsMeta = const VerificationMeta(
    'keepTranscripts',
  );
  @override
  late final GeneratedColumn<bool> keepTranscripts = GeneratedColumn<bool>(
    'keep_transcripts',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_transcripts" IN (0, 1))',
    ),
  );
  static const VerificationMeta _cleanCompletedPayloadsMeta =
      const VerificationMeta('cleanCompletedPayloads');
  @override
  late final GeneratedColumn<bool> cleanCompletedPayloads =
      GeneratedColumn<bool>(
        'clean_completed_payloads',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("clean_completed_payloads" IN (0, 1))',
        ),
      );
  static const VerificationMeta _diagnosticsRetentionDaysMeta =
      const VerificationMeta('diagnosticsRetentionDays');
  @override
  late final GeneratedColumn<int> diagnosticsRetentionDays =
      GeneratedColumn<int>(
        'diagnostics_retention_days',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _useAiClassificationMeta =
      const VerificationMeta('useAiClassification');
  @override
  late final GeneratedColumn<bool> useAiClassification = GeneratedColumn<bool>(
    'use_ai_classification',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_ai_classification" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _academicIntegrationsEnabledMeta =
      const VerificationMeta('academicIntegrationsEnabled');
  @override
  late final GeneratedColumn<bool> academicIntegrationsEnabled =
      GeneratedColumn<bool>(
        'academic_integrations_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("academic_integrations_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _classificationModelMeta =
      const VerificationMeta('classificationModel');
  @override
  late final GeneratedColumn<String> classificationModel =
      GeneratedColumn<String>(
        'classification_model',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _summaryModelMeta = const VerificationMeta(
    'summaryModel',
  );
  @override
  late final GeneratedColumn<String> summaryModel = GeneratedColumn<String>(
    'summary_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoClassifyThresholdMeta =
      const VerificationMeta('autoClassifyThreshold');
  @override
  late final GeneratedColumn<double> autoClassifyThreshold =
      GeneratedColumn<double>(
        'auto_classify_threshold',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _reviewThresholdMeta = const VerificationMeta(
    'reviewThreshold',
  );
  @override
  late final GeneratedColumn<double> reviewThreshold = GeneratedColumn<double>(
    'review_threshold',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryLanguageMeta = const VerificationMeta(
    'summaryLanguage',
  );
  @override
  late final GeneratedColumn<String> summaryLanguage = GeneratedColumn<String>(
    'summary_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryDetailMeta = const VerificationMeta(
    'summaryDetail',
  );
  @override
  late final GeneratedColumn<String> summaryDetail = GeneratedColumn<String>(
    'summary_detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notionMetadataEnabledMeta =
      const VerificationMeta('notionMetadataEnabled');
  @override
  late final GeneratedColumn<bool> notionMetadataEnabled =
      GeneratedColumn<bool>(
        'notion_metadata_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("notion_metadata_enabled" IN (0, 1))',
        ),
      );
  static const VerificationMeta _notionSubjectsDataSourceIdMeta =
      const VerificationMeta('notionSubjectsDataSourceId');
  @override
  late final GeneratedColumn<String> notionSubjectsDataSourceId =
      GeneratedColumn<String>(
        'notion_subjects_data_source_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notionSummariesDataSourceIdMeta =
      const VerificationMeta('notionSummariesDataSourceId');
  @override
  late final GeneratedColumn<String> notionSummariesDataSourceId =
      GeneratedColumn<String>(
        'notion_summaries_data_source_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _relayBaseUrlMeta = const VerificationMeta(
    'relayBaseUrl',
  );
  @override
  late final GeneratedColumn<String> relayBaseUrl = GeneratedColumn<String>(
    'relay_base_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    setupComplete,
    automaticSync,
    launchWithWindows,
    syncOnLaunch,
    backgroundMobileSync,
    notificationsEnabled,
    pollingMinutes,
    overlapHours,
    workerCount,
    keepTranscripts,
    cleanCompletedPayloads,
    diagnosticsRetentionDays,
    useAiClassification,
    academicIntegrationsEnabled,
    classificationModel,
    summaryModel,
    autoClassifyThreshold,
    reviewThreshold,
    summaryLanguage,
    summaryDetail,
    notionMetadataEnabled,
    notionSubjectsDataSourceId,
    notionSummariesDataSourceId,
    relayBaseUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('setup_complete')) {
      context.handle(
        _setupCompleteMeta,
        setupComplete.isAcceptableOrUnknown(
          data['setup_complete']!,
          _setupCompleteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_setupCompleteMeta);
    }
    if (data.containsKey('automatic_sync')) {
      context.handle(
        _automaticSyncMeta,
        automaticSync.isAcceptableOrUnknown(
          data['automatic_sync']!,
          _automaticSyncMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_automaticSyncMeta);
    }
    if (data.containsKey('launch_with_windows')) {
      context.handle(
        _launchWithWindowsMeta,
        launchWithWindows.isAcceptableOrUnknown(
          data['launch_with_windows']!,
          _launchWithWindowsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_launchWithWindowsMeta);
    }
    if (data.containsKey('sync_on_launch')) {
      context.handle(
        _syncOnLaunchMeta,
        syncOnLaunch.isAcceptableOrUnknown(
          data['sync_on_launch']!,
          _syncOnLaunchMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_syncOnLaunchMeta);
    }
    if (data.containsKey('background_mobile_sync')) {
      context.handle(
        _backgroundMobileSyncMeta,
        backgroundMobileSync.isAcceptableOrUnknown(
          data['background_mobile_sync']!,
          _backgroundMobileSyncMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backgroundMobileSyncMeta);
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('polling_minutes')) {
      context.handle(
        _pollingMinutesMeta,
        pollingMinutes.isAcceptableOrUnknown(
          data['polling_minutes']!,
          _pollingMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pollingMinutesMeta);
    }
    if (data.containsKey('overlap_hours')) {
      context.handle(
        _overlapHoursMeta,
        overlapHours.isAcceptableOrUnknown(
          data['overlap_hours']!,
          _overlapHoursMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overlapHoursMeta);
    }
    if (data.containsKey('worker_count')) {
      context.handle(
        _workerCountMeta,
        workerCount.isAcceptableOrUnknown(
          data['worker_count']!,
          _workerCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workerCountMeta);
    }
    if (data.containsKey('keep_transcripts')) {
      context.handle(
        _keepTranscriptsMeta,
        keepTranscripts.isAcceptableOrUnknown(
          data['keep_transcripts']!,
          _keepTranscriptsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_keepTranscriptsMeta);
    }
    if (data.containsKey('clean_completed_payloads')) {
      context.handle(
        _cleanCompletedPayloadsMeta,
        cleanCompletedPayloads.isAcceptableOrUnknown(
          data['clean_completed_payloads']!,
          _cleanCompletedPayloadsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cleanCompletedPayloadsMeta);
    }
    if (data.containsKey('diagnostics_retention_days')) {
      context.handle(
        _diagnosticsRetentionDaysMeta,
        diagnosticsRetentionDays.isAcceptableOrUnknown(
          data['diagnostics_retention_days']!,
          _diagnosticsRetentionDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_diagnosticsRetentionDaysMeta);
    }
    if (data.containsKey('use_ai_classification')) {
      context.handle(
        _useAiClassificationMeta,
        useAiClassification.isAcceptableOrUnknown(
          data['use_ai_classification']!,
          _useAiClassificationMeta,
        ),
      );
    }
    if (data.containsKey('academic_integrations_enabled')) {
      context.handle(
        _academicIntegrationsEnabledMeta,
        academicIntegrationsEnabled.isAcceptableOrUnknown(
          data['academic_integrations_enabled']!,
          _academicIntegrationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('classification_model')) {
      context.handle(
        _classificationModelMeta,
        classificationModel.isAcceptableOrUnknown(
          data['classification_model']!,
          _classificationModelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_classificationModelMeta);
    }
    if (data.containsKey('summary_model')) {
      context.handle(
        _summaryModelMeta,
        summaryModel.isAcceptableOrUnknown(
          data['summary_model']!,
          _summaryModelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryModelMeta);
    }
    if (data.containsKey('auto_classify_threshold')) {
      context.handle(
        _autoClassifyThresholdMeta,
        autoClassifyThreshold.isAcceptableOrUnknown(
          data['auto_classify_threshold']!,
          _autoClassifyThresholdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_autoClassifyThresholdMeta);
    }
    if (data.containsKey('review_threshold')) {
      context.handle(
        _reviewThresholdMeta,
        reviewThreshold.isAcceptableOrUnknown(
          data['review_threshold']!,
          _reviewThresholdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reviewThresholdMeta);
    }
    if (data.containsKey('summary_language')) {
      context.handle(
        _summaryLanguageMeta,
        summaryLanguage.isAcceptableOrUnknown(
          data['summary_language']!,
          _summaryLanguageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryLanguageMeta);
    }
    if (data.containsKey('summary_detail')) {
      context.handle(
        _summaryDetailMeta,
        summaryDetail.isAcceptableOrUnknown(
          data['summary_detail']!,
          _summaryDetailMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryDetailMeta);
    }
    if (data.containsKey('notion_metadata_enabled')) {
      context.handle(
        _notionMetadataEnabledMeta,
        notionMetadataEnabled.isAcceptableOrUnknown(
          data['notion_metadata_enabled']!,
          _notionMetadataEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notionMetadataEnabledMeta);
    }
    if (data.containsKey('notion_subjects_data_source_id')) {
      context.handle(
        _notionSubjectsDataSourceIdMeta,
        notionSubjectsDataSourceId.isAcceptableOrUnknown(
          data['notion_subjects_data_source_id']!,
          _notionSubjectsDataSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('notion_summaries_data_source_id')) {
      context.handle(
        _notionSummariesDataSourceIdMeta,
        notionSummariesDataSourceId.isAcceptableOrUnknown(
          data['notion_summaries_data_source_id']!,
          _notionSummariesDataSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('relay_base_url')) {
      context.handle(
        _relayBaseUrlMeta,
        relayBaseUrl.isAcceptableOrUnknown(
          data['relay_base_url']!,
          _relayBaseUrlMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      setupComplete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}setup_complete'],
      )!,
      automaticSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}automatic_sync'],
      )!,
      launchWithWindows: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}launch_with_windows'],
      )!,
      syncOnLaunch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_on_launch'],
      )!,
      backgroundMobileSync: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}background_mobile_sync'],
      )!,
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      pollingMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}polling_minutes'],
      )!,
      overlapHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overlap_hours'],
      )!,
      workerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}worker_count'],
      )!,
      keepTranscripts: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_transcripts'],
      )!,
      cleanCompletedPayloads: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}clean_completed_payloads'],
      )!,
      diagnosticsRetentionDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diagnostics_retention_days'],
      )!,
      useAiClassification: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_ai_classification'],
      )!,
      academicIntegrationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}academic_integrations_enabled'],
      )!,
      classificationModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}classification_model'],
      )!,
      summaryModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_model'],
      )!,
      autoClassifyThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}auto_classify_threshold'],
      )!,
      reviewThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}review_threshold'],
      )!,
      summaryLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_language'],
      )!,
      summaryDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_detail'],
      )!,
      notionMetadataEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notion_metadata_enabled'],
      )!,
      notionSubjectsDataSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notion_subjects_data_source_id'],
      ),
      notionSummariesDataSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notion_summaries_data_source_id'],
      ),
      relayBaseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relay_base_url'],
      ),
    );
  }

  @override
  $SettingsRecordsTable createAlias(String alias) {
    return $SettingsRecordsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final int id;
  final String displayName;
  final bool setupComplete;
  final bool automaticSync;
  final bool launchWithWindows;
  final bool syncOnLaunch;
  final bool backgroundMobileSync;
  final bool notificationsEnabled;
  final int pollingMinutes;
  final int overlapHours;
  final int workerCount;
  final bool keepTranscripts;
  final bool cleanCompletedPayloads;
  final int diagnosticsRetentionDays;
  final bool useAiClassification;
  final bool academicIntegrationsEnabled;
  final String classificationModel;
  final String summaryModel;
  final double autoClassifyThreshold;
  final double reviewThreshold;
  final String summaryLanguage;
  final String summaryDetail;
  final bool notionMetadataEnabled;
  final String? notionSubjectsDataSourceId;
  final String? notionSummariesDataSourceId;
  final String? relayBaseUrl;
  const SettingsRow({
    required this.id,
    required this.displayName,
    required this.setupComplete,
    required this.automaticSync,
    required this.launchWithWindows,
    required this.syncOnLaunch,
    required this.backgroundMobileSync,
    required this.notificationsEnabled,
    required this.pollingMinutes,
    required this.overlapHours,
    required this.workerCount,
    required this.keepTranscripts,
    required this.cleanCompletedPayloads,
    required this.diagnosticsRetentionDays,
    required this.useAiClassification,
    required this.academicIntegrationsEnabled,
    required this.classificationModel,
    required this.summaryModel,
    required this.autoClassifyThreshold,
    required this.reviewThreshold,
    required this.summaryLanguage,
    required this.summaryDetail,
    required this.notionMetadataEnabled,
    this.notionSubjectsDataSourceId,
    this.notionSummariesDataSourceId,
    this.relayBaseUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['display_name'] = Variable<String>(displayName);
    map['setup_complete'] = Variable<bool>(setupComplete);
    map['automatic_sync'] = Variable<bool>(automaticSync);
    map['launch_with_windows'] = Variable<bool>(launchWithWindows);
    map['sync_on_launch'] = Variable<bool>(syncOnLaunch);
    map['background_mobile_sync'] = Variable<bool>(backgroundMobileSync);
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['polling_minutes'] = Variable<int>(pollingMinutes);
    map['overlap_hours'] = Variable<int>(overlapHours);
    map['worker_count'] = Variable<int>(workerCount);
    map['keep_transcripts'] = Variable<bool>(keepTranscripts);
    map['clean_completed_payloads'] = Variable<bool>(cleanCompletedPayloads);
    map['diagnostics_retention_days'] = Variable<int>(diagnosticsRetentionDays);
    map['use_ai_classification'] = Variable<bool>(useAiClassification);
    map['academic_integrations_enabled'] = Variable<bool>(
      academicIntegrationsEnabled,
    );
    map['classification_model'] = Variable<String>(classificationModel);
    map['summary_model'] = Variable<String>(summaryModel);
    map['auto_classify_threshold'] = Variable<double>(autoClassifyThreshold);
    map['review_threshold'] = Variable<double>(reviewThreshold);
    map['summary_language'] = Variable<String>(summaryLanguage);
    map['summary_detail'] = Variable<String>(summaryDetail);
    map['notion_metadata_enabled'] = Variable<bool>(notionMetadataEnabled);
    if (!nullToAbsent || notionSubjectsDataSourceId != null) {
      map['notion_subjects_data_source_id'] = Variable<String>(
        notionSubjectsDataSourceId,
      );
    }
    if (!nullToAbsent || notionSummariesDataSourceId != null) {
      map['notion_summaries_data_source_id'] = Variable<String>(
        notionSummariesDataSourceId,
      );
    }
    if (!nullToAbsent || relayBaseUrl != null) {
      map['relay_base_url'] = Variable<String>(relayBaseUrl);
    }
    return map;
  }

  SettingsRecordsCompanion toCompanion(bool nullToAbsent) {
    return SettingsRecordsCompanion(
      id: Value(id),
      displayName: Value(displayName),
      setupComplete: Value(setupComplete),
      automaticSync: Value(automaticSync),
      launchWithWindows: Value(launchWithWindows),
      syncOnLaunch: Value(syncOnLaunch),
      backgroundMobileSync: Value(backgroundMobileSync),
      notificationsEnabled: Value(notificationsEnabled),
      pollingMinutes: Value(pollingMinutes),
      overlapHours: Value(overlapHours),
      workerCount: Value(workerCount),
      keepTranscripts: Value(keepTranscripts),
      cleanCompletedPayloads: Value(cleanCompletedPayloads),
      diagnosticsRetentionDays: Value(diagnosticsRetentionDays),
      useAiClassification: Value(useAiClassification),
      academicIntegrationsEnabled: Value(academicIntegrationsEnabled),
      classificationModel: Value(classificationModel),
      summaryModel: Value(summaryModel),
      autoClassifyThreshold: Value(autoClassifyThreshold),
      reviewThreshold: Value(reviewThreshold),
      summaryLanguage: Value(summaryLanguage),
      summaryDetail: Value(summaryDetail),
      notionMetadataEnabled: Value(notionMetadataEnabled),
      notionSubjectsDataSourceId:
          notionSubjectsDataSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(notionSubjectsDataSourceId),
      notionSummariesDataSourceId:
          notionSummariesDataSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(notionSummariesDataSourceId),
      relayBaseUrl: relayBaseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(relayBaseUrl),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      setupComplete: serializer.fromJson<bool>(json['setupComplete']),
      automaticSync: serializer.fromJson<bool>(json['automaticSync']),
      launchWithWindows: serializer.fromJson<bool>(json['launchWithWindows']),
      syncOnLaunch: serializer.fromJson<bool>(json['syncOnLaunch']),
      backgroundMobileSync: serializer.fromJson<bool>(
        json['backgroundMobileSync'],
      ),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      pollingMinutes: serializer.fromJson<int>(json['pollingMinutes']),
      overlapHours: serializer.fromJson<int>(json['overlapHours']),
      workerCount: serializer.fromJson<int>(json['workerCount']),
      keepTranscripts: serializer.fromJson<bool>(json['keepTranscripts']),
      cleanCompletedPayloads: serializer.fromJson<bool>(
        json['cleanCompletedPayloads'],
      ),
      diagnosticsRetentionDays: serializer.fromJson<int>(
        json['diagnosticsRetentionDays'],
      ),
      useAiClassification: serializer.fromJson<bool>(
        json['useAiClassification'],
      ),
      academicIntegrationsEnabled: serializer.fromJson<bool>(
        json['academicIntegrationsEnabled'],
      ),
      classificationModel: serializer.fromJson<String>(
        json['classificationModel'],
      ),
      summaryModel: serializer.fromJson<String>(json['summaryModel']),
      autoClassifyThreshold: serializer.fromJson<double>(
        json['autoClassifyThreshold'],
      ),
      reviewThreshold: serializer.fromJson<double>(json['reviewThreshold']),
      summaryLanguage: serializer.fromJson<String>(json['summaryLanguage']),
      summaryDetail: serializer.fromJson<String>(json['summaryDetail']),
      notionMetadataEnabled: serializer.fromJson<bool>(
        json['notionMetadataEnabled'],
      ),
      notionSubjectsDataSourceId: serializer.fromJson<String?>(
        json['notionSubjectsDataSourceId'],
      ),
      notionSummariesDataSourceId: serializer.fromJson<String?>(
        json['notionSummariesDataSourceId'],
      ),
      relayBaseUrl: serializer.fromJson<String?>(json['relayBaseUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'displayName': serializer.toJson<String>(displayName),
      'setupComplete': serializer.toJson<bool>(setupComplete),
      'automaticSync': serializer.toJson<bool>(automaticSync),
      'launchWithWindows': serializer.toJson<bool>(launchWithWindows),
      'syncOnLaunch': serializer.toJson<bool>(syncOnLaunch),
      'backgroundMobileSync': serializer.toJson<bool>(backgroundMobileSync),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'pollingMinutes': serializer.toJson<int>(pollingMinutes),
      'overlapHours': serializer.toJson<int>(overlapHours),
      'workerCount': serializer.toJson<int>(workerCount),
      'keepTranscripts': serializer.toJson<bool>(keepTranscripts),
      'cleanCompletedPayloads': serializer.toJson<bool>(cleanCompletedPayloads),
      'diagnosticsRetentionDays': serializer.toJson<int>(
        diagnosticsRetentionDays,
      ),
      'useAiClassification': serializer.toJson<bool>(useAiClassification),
      'academicIntegrationsEnabled': serializer.toJson<bool>(
        academicIntegrationsEnabled,
      ),
      'classificationModel': serializer.toJson<String>(classificationModel),
      'summaryModel': serializer.toJson<String>(summaryModel),
      'autoClassifyThreshold': serializer.toJson<double>(autoClassifyThreshold),
      'reviewThreshold': serializer.toJson<double>(reviewThreshold),
      'summaryLanguage': serializer.toJson<String>(summaryLanguage),
      'summaryDetail': serializer.toJson<String>(summaryDetail),
      'notionMetadataEnabled': serializer.toJson<bool>(notionMetadataEnabled),
      'notionSubjectsDataSourceId': serializer.toJson<String?>(
        notionSubjectsDataSourceId,
      ),
      'notionSummariesDataSourceId': serializer.toJson<String?>(
        notionSummariesDataSourceId,
      ),
      'relayBaseUrl': serializer.toJson<String?>(relayBaseUrl),
    };
  }

  SettingsRow copyWith({
    int? id,
    String? displayName,
    bool? setupComplete,
    bool? automaticSync,
    bool? launchWithWindows,
    bool? syncOnLaunch,
    bool? backgroundMobileSync,
    bool? notificationsEnabled,
    int? pollingMinutes,
    int? overlapHours,
    int? workerCount,
    bool? keepTranscripts,
    bool? cleanCompletedPayloads,
    int? diagnosticsRetentionDays,
    bool? useAiClassification,
    bool? academicIntegrationsEnabled,
    String? classificationModel,
    String? summaryModel,
    double? autoClassifyThreshold,
    double? reviewThreshold,
    String? summaryLanguage,
    String? summaryDetail,
    bool? notionMetadataEnabled,
    Value<String?> notionSubjectsDataSourceId = const Value.absent(),
    Value<String?> notionSummariesDataSourceId = const Value.absent(),
    Value<String?> relayBaseUrl = const Value.absent(),
  }) => SettingsRow(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    setupComplete: setupComplete ?? this.setupComplete,
    automaticSync: automaticSync ?? this.automaticSync,
    launchWithWindows: launchWithWindows ?? this.launchWithWindows,
    syncOnLaunch: syncOnLaunch ?? this.syncOnLaunch,
    backgroundMobileSync: backgroundMobileSync ?? this.backgroundMobileSync,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    pollingMinutes: pollingMinutes ?? this.pollingMinutes,
    overlapHours: overlapHours ?? this.overlapHours,
    workerCount: workerCount ?? this.workerCount,
    keepTranscripts: keepTranscripts ?? this.keepTranscripts,
    cleanCompletedPayloads:
        cleanCompletedPayloads ?? this.cleanCompletedPayloads,
    diagnosticsRetentionDays:
        diagnosticsRetentionDays ?? this.diagnosticsRetentionDays,
    useAiClassification: useAiClassification ?? this.useAiClassification,
    academicIntegrationsEnabled:
        academicIntegrationsEnabled ?? this.academicIntegrationsEnabled,
    classificationModel: classificationModel ?? this.classificationModel,
    summaryModel: summaryModel ?? this.summaryModel,
    autoClassifyThreshold: autoClassifyThreshold ?? this.autoClassifyThreshold,
    reviewThreshold: reviewThreshold ?? this.reviewThreshold,
    summaryLanguage: summaryLanguage ?? this.summaryLanguage,
    summaryDetail: summaryDetail ?? this.summaryDetail,
    notionMetadataEnabled: notionMetadataEnabled ?? this.notionMetadataEnabled,
    notionSubjectsDataSourceId: notionSubjectsDataSourceId.present
        ? notionSubjectsDataSourceId.value
        : this.notionSubjectsDataSourceId,
    notionSummariesDataSourceId: notionSummariesDataSourceId.present
        ? notionSummariesDataSourceId.value
        : this.notionSummariesDataSourceId,
    relayBaseUrl: relayBaseUrl.present ? relayBaseUrl.value : this.relayBaseUrl,
  );
  SettingsRow copyWithCompanion(SettingsRecordsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      setupComplete: data.setupComplete.present
          ? data.setupComplete.value
          : this.setupComplete,
      automaticSync: data.automaticSync.present
          ? data.automaticSync.value
          : this.automaticSync,
      launchWithWindows: data.launchWithWindows.present
          ? data.launchWithWindows.value
          : this.launchWithWindows,
      syncOnLaunch: data.syncOnLaunch.present
          ? data.syncOnLaunch.value
          : this.syncOnLaunch,
      backgroundMobileSync: data.backgroundMobileSync.present
          ? data.backgroundMobileSync.value
          : this.backgroundMobileSync,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      pollingMinutes: data.pollingMinutes.present
          ? data.pollingMinutes.value
          : this.pollingMinutes,
      overlapHours: data.overlapHours.present
          ? data.overlapHours.value
          : this.overlapHours,
      workerCount: data.workerCount.present
          ? data.workerCount.value
          : this.workerCount,
      keepTranscripts: data.keepTranscripts.present
          ? data.keepTranscripts.value
          : this.keepTranscripts,
      cleanCompletedPayloads: data.cleanCompletedPayloads.present
          ? data.cleanCompletedPayloads.value
          : this.cleanCompletedPayloads,
      diagnosticsRetentionDays: data.diagnosticsRetentionDays.present
          ? data.diagnosticsRetentionDays.value
          : this.diagnosticsRetentionDays,
      useAiClassification: data.useAiClassification.present
          ? data.useAiClassification.value
          : this.useAiClassification,
      academicIntegrationsEnabled: data.academicIntegrationsEnabled.present
          ? data.academicIntegrationsEnabled.value
          : this.academicIntegrationsEnabled,
      classificationModel: data.classificationModel.present
          ? data.classificationModel.value
          : this.classificationModel,
      summaryModel: data.summaryModel.present
          ? data.summaryModel.value
          : this.summaryModel,
      autoClassifyThreshold: data.autoClassifyThreshold.present
          ? data.autoClassifyThreshold.value
          : this.autoClassifyThreshold,
      reviewThreshold: data.reviewThreshold.present
          ? data.reviewThreshold.value
          : this.reviewThreshold,
      summaryLanguage: data.summaryLanguage.present
          ? data.summaryLanguage.value
          : this.summaryLanguage,
      summaryDetail: data.summaryDetail.present
          ? data.summaryDetail.value
          : this.summaryDetail,
      notionMetadataEnabled: data.notionMetadataEnabled.present
          ? data.notionMetadataEnabled.value
          : this.notionMetadataEnabled,
      notionSubjectsDataSourceId: data.notionSubjectsDataSourceId.present
          ? data.notionSubjectsDataSourceId.value
          : this.notionSubjectsDataSourceId,
      notionSummariesDataSourceId: data.notionSummariesDataSourceId.present
          ? data.notionSummariesDataSourceId.value
          : this.notionSummariesDataSourceId,
      relayBaseUrl: data.relayBaseUrl.present
          ? data.relayBaseUrl.value
          : this.relayBaseUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('setupComplete: $setupComplete, ')
          ..write('automaticSync: $automaticSync, ')
          ..write('launchWithWindows: $launchWithWindows, ')
          ..write('syncOnLaunch: $syncOnLaunch, ')
          ..write('backgroundMobileSync: $backgroundMobileSync, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('pollingMinutes: $pollingMinutes, ')
          ..write('overlapHours: $overlapHours, ')
          ..write('workerCount: $workerCount, ')
          ..write('keepTranscripts: $keepTranscripts, ')
          ..write('cleanCompletedPayloads: $cleanCompletedPayloads, ')
          ..write('diagnosticsRetentionDays: $diagnosticsRetentionDays, ')
          ..write('useAiClassification: $useAiClassification, ')
          ..write('academicIntegrationsEnabled: $academicIntegrationsEnabled, ')
          ..write('classificationModel: $classificationModel, ')
          ..write('summaryModel: $summaryModel, ')
          ..write('autoClassifyThreshold: $autoClassifyThreshold, ')
          ..write('reviewThreshold: $reviewThreshold, ')
          ..write('summaryLanguage: $summaryLanguage, ')
          ..write('summaryDetail: $summaryDetail, ')
          ..write('notionMetadataEnabled: $notionMetadataEnabled, ')
          ..write('notionSubjectsDataSourceId: $notionSubjectsDataSourceId, ')
          ..write('notionSummariesDataSourceId: $notionSummariesDataSourceId, ')
          ..write('relayBaseUrl: $relayBaseUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    displayName,
    setupComplete,
    automaticSync,
    launchWithWindows,
    syncOnLaunch,
    backgroundMobileSync,
    notificationsEnabled,
    pollingMinutes,
    overlapHours,
    workerCount,
    keepTranscripts,
    cleanCompletedPayloads,
    diagnosticsRetentionDays,
    useAiClassification,
    academicIntegrationsEnabled,
    classificationModel,
    summaryModel,
    autoClassifyThreshold,
    reviewThreshold,
    summaryLanguage,
    summaryDetail,
    notionMetadataEnabled,
    notionSubjectsDataSourceId,
    notionSummariesDataSourceId,
    relayBaseUrl,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.setupComplete == this.setupComplete &&
          other.automaticSync == this.automaticSync &&
          other.launchWithWindows == this.launchWithWindows &&
          other.syncOnLaunch == this.syncOnLaunch &&
          other.backgroundMobileSync == this.backgroundMobileSync &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.pollingMinutes == this.pollingMinutes &&
          other.overlapHours == this.overlapHours &&
          other.workerCount == this.workerCount &&
          other.keepTranscripts == this.keepTranscripts &&
          other.cleanCompletedPayloads == this.cleanCompletedPayloads &&
          other.diagnosticsRetentionDays == this.diagnosticsRetentionDays &&
          other.useAiClassification == this.useAiClassification &&
          other.academicIntegrationsEnabled ==
              this.academicIntegrationsEnabled &&
          other.classificationModel == this.classificationModel &&
          other.summaryModel == this.summaryModel &&
          other.autoClassifyThreshold == this.autoClassifyThreshold &&
          other.reviewThreshold == this.reviewThreshold &&
          other.summaryLanguage == this.summaryLanguage &&
          other.summaryDetail == this.summaryDetail &&
          other.notionMetadataEnabled == this.notionMetadataEnabled &&
          other.notionSubjectsDataSourceId == this.notionSubjectsDataSourceId &&
          other.notionSummariesDataSourceId ==
              this.notionSummariesDataSourceId &&
          other.relayBaseUrl == this.relayBaseUrl);
}

class SettingsRecordsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<String> displayName;
  final Value<bool> setupComplete;
  final Value<bool> automaticSync;
  final Value<bool> launchWithWindows;
  final Value<bool> syncOnLaunch;
  final Value<bool> backgroundMobileSync;
  final Value<bool> notificationsEnabled;
  final Value<int> pollingMinutes;
  final Value<int> overlapHours;
  final Value<int> workerCount;
  final Value<bool> keepTranscripts;
  final Value<bool> cleanCompletedPayloads;
  final Value<int> diagnosticsRetentionDays;
  final Value<bool> useAiClassification;
  final Value<bool> academicIntegrationsEnabled;
  final Value<String> classificationModel;
  final Value<String> summaryModel;
  final Value<double> autoClassifyThreshold;
  final Value<double> reviewThreshold;
  final Value<String> summaryLanguage;
  final Value<String> summaryDetail;
  final Value<bool> notionMetadataEnabled;
  final Value<String?> notionSubjectsDataSourceId;
  final Value<String?> notionSummariesDataSourceId;
  final Value<String?> relayBaseUrl;
  const SettingsRecordsCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.setupComplete = const Value.absent(),
    this.automaticSync = const Value.absent(),
    this.launchWithWindows = const Value.absent(),
    this.syncOnLaunch = const Value.absent(),
    this.backgroundMobileSync = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.pollingMinutes = const Value.absent(),
    this.overlapHours = const Value.absent(),
    this.workerCount = const Value.absent(),
    this.keepTranscripts = const Value.absent(),
    this.cleanCompletedPayloads = const Value.absent(),
    this.diagnosticsRetentionDays = const Value.absent(),
    this.useAiClassification = const Value.absent(),
    this.academicIntegrationsEnabled = const Value.absent(),
    this.classificationModel = const Value.absent(),
    this.summaryModel = const Value.absent(),
    this.autoClassifyThreshold = const Value.absent(),
    this.reviewThreshold = const Value.absent(),
    this.summaryLanguage = const Value.absent(),
    this.summaryDetail = const Value.absent(),
    this.notionMetadataEnabled = const Value.absent(),
    this.notionSubjectsDataSourceId = const Value.absent(),
    this.notionSummariesDataSourceId = const Value.absent(),
    this.relayBaseUrl = const Value.absent(),
  });
  SettingsRecordsCompanion.insert({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    required bool setupComplete,
    required bool automaticSync,
    required bool launchWithWindows,
    required bool syncOnLaunch,
    required bool backgroundMobileSync,
    this.notificationsEnabled = const Value.absent(),
    required int pollingMinutes,
    required int overlapHours,
    required int workerCount,
    required bool keepTranscripts,
    required bool cleanCompletedPayloads,
    required int diagnosticsRetentionDays,
    this.useAiClassification = const Value.absent(),
    this.academicIntegrationsEnabled = const Value.absent(),
    required String classificationModel,
    required String summaryModel,
    required double autoClassifyThreshold,
    required double reviewThreshold,
    required String summaryLanguage,
    required String summaryDetail,
    required bool notionMetadataEnabled,
    this.notionSubjectsDataSourceId = const Value.absent(),
    this.notionSummariesDataSourceId = const Value.absent(),
    this.relayBaseUrl = const Value.absent(),
  }) : setupComplete = Value(setupComplete),
       automaticSync = Value(automaticSync),
       launchWithWindows = Value(launchWithWindows),
       syncOnLaunch = Value(syncOnLaunch),
       backgroundMobileSync = Value(backgroundMobileSync),
       pollingMinutes = Value(pollingMinutes),
       overlapHours = Value(overlapHours),
       workerCount = Value(workerCount),
       keepTranscripts = Value(keepTranscripts),
       cleanCompletedPayloads = Value(cleanCompletedPayloads),
       diagnosticsRetentionDays = Value(diagnosticsRetentionDays),
       classificationModel = Value(classificationModel),
       summaryModel = Value(summaryModel),
       autoClassifyThreshold = Value(autoClassifyThreshold),
       reviewThreshold = Value(reviewThreshold),
       summaryLanguage = Value(summaryLanguage),
       summaryDetail = Value(summaryDetail),
       notionMetadataEnabled = Value(notionMetadataEnabled);
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<String>? displayName,
    Expression<bool>? setupComplete,
    Expression<bool>? automaticSync,
    Expression<bool>? launchWithWindows,
    Expression<bool>? syncOnLaunch,
    Expression<bool>? backgroundMobileSync,
    Expression<bool>? notificationsEnabled,
    Expression<int>? pollingMinutes,
    Expression<int>? overlapHours,
    Expression<int>? workerCount,
    Expression<bool>? keepTranscripts,
    Expression<bool>? cleanCompletedPayloads,
    Expression<int>? diagnosticsRetentionDays,
    Expression<bool>? useAiClassification,
    Expression<bool>? academicIntegrationsEnabled,
    Expression<String>? classificationModel,
    Expression<String>? summaryModel,
    Expression<double>? autoClassifyThreshold,
    Expression<double>? reviewThreshold,
    Expression<String>? summaryLanguage,
    Expression<String>? summaryDetail,
    Expression<bool>? notionMetadataEnabled,
    Expression<String>? notionSubjectsDataSourceId,
    Expression<String>? notionSummariesDataSourceId,
    Expression<String>? relayBaseUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (setupComplete != null) 'setup_complete': setupComplete,
      if (automaticSync != null) 'automatic_sync': automaticSync,
      if (launchWithWindows != null) 'launch_with_windows': launchWithWindows,
      if (syncOnLaunch != null) 'sync_on_launch': syncOnLaunch,
      if (backgroundMobileSync != null)
        'background_mobile_sync': backgroundMobileSync,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (pollingMinutes != null) 'polling_minutes': pollingMinutes,
      if (overlapHours != null) 'overlap_hours': overlapHours,
      if (workerCount != null) 'worker_count': workerCount,
      if (keepTranscripts != null) 'keep_transcripts': keepTranscripts,
      if (cleanCompletedPayloads != null)
        'clean_completed_payloads': cleanCompletedPayloads,
      if (diagnosticsRetentionDays != null)
        'diagnostics_retention_days': diagnosticsRetentionDays,
      if (useAiClassification != null)
        'use_ai_classification': useAiClassification,
      if (academicIntegrationsEnabled != null)
        'academic_integrations_enabled': academicIntegrationsEnabled,
      if (classificationModel != null)
        'classification_model': classificationModel,
      if (summaryModel != null) 'summary_model': summaryModel,
      if (autoClassifyThreshold != null)
        'auto_classify_threshold': autoClassifyThreshold,
      if (reviewThreshold != null) 'review_threshold': reviewThreshold,
      if (summaryLanguage != null) 'summary_language': summaryLanguage,
      if (summaryDetail != null) 'summary_detail': summaryDetail,
      if (notionMetadataEnabled != null)
        'notion_metadata_enabled': notionMetadataEnabled,
      if (notionSubjectsDataSourceId != null)
        'notion_subjects_data_source_id': notionSubjectsDataSourceId,
      if (notionSummariesDataSourceId != null)
        'notion_summaries_data_source_id': notionSummariesDataSourceId,
      if (relayBaseUrl != null) 'relay_base_url': relayBaseUrl,
    });
  }

  SettingsRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? displayName,
    Value<bool>? setupComplete,
    Value<bool>? automaticSync,
    Value<bool>? launchWithWindows,
    Value<bool>? syncOnLaunch,
    Value<bool>? backgroundMobileSync,
    Value<bool>? notificationsEnabled,
    Value<int>? pollingMinutes,
    Value<int>? overlapHours,
    Value<int>? workerCount,
    Value<bool>? keepTranscripts,
    Value<bool>? cleanCompletedPayloads,
    Value<int>? diagnosticsRetentionDays,
    Value<bool>? useAiClassification,
    Value<bool>? academicIntegrationsEnabled,
    Value<String>? classificationModel,
    Value<String>? summaryModel,
    Value<double>? autoClassifyThreshold,
    Value<double>? reviewThreshold,
    Value<String>? summaryLanguage,
    Value<String>? summaryDetail,
    Value<bool>? notionMetadataEnabled,
    Value<String?>? notionSubjectsDataSourceId,
    Value<String?>? notionSummariesDataSourceId,
    Value<String?>? relayBaseUrl,
  }) {
    return SettingsRecordsCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      setupComplete: setupComplete ?? this.setupComplete,
      automaticSync: automaticSync ?? this.automaticSync,
      launchWithWindows: launchWithWindows ?? this.launchWithWindows,
      syncOnLaunch: syncOnLaunch ?? this.syncOnLaunch,
      backgroundMobileSync: backgroundMobileSync ?? this.backgroundMobileSync,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      pollingMinutes: pollingMinutes ?? this.pollingMinutes,
      overlapHours: overlapHours ?? this.overlapHours,
      workerCount: workerCount ?? this.workerCount,
      keepTranscripts: keepTranscripts ?? this.keepTranscripts,
      cleanCompletedPayloads:
          cleanCompletedPayloads ?? this.cleanCompletedPayloads,
      diagnosticsRetentionDays:
          diagnosticsRetentionDays ?? this.diagnosticsRetentionDays,
      useAiClassification: useAiClassification ?? this.useAiClassification,
      academicIntegrationsEnabled:
          academicIntegrationsEnabled ?? this.academicIntegrationsEnabled,
      classificationModel: classificationModel ?? this.classificationModel,
      summaryModel: summaryModel ?? this.summaryModel,
      autoClassifyThreshold:
          autoClassifyThreshold ?? this.autoClassifyThreshold,
      reviewThreshold: reviewThreshold ?? this.reviewThreshold,
      summaryLanguage: summaryLanguage ?? this.summaryLanguage,
      summaryDetail: summaryDetail ?? this.summaryDetail,
      notionMetadataEnabled:
          notionMetadataEnabled ?? this.notionMetadataEnabled,
      notionSubjectsDataSourceId:
          notionSubjectsDataSourceId ?? this.notionSubjectsDataSourceId,
      notionSummariesDataSourceId:
          notionSummariesDataSourceId ?? this.notionSummariesDataSourceId,
      relayBaseUrl: relayBaseUrl ?? this.relayBaseUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (setupComplete.present) {
      map['setup_complete'] = Variable<bool>(setupComplete.value);
    }
    if (automaticSync.present) {
      map['automatic_sync'] = Variable<bool>(automaticSync.value);
    }
    if (launchWithWindows.present) {
      map['launch_with_windows'] = Variable<bool>(launchWithWindows.value);
    }
    if (syncOnLaunch.present) {
      map['sync_on_launch'] = Variable<bool>(syncOnLaunch.value);
    }
    if (backgroundMobileSync.present) {
      map['background_mobile_sync'] = Variable<bool>(
        backgroundMobileSync.value,
      );
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (pollingMinutes.present) {
      map['polling_minutes'] = Variable<int>(pollingMinutes.value);
    }
    if (overlapHours.present) {
      map['overlap_hours'] = Variable<int>(overlapHours.value);
    }
    if (workerCount.present) {
      map['worker_count'] = Variable<int>(workerCount.value);
    }
    if (keepTranscripts.present) {
      map['keep_transcripts'] = Variable<bool>(keepTranscripts.value);
    }
    if (cleanCompletedPayloads.present) {
      map['clean_completed_payloads'] = Variable<bool>(
        cleanCompletedPayloads.value,
      );
    }
    if (diagnosticsRetentionDays.present) {
      map['diagnostics_retention_days'] = Variable<int>(
        diagnosticsRetentionDays.value,
      );
    }
    if (useAiClassification.present) {
      map['use_ai_classification'] = Variable<bool>(useAiClassification.value);
    }
    if (academicIntegrationsEnabled.present) {
      map['academic_integrations_enabled'] = Variable<bool>(
        academicIntegrationsEnabled.value,
      );
    }
    if (classificationModel.present) {
      map['classification_model'] = Variable<String>(classificationModel.value);
    }
    if (summaryModel.present) {
      map['summary_model'] = Variable<String>(summaryModel.value);
    }
    if (autoClassifyThreshold.present) {
      map['auto_classify_threshold'] = Variable<double>(
        autoClassifyThreshold.value,
      );
    }
    if (reviewThreshold.present) {
      map['review_threshold'] = Variable<double>(reviewThreshold.value);
    }
    if (summaryLanguage.present) {
      map['summary_language'] = Variable<String>(summaryLanguage.value);
    }
    if (summaryDetail.present) {
      map['summary_detail'] = Variable<String>(summaryDetail.value);
    }
    if (notionMetadataEnabled.present) {
      map['notion_metadata_enabled'] = Variable<bool>(
        notionMetadataEnabled.value,
      );
    }
    if (notionSubjectsDataSourceId.present) {
      map['notion_subjects_data_source_id'] = Variable<String>(
        notionSubjectsDataSourceId.value,
      );
    }
    if (notionSummariesDataSourceId.present) {
      map['notion_summaries_data_source_id'] = Variable<String>(
        notionSummariesDataSourceId.value,
      );
    }
    if (relayBaseUrl.present) {
      map['relay_base_url'] = Variable<String>(relayBaseUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRecordsCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('setupComplete: $setupComplete, ')
          ..write('automaticSync: $automaticSync, ')
          ..write('launchWithWindows: $launchWithWindows, ')
          ..write('syncOnLaunch: $syncOnLaunch, ')
          ..write('backgroundMobileSync: $backgroundMobileSync, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('pollingMinutes: $pollingMinutes, ')
          ..write('overlapHours: $overlapHours, ')
          ..write('workerCount: $workerCount, ')
          ..write('keepTranscripts: $keepTranscripts, ')
          ..write('cleanCompletedPayloads: $cleanCompletedPayloads, ')
          ..write('diagnosticsRetentionDays: $diagnosticsRetentionDays, ')
          ..write('useAiClassification: $useAiClassification, ')
          ..write('academicIntegrationsEnabled: $academicIntegrationsEnabled, ')
          ..write('classificationModel: $classificationModel, ')
          ..write('summaryModel: $summaryModel, ')
          ..write('autoClassifyThreshold: $autoClassifyThreshold, ')
          ..write('reviewThreshold: $reviewThreshold, ')
          ..write('summaryLanguage: $summaryLanguage, ')
          ..write('summaryDetail: $summaryDetail, ')
          ..write('notionMetadataEnabled: $notionMetadataEnabled, ')
          ..write('notionSubjectsDataSourceId: $notionSubjectsDataSourceId, ')
          ..write('notionSummariesDataSourceId: $notionSummariesDataSourceId, ')
          ..write('relayBaseUrl: $relayBaseUrl')
          ..write(')'))
        .toString();
  }
}

class $ClassificationCorrectionsTable extends ClassificationCorrections
    with
        TableInfo<
          $ClassificationCorrectionsTable,
          ClassificationCorrectionRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassificationCorrectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titlePatternMeta = const VerificationMeta(
    'titlePattern',
  );
  @override
  late final GeneratedColumn<String> titlePattern = GeneratedColumn<String>(
    'title_pattern',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speakerHintMeta = const VerificationMeta(
    'speakerHint',
  );
  @override
  late final GeneratedColumn<String> speakerHint = GeneratedColumn<String>(
    'speaker_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeHintMeta = const VerificationMeta(
    'timeHint',
  );
  @override
  late final GeneratedColumn<String> timeHint = GeneratedColumn<String>(
    'time_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectNameMeta = const VerificationMeta(
    'subjectName',
  );
  @override
  late final GeneratedColumn<String> subjectName = GeneratedColumn<String>(
    'subject_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titlePattern,
    speakerHint,
    weekday,
    timeHint,
    subjectId,
    subjectName,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'classification_corrections';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassificationCorrectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title_pattern')) {
      context.handle(
        _titlePatternMeta,
        titlePattern.isAcceptableOrUnknown(
          data['title_pattern']!,
          _titlePatternMeta,
        ),
      );
    }
    if (data.containsKey('speaker_hint')) {
      context.handle(
        _speakerHintMeta,
        speakerHint.isAcceptableOrUnknown(
          data['speaker_hint']!,
          _speakerHintMeta,
        ),
      );
    }
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    }
    if (data.containsKey('time_hint')) {
      context.handle(
        _timeHintMeta,
        timeHint.isAcceptableOrUnknown(data['time_hint']!, _timeHintMeta),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('subject_name')) {
      context.handle(
        _subjectNameMeta,
        subjectName.isAcceptableOrUnknown(
          data['subject_name']!,
          _subjectNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClassificationCorrectionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassificationCorrectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      titlePattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_pattern'],
      ),
      speakerHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_hint'],
      ),
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      ),
      timeHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_hint'],
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      subjectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ClassificationCorrectionsTable createAlias(String alias) {
    return $ClassificationCorrectionsTable(attachedDatabase, alias);
  }
}

class ClassificationCorrectionRow extends DataClass
    implements Insertable<ClassificationCorrectionRow> {
  final int id;
  final String? titlePattern;
  final String? speakerHint;
  final int? weekday;
  final String? timeHint;
  final String subjectId;
  final String subjectName;
  final DateTime createdAt;
  const ClassificationCorrectionRow({
    required this.id,
    this.titlePattern,
    this.speakerHint,
    this.weekday,
    this.timeHint,
    required this.subjectId,
    required this.subjectName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || titlePattern != null) {
      map['title_pattern'] = Variable<String>(titlePattern);
    }
    if (!nullToAbsent || speakerHint != null) {
      map['speaker_hint'] = Variable<String>(speakerHint);
    }
    if (!nullToAbsent || weekday != null) {
      map['weekday'] = Variable<int>(weekday);
    }
    if (!nullToAbsent || timeHint != null) {
      map['time_hint'] = Variable<String>(timeHint);
    }
    map['subject_id'] = Variable<String>(subjectId);
    map['subject_name'] = Variable<String>(subjectName);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ClassificationCorrectionsCompanion toCompanion(bool nullToAbsent) {
    return ClassificationCorrectionsCompanion(
      id: Value(id),
      titlePattern: titlePattern == null && nullToAbsent
          ? const Value.absent()
          : Value(titlePattern),
      speakerHint: speakerHint == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerHint),
      weekday: weekday == null && nullToAbsent
          ? const Value.absent()
          : Value(weekday),
      timeHint: timeHint == null && nullToAbsent
          ? const Value.absent()
          : Value(timeHint),
      subjectId: Value(subjectId),
      subjectName: Value(subjectName),
      createdAt: Value(createdAt),
    );
  }

  factory ClassificationCorrectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassificationCorrectionRow(
      id: serializer.fromJson<int>(json['id']),
      titlePattern: serializer.fromJson<String?>(json['titlePattern']),
      speakerHint: serializer.fromJson<String?>(json['speakerHint']),
      weekday: serializer.fromJson<int?>(json['weekday']),
      timeHint: serializer.fromJson<String?>(json['timeHint']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      subjectName: serializer.fromJson<String>(json['subjectName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'titlePattern': serializer.toJson<String?>(titlePattern),
      'speakerHint': serializer.toJson<String?>(speakerHint),
      'weekday': serializer.toJson<int?>(weekday),
      'timeHint': serializer.toJson<String?>(timeHint),
      'subjectId': serializer.toJson<String>(subjectId),
      'subjectName': serializer.toJson<String>(subjectName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ClassificationCorrectionRow copyWith({
    int? id,
    Value<String?> titlePattern = const Value.absent(),
    Value<String?> speakerHint = const Value.absent(),
    Value<int?> weekday = const Value.absent(),
    Value<String?> timeHint = const Value.absent(),
    String? subjectId,
    String? subjectName,
    DateTime? createdAt,
  }) => ClassificationCorrectionRow(
    id: id ?? this.id,
    titlePattern: titlePattern.present ? titlePattern.value : this.titlePattern,
    speakerHint: speakerHint.present ? speakerHint.value : this.speakerHint,
    weekday: weekday.present ? weekday.value : this.weekday,
    timeHint: timeHint.present ? timeHint.value : this.timeHint,
    subjectId: subjectId ?? this.subjectId,
    subjectName: subjectName ?? this.subjectName,
    createdAt: createdAt ?? this.createdAt,
  );
  ClassificationCorrectionRow copyWithCompanion(
    ClassificationCorrectionsCompanion data,
  ) {
    return ClassificationCorrectionRow(
      id: data.id.present ? data.id.value : this.id,
      titlePattern: data.titlePattern.present
          ? data.titlePattern.value
          : this.titlePattern,
      speakerHint: data.speakerHint.present
          ? data.speakerHint.value
          : this.speakerHint,
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
      timeHint: data.timeHint.present ? data.timeHint.value : this.timeHint,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      subjectName: data.subjectName.present
          ? data.subjectName.value
          : this.subjectName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationCorrectionRow(')
          ..write('id: $id, ')
          ..write('titlePattern: $titlePattern, ')
          ..write('speakerHint: $speakerHint, ')
          ..write('weekday: $weekday, ')
          ..write('timeHint: $timeHint, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectName: $subjectName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    titlePattern,
    speakerHint,
    weekday,
    timeHint,
    subjectId,
    subjectName,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassificationCorrectionRow &&
          other.id == this.id &&
          other.titlePattern == this.titlePattern &&
          other.speakerHint == this.speakerHint &&
          other.weekday == this.weekday &&
          other.timeHint == this.timeHint &&
          other.subjectId == this.subjectId &&
          other.subjectName == this.subjectName &&
          other.createdAt == this.createdAt);
}

class ClassificationCorrectionsCompanion
    extends UpdateCompanion<ClassificationCorrectionRow> {
  final Value<int> id;
  final Value<String?> titlePattern;
  final Value<String?> speakerHint;
  final Value<int?> weekday;
  final Value<String?> timeHint;
  final Value<String> subjectId;
  final Value<String> subjectName;
  final Value<DateTime> createdAt;
  const ClassificationCorrectionsCompanion({
    this.id = const Value.absent(),
    this.titlePattern = const Value.absent(),
    this.speakerHint = const Value.absent(),
    this.weekday = const Value.absent(),
    this.timeHint = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ClassificationCorrectionsCompanion.insert({
    this.id = const Value.absent(),
    this.titlePattern = const Value.absent(),
    this.speakerHint = const Value.absent(),
    this.weekday = const Value.absent(),
    this.timeHint = const Value.absent(),
    required String subjectId,
    required String subjectName,
    required DateTime createdAt,
  }) : subjectId = Value(subjectId),
       subjectName = Value(subjectName),
       createdAt = Value(createdAt);
  static Insertable<ClassificationCorrectionRow> custom({
    Expression<int>? id,
    Expression<String>? titlePattern,
    Expression<String>? speakerHint,
    Expression<int>? weekday,
    Expression<String>? timeHint,
    Expression<String>? subjectId,
    Expression<String>? subjectName,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titlePattern != null) 'title_pattern': titlePattern,
      if (speakerHint != null) 'speaker_hint': speakerHint,
      if (weekday != null) 'weekday': weekday,
      if (timeHint != null) 'time_hint': timeHint,
      if (subjectId != null) 'subject_id': subjectId,
      if (subjectName != null) 'subject_name': subjectName,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ClassificationCorrectionsCompanion copyWith({
    Value<int>? id,
    Value<String?>? titlePattern,
    Value<String?>? speakerHint,
    Value<int?>? weekday,
    Value<String?>? timeHint,
    Value<String>? subjectId,
    Value<String>? subjectName,
    Value<DateTime>? createdAt,
  }) {
    return ClassificationCorrectionsCompanion(
      id: id ?? this.id,
      titlePattern: titlePattern ?? this.titlePattern,
      speakerHint: speakerHint ?? this.speakerHint,
      weekday: weekday ?? this.weekday,
      timeHint: timeHint ?? this.timeHint,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (titlePattern.present) {
      map['title_pattern'] = Variable<String>(titlePattern.value);
    }
    if (speakerHint.present) {
      map['speaker_hint'] = Variable<String>(speakerHint.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (timeHint.present) {
      map['time_hint'] = Variable<String>(timeHint.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (subjectName.present) {
      map['subject_name'] = Variable<String>(subjectName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationCorrectionsCompanion(')
          ..write('id: $id, ')
          ..write('titlePattern: $titlePattern, ')
          ..write('speakerHint: $speakerHint, ')
          ..write('weekday: $weekday, ')
          ..write('timeHint: $timeHint, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectName: $subjectName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AcademicCacheRecordsTable extends AcademicCacheRecords
    with TableInfo<$AcademicCacheRecordsTable, AcademicCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AcademicCacheRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordKeyMeta = const VerificationMeta(
    'recordKey',
  );
  @override
  late final GeneratedColumn<String> recordKey = GeneratedColumn<String>(
    'record_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startsAtMeta = const VerificationMeta(
    'startsAt',
  );
  @override
  late final GeneratedColumn<DateTime> startsAt = GeneratedColumn<DateTime>(
    'starts_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
    'ends_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedFieldsJsonMeta = const VerificationMeta(
    'changedFieldsJson',
  );
  @override
  late final GeneratedColumn<String> changedFieldsJson =
      GeneratedColumn<String>(
        'changed_fields_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _lastChangedAtMeta = const VerificationMeta(
    'lastChangedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastChangedAt =
      GeneratedColumn<DateTime>(
        'last_changed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    recordKey,
    source,
    kind,
    externalId,
    subjectId,
    title,
    startsAt,
    endsAt,
    payloadJson,
    fingerprint,
    changedFieldsJson,
    lastChangedAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'academic_cache_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<AcademicCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_key')) {
      context.handle(
        _recordKeyMeta,
        recordKey.isAcceptableOrUnknown(data['record_key']!, _recordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_recordKeyMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('starts_at')) {
      context.handle(
        _startsAtMeta,
        startsAt.isAcceptableOrUnknown(data['starts_at']!, _startsAtMeta),
      );
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('changed_fields_json')) {
      context.handle(
        _changedFieldsJsonMeta,
        changedFieldsJson.isAcceptableOrUnknown(
          data['changed_fields_json']!,
          _changedFieldsJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_changed_at')) {
      context.handle(
        _lastChangedAtMeta,
        lastChangedAt.isAcceptableOrUnknown(
          data['last_changed_at']!,
          _lastChangedAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordKey};
  @override
  AcademicCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AcademicCacheRow(
      recordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_key'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starts_at'],
      ),
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_at'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      changedFieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_fields_json'],
      )!,
      lastChangedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_changed_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $AcademicCacheRecordsTable createAlias(String alias) {
    return $AcademicCacheRecordsTable(attachedDatabase, alias);
  }
}

class AcademicCacheRow extends DataClass
    implements Insertable<AcademicCacheRow> {
  final String recordKey;
  final String source;
  final String kind;
  final String externalId;
  final String? subjectId;
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String payloadJson;
  final String fingerprint;
  final String changedFieldsJson;
  final DateTime? lastChangedAt;
  final DateTime syncedAt;
  const AcademicCacheRow({
    required this.recordKey,
    required this.source,
    required this.kind,
    required this.externalId,
    this.subjectId,
    required this.title,
    this.startsAt,
    this.endsAt,
    required this.payloadJson,
    required this.fingerprint,
    required this.changedFieldsJson,
    this.lastChangedAt,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_key'] = Variable<String>(recordKey);
    map['source'] = Variable<String>(source);
    map['kind'] = Variable<String>(kind);
    map['external_id'] = Variable<String>(externalId);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || startsAt != null) {
      map['starts_at'] = Variable<DateTime>(startsAt);
    }
    if (!nullToAbsent || endsAt != null) {
      map['ends_at'] = Variable<DateTime>(endsAt);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['changed_fields_json'] = Variable<String>(changedFieldsJson);
    if (!nullToAbsent || lastChangedAt != null) {
      map['last_changed_at'] = Variable<DateTime>(lastChangedAt);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  AcademicCacheRecordsCompanion toCompanion(bool nullToAbsent) {
    return AcademicCacheRecordsCompanion(
      recordKey: Value(recordKey),
      source: Value(source),
      kind: Value(kind),
      externalId: Value(externalId),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      title: Value(title),
      startsAt: startsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startsAt),
      endsAt: endsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endsAt),
      payloadJson: Value(payloadJson),
      fingerprint: Value(fingerprint),
      changedFieldsJson: Value(changedFieldsJson),
      lastChangedAt: lastChangedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastChangedAt),
      syncedAt: Value(syncedAt),
    );
  }

  factory AcademicCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AcademicCacheRow(
      recordKey: serializer.fromJson<String>(json['recordKey']),
      source: serializer.fromJson<String>(json['source']),
      kind: serializer.fromJson<String>(json['kind']),
      externalId: serializer.fromJson<String>(json['externalId']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      title: serializer.fromJson<String>(json['title']),
      startsAt: serializer.fromJson<DateTime?>(json['startsAt']),
      endsAt: serializer.fromJson<DateTime?>(json['endsAt']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      changedFieldsJson: serializer.fromJson<String>(json['changedFieldsJson']),
      lastChangedAt: serializer.fromJson<DateTime?>(json['lastChangedAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordKey': serializer.toJson<String>(recordKey),
      'source': serializer.toJson<String>(source),
      'kind': serializer.toJson<String>(kind),
      'externalId': serializer.toJson<String>(externalId),
      'subjectId': serializer.toJson<String?>(subjectId),
      'title': serializer.toJson<String>(title),
      'startsAt': serializer.toJson<DateTime?>(startsAt),
      'endsAt': serializer.toJson<DateTime?>(endsAt),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'changedFieldsJson': serializer.toJson<String>(changedFieldsJson),
      'lastChangedAt': serializer.toJson<DateTime?>(lastChangedAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  AcademicCacheRow copyWith({
    String? recordKey,
    String? source,
    String? kind,
    String? externalId,
    Value<String?> subjectId = const Value.absent(),
    String? title,
    Value<DateTime?> startsAt = const Value.absent(),
    Value<DateTime?> endsAt = const Value.absent(),
    String? payloadJson,
    String? fingerprint,
    String? changedFieldsJson,
    Value<DateTime?> lastChangedAt = const Value.absent(),
    DateTime? syncedAt,
  }) => AcademicCacheRow(
    recordKey: recordKey ?? this.recordKey,
    source: source ?? this.source,
    kind: kind ?? this.kind,
    externalId: externalId ?? this.externalId,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    title: title ?? this.title,
    startsAt: startsAt.present ? startsAt.value : this.startsAt,
    endsAt: endsAt.present ? endsAt.value : this.endsAt,
    payloadJson: payloadJson ?? this.payloadJson,
    fingerprint: fingerprint ?? this.fingerprint,
    changedFieldsJson: changedFieldsJson ?? this.changedFieldsJson,
    lastChangedAt: lastChangedAt.present
        ? lastChangedAt.value
        : this.lastChangedAt,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  AcademicCacheRow copyWithCompanion(AcademicCacheRecordsCompanion data) {
    return AcademicCacheRow(
      recordKey: data.recordKey.present ? data.recordKey.value : this.recordKey,
      source: data.source.present ? data.source.value : this.source,
      kind: data.kind.present ? data.kind.value : this.kind,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      title: data.title.present ? data.title.value : this.title,
      startsAt: data.startsAt.present ? data.startsAt.value : this.startsAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      changedFieldsJson: data.changedFieldsJson.present
          ? data.changedFieldsJson.value
          : this.changedFieldsJson,
      lastChangedAt: data.lastChangedAt.present
          ? data.lastChangedAt.value
          : this.lastChangedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AcademicCacheRow(')
          ..write('recordKey: $recordKey, ')
          ..write('source: $source, ')
          ..write('kind: $kind, ')
          ..write('externalId: $externalId, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('changedFieldsJson: $changedFieldsJson, ')
          ..write('lastChangedAt: $lastChangedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    recordKey,
    source,
    kind,
    externalId,
    subjectId,
    title,
    startsAt,
    endsAt,
    payloadJson,
    fingerprint,
    changedFieldsJson,
    lastChangedAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AcademicCacheRow &&
          other.recordKey == this.recordKey &&
          other.source == this.source &&
          other.kind == this.kind &&
          other.externalId == this.externalId &&
          other.subjectId == this.subjectId &&
          other.title == this.title &&
          other.startsAt == this.startsAt &&
          other.endsAt == this.endsAt &&
          other.payloadJson == this.payloadJson &&
          other.fingerprint == this.fingerprint &&
          other.changedFieldsJson == this.changedFieldsJson &&
          other.lastChangedAt == this.lastChangedAt &&
          other.syncedAt == this.syncedAt);
}

class AcademicCacheRecordsCompanion extends UpdateCompanion<AcademicCacheRow> {
  final Value<String> recordKey;
  final Value<String> source;
  final Value<String> kind;
  final Value<String> externalId;
  final Value<String?> subjectId;
  final Value<String> title;
  final Value<DateTime?> startsAt;
  final Value<DateTime?> endsAt;
  final Value<String> payloadJson;
  final Value<String> fingerprint;
  final Value<String> changedFieldsJson;
  final Value<DateTime?> lastChangedAt;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const AcademicCacheRecordsCompanion({
    this.recordKey = const Value.absent(),
    this.source = const Value.absent(),
    this.kind = const Value.absent(),
    this.externalId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.title = const Value.absent(),
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.changedFieldsJson = const Value.absent(),
    this.lastChangedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AcademicCacheRecordsCompanion.insert({
    required String recordKey,
    required String source,
    required String kind,
    required String externalId,
    this.subjectId = const Value.absent(),
    required String title,
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    required String payloadJson,
    required String fingerprint,
    this.changedFieldsJson = const Value.absent(),
    this.lastChangedAt = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : recordKey = Value(recordKey),
       source = Value(source),
       kind = Value(kind),
       externalId = Value(externalId),
       title = Value(title),
       payloadJson = Value(payloadJson),
       fingerprint = Value(fingerprint),
       syncedAt = Value(syncedAt);
  static Insertable<AcademicCacheRow> custom({
    Expression<String>? recordKey,
    Expression<String>? source,
    Expression<String>? kind,
    Expression<String>? externalId,
    Expression<String>? subjectId,
    Expression<String>? title,
    Expression<DateTime>? startsAt,
    Expression<DateTime>? endsAt,
    Expression<String>? payloadJson,
    Expression<String>? fingerprint,
    Expression<String>? changedFieldsJson,
    Expression<DateTime>? lastChangedAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordKey != null) 'record_key': recordKey,
      if (source != null) 'source': source,
      if (kind != null) 'kind': kind,
      if (externalId != null) 'external_id': externalId,
      if (subjectId != null) 'subject_id': subjectId,
      if (title != null) 'title': title,
      if (startsAt != null) 'starts_at': startsAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (changedFieldsJson != null) 'changed_fields_json': changedFieldsJson,
      if (lastChangedAt != null) 'last_changed_at': lastChangedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AcademicCacheRecordsCompanion copyWith({
    Value<String>? recordKey,
    Value<String>? source,
    Value<String>? kind,
    Value<String>? externalId,
    Value<String?>? subjectId,
    Value<String>? title,
    Value<DateTime?>? startsAt,
    Value<DateTime?>? endsAt,
    Value<String>? payloadJson,
    Value<String>? fingerprint,
    Value<String>? changedFieldsJson,
    Value<DateTime?>? lastChangedAt,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return AcademicCacheRecordsCompanion(
      recordKey: recordKey ?? this.recordKey,
      source: source ?? this.source,
      kind: kind ?? this.kind,
      externalId: externalId ?? this.externalId,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      payloadJson: payloadJson ?? this.payloadJson,
      fingerprint: fingerprint ?? this.fingerprint,
      changedFieldsJson: changedFieldsJson ?? this.changedFieldsJson,
      lastChangedAt: lastChangedAt ?? this.lastChangedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordKey.present) {
      map['record_key'] = Variable<String>(recordKey.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startsAt.present) {
      map['starts_at'] = Variable<DateTime>(startsAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (changedFieldsJson.present) {
      map['changed_fields_json'] = Variable<String>(changedFieldsJson.value);
    }
    if (lastChangedAt.present) {
      map['last_changed_at'] = Variable<DateTime>(lastChangedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AcademicCacheRecordsCompanion(')
          ..write('recordKey: $recordKey, ')
          ..write('source: $source, ')
          ..write('kind: $kind, ')
          ..write('externalId: $externalId, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('changedFieldsJson: $changedFieldsJson, ')
          ..write('lastChangedAt: $lastChangedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AcademicChangeRecordsTable extends AcademicChangeRecords
    with TableInfo<$AcademicChangeRecordsTable, AcademicChangeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AcademicChangeRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordKeyMeta = const VerificationMeta(
    'recordKey',
  );
  @override
  late final GeneratedColumn<String> recordKey = GeneratedColumn<String>(
    'record_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousPayloadJsonMeta =
      const VerificationMeta('previousPayloadJson');
  @override
  late final GeneratedColumn<String> previousPayloadJson =
      GeneratedColumn<String>(
        'previous_payload_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _changedFieldsJsonMeta = const VerificationMeta(
    'changedFieldsJson',
  );
  @override
  late final GeneratedColumn<String> changedFieldsJson =
      GeneratedColumn<String>(
        'changed_fields_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordKey,
    kind,
    previousPayloadJson,
    changedFieldsJson,
    changedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'academic_change_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<AcademicChangeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record_key')) {
      context.handle(
        _recordKeyMeta,
        recordKey.isAcceptableOrUnknown(data['record_key']!, _recordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_recordKeyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('previous_payload_json')) {
      context.handle(
        _previousPayloadJsonMeta,
        previousPayloadJson.isAcceptableOrUnknown(
          data['previous_payload_json']!,
          _previousPayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previousPayloadJsonMeta);
    }
    if (data.containsKey('changed_fields_json')) {
      context.handle(
        _changedFieldsJsonMeta,
        changedFieldsJson.isAcceptableOrUnknown(
          data['changed_fields_json']!,
          _changedFieldsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changedFieldsJsonMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AcademicChangeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AcademicChangeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_key'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      previousPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_payload_json'],
      )!,
      changedFieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_fields_json'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  $AcademicChangeRecordsTable createAlias(String alias) {
    return $AcademicChangeRecordsTable(attachedDatabase, alias);
  }
}

class AcademicChangeRow extends DataClass
    implements Insertable<AcademicChangeRow> {
  final int id;
  final String recordKey;
  final String kind;
  final String previousPayloadJson;
  final String changedFieldsJson;
  final DateTime changedAt;
  const AcademicChangeRow({
    required this.id,
    required this.recordKey,
    required this.kind,
    required this.previousPayloadJson,
    required this.changedFieldsJson,
    required this.changedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record_key'] = Variable<String>(recordKey);
    map['kind'] = Variable<String>(kind);
    map['previous_payload_json'] = Variable<String>(previousPayloadJson);
    map['changed_fields_json'] = Variable<String>(changedFieldsJson);
    map['changed_at'] = Variable<DateTime>(changedAt);
    return map;
  }

  AcademicChangeRecordsCompanion toCompanion(bool nullToAbsent) {
    return AcademicChangeRecordsCompanion(
      id: Value(id),
      recordKey: Value(recordKey),
      kind: Value(kind),
      previousPayloadJson: Value(previousPayloadJson),
      changedFieldsJson: Value(changedFieldsJson),
      changedAt: Value(changedAt),
    );
  }

  factory AcademicChangeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AcademicChangeRow(
      id: serializer.fromJson<int>(json['id']),
      recordKey: serializer.fromJson<String>(json['recordKey']),
      kind: serializer.fromJson<String>(json['kind']),
      previousPayloadJson: serializer.fromJson<String>(
        json['previousPayloadJson'],
      ),
      changedFieldsJson: serializer.fromJson<String>(json['changedFieldsJson']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordKey': serializer.toJson<String>(recordKey),
      'kind': serializer.toJson<String>(kind),
      'previousPayloadJson': serializer.toJson<String>(previousPayloadJson),
      'changedFieldsJson': serializer.toJson<String>(changedFieldsJson),
      'changedAt': serializer.toJson<DateTime>(changedAt),
    };
  }

  AcademicChangeRow copyWith({
    int? id,
    String? recordKey,
    String? kind,
    String? previousPayloadJson,
    String? changedFieldsJson,
    DateTime? changedAt,
  }) => AcademicChangeRow(
    id: id ?? this.id,
    recordKey: recordKey ?? this.recordKey,
    kind: kind ?? this.kind,
    previousPayloadJson: previousPayloadJson ?? this.previousPayloadJson,
    changedFieldsJson: changedFieldsJson ?? this.changedFieldsJson,
    changedAt: changedAt ?? this.changedAt,
  );
  AcademicChangeRow copyWithCompanion(AcademicChangeRecordsCompanion data) {
    return AcademicChangeRow(
      id: data.id.present ? data.id.value : this.id,
      recordKey: data.recordKey.present ? data.recordKey.value : this.recordKey,
      kind: data.kind.present ? data.kind.value : this.kind,
      previousPayloadJson: data.previousPayloadJson.present
          ? data.previousPayloadJson.value
          : this.previousPayloadJson,
      changedFieldsJson: data.changedFieldsJson.present
          ? data.changedFieldsJson.value
          : this.changedFieldsJson,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AcademicChangeRow(')
          ..write('id: $id, ')
          ..write('recordKey: $recordKey, ')
          ..write('kind: $kind, ')
          ..write('previousPayloadJson: $previousPayloadJson, ')
          ..write('changedFieldsJson: $changedFieldsJson, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordKey,
    kind,
    previousPayloadJson,
    changedFieldsJson,
    changedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AcademicChangeRow &&
          other.id == this.id &&
          other.recordKey == this.recordKey &&
          other.kind == this.kind &&
          other.previousPayloadJson == this.previousPayloadJson &&
          other.changedFieldsJson == this.changedFieldsJson &&
          other.changedAt == this.changedAt);
}

class AcademicChangeRecordsCompanion
    extends UpdateCompanion<AcademicChangeRow> {
  final Value<int> id;
  final Value<String> recordKey;
  final Value<String> kind;
  final Value<String> previousPayloadJson;
  final Value<String> changedFieldsJson;
  final Value<DateTime> changedAt;
  const AcademicChangeRecordsCompanion({
    this.id = const Value.absent(),
    this.recordKey = const Value.absent(),
    this.kind = const Value.absent(),
    this.previousPayloadJson = const Value.absent(),
    this.changedFieldsJson = const Value.absent(),
    this.changedAt = const Value.absent(),
  });
  AcademicChangeRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String recordKey,
    required String kind,
    required String previousPayloadJson,
    required String changedFieldsJson,
    required DateTime changedAt,
  }) : recordKey = Value(recordKey),
       kind = Value(kind),
       previousPayloadJson = Value(previousPayloadJson),
       changedFieldsJson = Value(changedFieldsJson),
       changedAt = Value(changedAt);
  static Insertable<AcademicChangeRow> custom({
    Expression<int>? id,
    Expression<String>? recordKey,
    Expression<String>? kind,
    Expression<String>? previousPayloadJson,
    Expression<String>? changedFieldsJson,
    Expression<DateTime>? changedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordKey != null) 'record_key': recordKey,
      if (kind != null) 'kind': kind,
      if (previousPayloadJson != null)
        'previous_payload_json': previousPayloadJson,
      if (changedFieldsJson != null) 'changed_fields_json': changedFieldsJson,
      if (changedAt != null) 'changed_at': changedAt,
    });
  }

  AcademicChangeRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? recordKey,
    Value<String>? kind,
    Value<String>? previousPayloadJson,
    Value<String>? changedFieldsJson,
    Value<DateTime>? changedAt,
  }) {
    return AcademicChangeRecordsCompanion(
      id: id ?? this.id,
      recordKey: recordKey ?? this.recordKey,
      kind: kind ?? this.kind,
      previousPayloadJson: previousPayloadJson ?? this.previousPayloadJson,
      changedFieldsJson: changedFieldsJson ?? this.changedFieldsJson,
      changedAt: changedAt ?? this.changedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordKey.present) {
      map['record_key'] = Variable<String>(recordKey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (previousPayloadJson.present) {
      map['previous_payload_json'] = Variable<String>(
        previousPayloadJson.value,
      );
    }
    if (changedFieldsJson.present) {
      map['changed_fields_json'] = Variable<String>(changedFieldsJson.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AcademicChangeRecordsCompanion(')
          ..write('id: $id, ')
          ..write('recordKey: $recordKey, ')
          ..write('kind: $kind, ')
          ..write('previousPayloadJson: $previousPayloadJson, ')
          ..write('changedFieldsJson: $changedFieldsJson, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$ClassSyncDatabase extends GeneratedDatabase {
  _$ClassSyncDatabase(QueryExecutor e) : super(e);
  $ClassSyncDatabaseManager get managers => $ClassSyncDatabaseManager(this);
  late final $CachedSubjectsTable cachedSubjects = $CachedSubjectsTable(this);
  late final $SyncJobsTable syncJobs = $SyncJobsTable(this);
  late final $JobEventsTable jobEvents = $JobEventsTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $SettingsRecordsTable settingsRecords = $SettingsRecordsTable(
    this,
  );
  late final $ClassificationCorrectionsTable classificationCorrections =
      $ClassificationCorrectionsTable(this);
  late final $AcademicCacheRecordsTable academicCacheRecords =
      $AcademicCacheRecordsTable(this);
  late final $AcademicChangeRecordsTable academicChangeRecords =
      $AcademicChangeRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedSubjects,
    syncJobs,
    jobEvents,
    syncCursors,
    settingsRecords,
    classificationCorrections,
    academicCacheRecords,
    academicChangeRecords,
  ];
}

typedef $$CachedSubjectsTableCreateCompanionBuilder =
    CachedSubjectsCompanion Function({
      required String notionId,
      required String name,
      required String year,
      required String semester,
      required String status,
      Value<String?> notionUrl,
      Value<String> aliasesJson,
      Value<String> professorsJson,
      Value<String> scheduleHintsJson,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedSubjectsTableUpdateCompanionBuilder =
    CachedSubjectsCompanion Function({
      Value<String> notionId,
      Value<String> name,
      Value<String> year,
      Value<String> semester,
      Value<String> status,
      Value<String?> notionUrl,
      Value<String> aliasesJson,
      Value<String> professorsJson,
      Value<String> scheduleHintsJson,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedSubjectsTableFilterComposer
    extends Composer<_$ClassSyncDatabase, $CachedSubjectsTable> {
  $$CachedSubjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get notionId => $composableBuilder(
    column: $table.notionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semester => $composableBuilder(
    column: $table.semester,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notionUrl => $composableBuilder(
    column: $table.notionUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get professorsJson => $composableBuilder(
    column: $table.professorsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleHintsJson => $composableBuilder(
    column: $table.scheduleHintsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedSubjectsTableOrderingComposer
    extends Composer<_$ClassSyncDatabase, $CachedSubjectsTable> {
  $$CachedSubjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get notionId => $composableBuilder(
    column: $table.notionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semester => $composableBuilder(
    column: $table.semester,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notionUrl => $composableBuilder(
    column: $table.notionUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get professorsJson => $composableBuilder(
    column: $table.professorsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleHintsJson => $composableBuilder(
    column: $table.scheduleHintsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedSubjectsTableAnnotationComposer
    extends Composer<_$ClassSyncDatabase, $CachedSubjectsTable> {
  $$CachedSubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get notionId =>
      $composableBuilder(column: $table.notionId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get semester =>
      $composableBuilder(column: $table.semester, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notionUrl =>
      $composableBuilder(column: $table.notionUrl, builder: (column) => column);

  GeneratedColumn<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get professorsJson => $composableBuilder(
    column: $table.professorsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduleHintsJson => $composableBuilder(
    column: $table.scheduleHintsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedSubjectsTableTableManager
    extends
        RootTableManager<
          _$ClassSyncDatabase,
          $CachedSubjectsTable,
          CachedSubjectRow,
          $$CachedSubjectsTableFilterComposer,
          $$CachedSubjectsTableOrderingComposer,
          $$CachedSubjectsTableAnnotationComposer,
          $$CachedSubjectsTableCreateCompanionBuilder,
          $$CachedSubjectsTableUpdateCompanionBuilder,
          (
            CachedSubjectRow,
            BaseReferences<
              _$ClassSyncDatabase,
              $CachedSubjectsTable,
              CachedSubjectRow
            >,
          ),
          CachedSubjectRow,
          PrefetchHooks Function()
        > {
  $$CachedSubjectsTableTableManager(
    _$ClassSyncDatabase db,
    $CachedSubjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> notionId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> year = const Value.absent(),
                Value<String> semester = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notionUrl = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<String> professorsJson = const Value.absent(),
                Value<String> scheduleHintsJson = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSubjectsCompanion(
                notionId: notionId,
                name: name,
                year: year,
                semester: semester,
                status: status,
                notionUrl: notionUrl,
                aliasesJson: aliasesJson,
                professorsJson: professorsJson,
                scheduleHintsJson: scheduleHintsJson,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String notionId,
                required String name,
                required String year,
                required String semester,
                required String status,
                Value<String?> notionUrl = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<String> professorsJson = const Value.absent(),
                Value<String> scheduleHintsJson = const Value.absent(),
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedSubjectsCompanion.insert(
                notionId: notionId,
                name: name,
                year: year,
                semester: semester,
                status: status,
                notionUrl: notionUrl,
                aliasesJson: aliasesJson,
                professorsJson: professorsJson,
                scheduleHintsJson: scheduleHintsJson,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedSubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClassSyncDatabase,
      $CachedSubjectsTable,
      CachedSubjectRow,
      $$CachedSubjectsTableFilterComposer,
      $$CachedSubjectsTableOrderingComposer,
      $$CachedSubjectsTableAnnotationComposer,
      $$CachedSubjectsTableCreateCompanionBuilder,
      $$CachedSubjectsTableUpdateCompanionBuilder,
      (
        CachedSubjectRow,
        BaseReferences<
          _$ClassSyncDatabase,
          $CachedSubjectsTable,
          CachedSubjectRow
        >,
      ),
      CachedSubjectRow,
      PrefetchHooks Function()
    >;
typedef $$SyncJobsTableCreateCompanionBuilder =
    SyncJobsCompanion Function({
      required String id,
      required String firefliesId,
      required String meetingTitle,
      required DateTime meetingDate,
      Value<String?> firefliesUrl,
      Value<String> status,
      Value<String> sourceType,
      Value<String?> subjectId,
      Value<String?> subjectName,
      Value<double?> classificationConfidence,
      Value<String?> classificationCandidatesJson,
      Value<String?> transcriptJson,
      Value<String?> summaryTitle,
      Value<String?> summaryJson,
      Value<String?> summaryPartialsJson,
      Value<String?> notionPageId,
      Value<String?> notionUrl,
      Value<String?> reprocessMode,
      Value<int> attemptCount,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastErrorType,
      Value<String?> lastErrorMessage,
      required DateTime discoveredAt,
      Value<DateTime?> startedAt,
      required DateTime updatedAt,
      Value<DateTime?> completedAt,
      Value<String?> leaseOwner,
      Value<DateTime?> leaseExpiresAt,
      Value<int> rowid,
    });
typedef $$SyncJobsTableUpdateCompanionBuilder =
    SyncJobsCompanion Function({
      Value<String> id,
      Value<String> firefliesId,
      Value<String> meetingTitle,
      Value<DateTime> meetingDate,
      Value<String?> firefliesUrl,
      Value<String> status,
      Value<String> sourceType,
      Value<String?> subjectId,
      Value<String?> subjectName,
      Value<double?> classificationConfidence,
      Value<String?> classificationCandidatesJson,
      Value<String?> transcriptJson,
      Value<String?> summaryTitle,
      Value<String?> summaryJson,
      Value<String?> summaryPartialsJson,
      Value<String?> notionPageId,
      Value<String?> notionUrl,
      Value<String?> reprocessMode,
      Value<int> attemptCount,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastErrorType,
      Value<String?> lastErrorMessage,
      Value<DateTime> discoveredAt,
      Value<DateTime?> startedAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<String?> leaseOwner,
      Value<DateTime?> leaseExpiresAt,
      Value<int> rowid,
    });

final class $$SyncJobsTableReferences
    extends BaseReferences<_$ClassSyncDatabase, $SyncJobsTable, SyncJobRow> {
  $$SyncJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$JobEventsTable, List<JobEventRow>>
  _jobEventsRefsTable(_$ClassSyncDatabase db) => MultiTypedResultKey.fromTable(
    db.jobEvents,
    aliasName: 'sync_jobs__id__job_events__job_id',
  );

  $$JobEventsTableProcessedTableManager get jobEventsRefs {
    final manager = $$JobEventsTableTableManager(
      $_db,
      $_db.jobEvents,
    ).filter((f) => f.jobId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_jobEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SyncJobsTableFilterComposer
    extends Composer<_$ClassSyncDatabase, $SyncJobsTable> {
  $$SyncJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firefliesId => $composableBuilder(
    column: $table.firefliesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meetingTitle => $composableBuilder(
    column: $table.meetingTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get meetingDate => $composableBuilder(
    column: $table.meetingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firefliesUrl => $composableBuilder(
    column: $table.firefliesUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get classificationConfidence => $composableBuilder(
    column: $table.classificationConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classificationCandidatesJson => $composableBuilder(
    column: $table.classificationCandidatesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryTitle => $composableBuilder(
    column: $table.summaryTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryPartialsJson => $composableBuilder(
    column: $table.summaryPartialsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notionPageId => $composableBuilder(
    column: $table.notionPageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notionUrl => $composableBuilder(
    column: $table.notionUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reprocessMode => $composableBuilder(
    column: $table.reprocessMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorType => $composableBuilder(
    column: $table.lastErrorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseExpiresAt => $composableBuilder(
    column: $table.leaseExpiresAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> jobEventsRefs(
    Expression<bool> Function($$JobEventsTableFilterComposer f) f,
  ) {
    final $$JobEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.jobEvents,
      getReferencedColumn: (t) => t.jobId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JobEventsTableFilterComposer(
            $db: $db,
            $table: $db.jobEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyncJobsTableOrderingComposer
    extends Composer<_$ClassSyncDatabase, $SyncJobsTable> {
  $$SyncJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firefliesId => $composableBuilder(
    column: $table.firefliesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meetingTitle => $composableBuilder(
    column: $table.meetingTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get meetingDate => $composableBuilder(
    column: $table.meetingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firefliesUrl => $composableBuilder(
    column: $table.firefliesUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get classificationConfidence => $composableBuilder(
    column: $table.classificationConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classificationCandidatesJson =>
      $composableBuilder(
        column: $table.classificationCandidatesJson,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryTitle => $composableBuilder(
    column: $table.summaryTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryPartialsJson => $composableBuilder(
    column: $table.summaryPartialsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notionPageId => $composableBuilder(
    column: $table.notionPageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notionUrl => $composableBuilder(
    column: $table.notionUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reprocessMode => $composableBuilder(
    column: $table.reprocessMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorType => $composableBuilder(
    column: $table.lastErrorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseExpiresAt => $composableBuilder(
    column: $table.leaseExpiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncJobsTableAnnotationComposer
    extends Composer<_$ClassSyncDatabase, $SyncJobsTable> {
  $$SyncJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get firefliesId => $composableBuilder(
    column: $table.firefliesId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get meetingTitle => $composableBuilder(
    column: $table.meetingTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get meetingDate => $composableBuilder(
    column: $table.meetingDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firefliesUrl => $composableBuilder(
    column: $table.firefliesUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get classificationConfidence => $composableBuilder(
    column: $table.classificationConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get classificationCandidatesJson =>
      $composableBuilder(
        column: $table.classificationCandidatesJson,
        builder: (column) => column,
      );

  GeneratedColumn<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryTitle => $composableBuilder(
    column: $table.summaryTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryPartialsJson => $composableBuilder(
    column: $table.summaryPartialsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notionPageId => $composableBuilder(
    column: $table.notionPageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notionUrl =>
      $composableBuilder(column: $table.notionUrl, builder: (column) => column);

  GeneratedColumn<String> get reprocessMode => $composableBuilder(
    column: $table.reprocessMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorType => $composableBuilder(
    column: $table.lastErrorType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leaseExpiresAt => $composableBuilder(
    column: $table.leaseExpiresAt,
    builder: (column) => column,
  );

  Expression<T> jobEventsRefs<T extends Object>(
    Expression<T> Function($$JobEventsTableAnnotationComposer a) f,
  ) {
    final $$JobEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.jobEvents,
      getReferencedColumn: (t) => t.jobId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JobEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.jobEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SyncJobsTableTableManager
    extends
        RootTableManager<
          _$ClassSyncDatabase,
          $SyncJobsTable,
          SyncJobRow,
          $$SyncJobsTableFilterComposer,
          $$SyncJobsTableOrderingComposer,
          $$SyncJobsTableAnnotationComposer,
          $$SyncJobsTableCreateCompanionBuilder,
          $$SyncJobsTableUpdateCompanionBuilder,
          (SyncJobRow, $$SyncJobsTableReferences),
          SyncJobRow,
          PrefetchHooks Function({bool jobEventsRefs})
        > {
  $$SyncJobsTableTableManager(_$ClassSyncDatabase db, $SyncJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> firefliesId = const Value.absent(),
                Value<String> meetingTitle = const Value.absent(),
                Value<DateTime> meetingDate = const Value.absent(),
                Value<String?> firefliesUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String?> subjectName = const Value.absent(),
                Value<double?> classificationConfidence = const Value.absent(),
                Value<String?> classificationCandidatesJson =
                    const Value.absent(),
                Value<String?> transcriptJson = const Value.absent(),
                Value<String?> summaryTitle = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String?> summaryPartialsJson = const Value.absent(),
                Value<String?> notionPageId = const Value.absent(),
                Value<String?> notionUrl = const Value.absent(),
                Value<String?> reprocessMode = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastErrorType = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                Value<DateTime> discoveredAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<DateTime?> leaseExpiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncJobsCompanion(
                id: id,
                firefliesId: firefliesId,
                meetingTitle: meetingTitle,
                meetingDate: meetingDate,
                firefliesUrl: firefliesUrl,
                status: status,
                sourceType: sourceType,
                subjectId: subjectId,
                subjectName: subjectName,
                classificationConfidence: classificationConfidence,
                classificationCandidatesJson: classificationCandidatesJson,
                transcriptJson: transcriptJson,
                summaryTitle: summaryTitle,
                summaryJson: summaryJson,
                summaryPartialsJson: summaryPartialsJson,
                notionPageId: notionPageId,
                notionUrl: notionUrl,
                reprocessMode: reprocessMode,
                attemptCount: attemptCount,
                nextRetryAt: nextRetryAt,
                lastErrorType: lastErrorType,
                lastErrorMessage: lastErrorMessage,
                discoveredAt: discoveredAt,
                startedAt: startedAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                leaseOwner: leaseOwner,
                leaseExpiresAt: leaseExpiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String firefliesId,
                required String meetingTitle,
                required DateTime meetingDate,
                Value<String?> firefliesUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String?> subjectName = const Value.absent(),
                Value<double?> classificationConfidence = const Value.absent(),
                Value<String?> classificationCandidatesJson =
                    const Value.absent(),
                Value<String?> transcriptJson = const Value.absent(),
                Value<String?> summaryTitle = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String?> summaryPartialsJson = const Value.absent(),
                Value<String?> notionPageId = const Value.absent(),
                Value<String?> notionUrl = const Value.absent(),
                Value<String?> reprocessMode = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastErrorType = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                required DateTime discoveredAt,
                Value<DateTime?> startedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<DateTime?> leaseExpiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncJobsCompanion.insert(
                id: id,
                firefliesId: firefliesId,
                meetingTitle: meetingTitle,
                meetingDate: meetingDate,
                firefliesUrl: firefliesUrl,
                status: status,
                sourceType: sourceType,
                subjectId: subjectId,
                subjectName: subjectName,
                classificationConfidence: classificationConfidence,
                classificationCandidatesJson: classificationCandidatesJson,
                transcriptJson: transcriptJson,
                summaryTitle: summaryTitle,
                summaryJson: summaryJson,
                summaryPartialsJson: summaryPartialsJson,
                notionPageId: notionPageId,
                notionUrl: notionUrl,
                reprocessMode: reprocessMode,
                attemptCount: attemptCount,
                nextRetryAt: nextRetryAt,
                lastErrorType: lastErrorType,
                lastErrorMessage: lastErrorMessage,
                discoveredAt: discoveredAt,
                startedAt: startedAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                leaseOwner: leaseOwner,
                leaseExpiresAt: leaseExpiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SyncJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({jobEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (jobEventsRefs) db.jobEvents],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (jobEventsRefs)
                    await $_getPrefetchedData<
                      SyncJobRow,
                      $SyncJobsTable,
                      JobEventRow
                    >(
                      currentTable: table,
                      referencedTable: $$SyncJobsTableReferences
                          ._jobEventsRefsTable(db),
                      managerFromTypedResult: (p0) => $$SyncJobsTableReferences(
                        db,
                        table,
                        p0,
                      ).jobEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.jobId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SyncJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClassSyncDatabase,
      $SyncJobsTable,
      SyncJobRow,
      $$SyncJobsTableFilterComposer,
      $$SyncJobsTableOrderingComposer,
      $$SyncJobsTableAnnotationComposer,
      $$SyncJobsTableCreateCompanionBuilder,
      $$SyncJobsTableUpdateCompanionBuilder,
      (SyncJobRow, $$SyncJobsTableReferences),
      SyncJobRow,
      PrefetchHooks Function({bool jobEventsRefs})
    >;
typedef $$JobEventsTableCreateCompanionBuilder =
    JobEventsCompanion Function({
      Value<int> id,
      required String jobId,
      required String stage,
      required String message,
      required DateTime createdAt,
    });
typedef $$JobEventsTableUpdateCompanionBuilder =
    JobEventsCompanion Function({
      Value<int> id,
      Value<String> jobId,
      Value<String> stage,
      Value<String> message,
      Value<DateTime> createdAt,
    });

final class $$JobEventsTableReferences
    extends BaseReferences<_$ClassSyncDatabase, $JobEventsTable, JobEventRow> {
  $$JobEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SyncJobsTable _jobIdTable(_$ClassSyncDatabase db) =>
      db.syncJobs.createAlias('job_events__job_id__sync_jobs__id');

  $$SyncJobsTableProcessedTableManager get jobId {
    final $_column = $_itemColumn<String>('job_id')!;

    final manager = $$SyncJobsTableTableManager(
      $_db,
      $_db.syncJobs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_jobIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$JobEventsTableFilterComposer
    extends Composer<_$ClassSyncDatabase, $JobEventsTable> {
  $$JobEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SyncJobsTableFilterComposer get jobId {
    final $$SyncJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jobId,
      referencedTable: $db.syncJobs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncJobsTableFilterComposer(
            $db: $db,
            $table: $db.syncJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JobEventsTableOrderingComposer
    extends Composer<_$ClassSyncDatabase, $JobEventsTable> {
  $$JobEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SyncJobsTableOrderingComposer get jobId {
    final $$SyncJobsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jobId,
      referencedTable: $db.syncJobs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncJobsTableOrderingComposer(
            $db: $db,
            $table: $db.syncJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JobEventsTableAnnotationComposer
    extends Composer<_$ClassSyncDatabase, $JobEventsTable> {
  $$JobEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SyncJobsTableAnnotationComposer get jobId {
    final $$SyncJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jobId,
      referencedTable: $db.syncJobs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.syncJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JobEventsTableTableManager
    extends
        RootTableManager<
          _$ClassSyncDatabase,
          $JobEventsTable,
          JobEventRow,
          $$JobEventsTableFilterComposer,
          $$JobEventsTableOrderingComposer,
          $$JobEventsTableAnnotationComposer,
          $$JobEventsTableCreateCompanionBuilder,
          $$JobEventsTableUpdateCompanionBuilder,
          (JobEventRow, $$JobEventsTableReferences),
          JobEventRow,
          PrefetchHooks Function({bool jobId})
        > {
  $$JobEventsTableTableManager(_$ClassSyncDatabase db, $JobEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JobEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JobEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JobEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> jobId = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => JobEventsCompanion(
                id: id,
                jobId: jobId,
                stage: stage,
                message: message,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String jobId,
                required String stage,
                required String message,
                required DateTime createdAt,
              }) => JobEventsCompanion.insert(
                id: id,
                jobId: jobId,
                stage: stage,
                message: message,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$JobEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({jobId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (jobId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.jobId,
                                referencedTable: $$JobEventsTableReferences
                                    ._jobIdTable(db),
                                referencedColumn: $$JobEventsTableReferences
                                    ._jobIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$JobEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClassSyncDatabase,
      $JobEventsTable,
      JobEventRow,
      $$JobEventsTableFilterComposer,
      $$JobEventsTableOrderingComposer,
      $$JobEventsTableAnnotationComposer,
      $$JobEventsTableCreateCompanionBuilder,
      $$JobEventsTableUpdateCompanionBuilder,
      (JobEventRow, $$JobEventsTableReferences),
      JobEventRow,
      PrefetchHooks Function({bool jobId})
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String source,
      required DateTime cursorAt,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> source,
      Value<DateTime> cursorAt,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$ClassSyncDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cursorAt => $composableBuilder(
    column: $table.cursorAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$ClassSyncDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cursorAt => $composableBuilder(
    column: $table.cursorAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$ClassSyncDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get cursorAt =>
      $composableBuilder(column: $table.cursorAt, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$ClassSyncDatabase,
          $SyncCursorsTable,
          SyncCursorRow,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursorRow,
            BaseReferences<
              _$ClassSyncDatabase,
              $SyncCursorsTable,
              SyncCursorRow
            >,
          ),
          SyncCursorRow,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(
    _$ClassSyncDatabase db,
    $SyncCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> source = const Value.absent(),
                Value<DateTime> cursorAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                source: source,
                cursorAt: cursorAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String source,
                required DateTime cursorAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                source: source,
                cursorAt: cursorAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClassSyncDatabase,
      $SyncCursorsTable,
      SyncCursorRow,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursorRow,
        BaseReferences<_$ClassSyncDatabase, $SyncCursorsTable, SyncCursorRow>,
      ),
      SyncCursorRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsRecordsTableCreateCompanionBuilder =
    SettingsRecordsCompanion Function({
      Value<int> id,
      Value<String> displayName,
      required bool setupComplete,
      required bool automaticSync,
      required bool launchWithWindows,
      required bool syncOnLaunch,
      required bool backgroundMobileSync,
      Value<bool> notificationsEnabled,
      required int pollingMinutes,
      required int overlapHours,
      required int workerCount,
      required bool keepTranscripts,
      required bool cleanCompletedPayloads,
      required int diagnosticsRetentionDays,
      Value<bool> useAiClassification,
      Value<bool> academicIntegrationsEnabled,
      required String classificationModel,
      required String summaryModel,
      required double autoClassifyThreshold,
      required double reviewThreshold,
      required String summaryLanguage,
      required String summaryDetail,
      required bool notionMetadataEnabled,
      Value<String?> notionSubjectsDataSourceId,
      Value<String?> notionSummariesDataSourceId,
      Value<String?> relayBaseUrl,
    });
typedef $$SettingsRecordsTableUpdateCompanionBuilder =
    SettingsRecordsCompanion Function({
      Value<int> id,
      Value<String> displayName,
      Value<bool> setupComplete,
      Value<bool> automaticSync,
      Value<bool> launchWithWindows,
      Value<bool> syncOnLaunch,
      Value<bool> backgroundMobileSync,
      Value<bool> notificationsEnabled,
      Value<int> pollingMinutes,
      Value<int> overlapHours,
      Value<int> workerCount,
      Value<bool> keepTranscripts,
      Value<bool> cleanCompletedPayloads,
      Value<int> diagnosticsRetentionDays,
      Value<bool> useAiClassification,
      Value<bool> academicIntegrationsEnabled,
      Value<String> classificationModel,
      Value<String> summaryModel,
      Value<double> autoClassifyThreshold,
      Value<double> reviewThreshold,
      Value<String> summaryLanguage,
      Value<String> summaryDetail,
      Value<bool> notionMetadataEnabled,
      Value<String?> notionSubjectsDataSourceId,
      Value<String?> notionSummariesDataSourceId,
      Value<String?> relayBaseUrl,
    });

class $$SettingsRecordsTableFilterComposer
    extends Composer<_$ClassSyncDatabase, $SettingsRecordsTable> {
  $$SettingsRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get setupComplete => $composableBuilder(
    column: $table.setupComplete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get automaticSync => $composableBuilder(
    column: $table.automaticSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get launchWithWindows => $composableBuilder(
    column: $table.launchWithWindows,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncOnLaunch => $composableBuilder(
    column: $table.syncOnLaunch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get backgroundMobileSync => $composableBuilder(
    column: $table.backgroundMobileSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pollingMinutes => $composableBuilder(
    column: $table.pollingMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overlapHours => $composableBuilder(
    column: $table.overlapHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workerCount => $composableBuilder(
    column: $table.workerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepTranscripts => $composableBuilder(
    column: $table.keepTranscripts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cleanCompletedPayloads => $composableBuilder(
    column: $table.cleanCompletedPayloads,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diagnosticsRetentionDays => $composableBuilder(
    column: $table.diagnosticsRetentionDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useAiClassification => $composableBuilder(
    column: $table.useAiClassification,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get academicIntegrationsEnabled => $composableBuilder(
    column: $table.academicIntegrationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classificationModel => $composableBuilder(
    column: $table.classificationModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryModel => $composableBuilder(
    column: $table.summaryModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get autoClassifyThreshold => $composableBuilder(
    column: $table.autoClassifyThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reviewThreshold => $composableBuilder(
    column: $table.reviewThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryLanguage => $composableBuilder(
    column: $table.summaryLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryDetail => $composableBuilder(
    column: $table.summaryDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notionMetadataEnabled => $composableBuilder(
    column: $table.notionMetadataEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notionSubjectsDataSourceId => $composableBuilder(
    column: $table.notionSubjectsDataSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notionSummariesDataSourceId => $composableBuilder(
    column: $table.notionSummariesDataSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relayBaseUrl => $composableBuilder(
    column: $table.relayBaseUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsRecordsTableOrderingComposer
    extends Composer<_$ClassSyncDatabase, $SettingsRecordsTable> {
  $$SettingsRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get setupComplete => $composableBuilder(
    column: $table.setupComplete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get automaticSync => $composableBuilder(
    column: $table.automaticSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get launchWithWindows => $composableBuilder(
    column: $table.launchWithWindows,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncOnLaunch => $composableBuilder(
    column: $table.syncOnLaunch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get backgroundMobileSync => $composableBuilder(
    column: $table.backgroundMobileSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pollingMinutes => $composableBuilder(
    column: $table.pollingMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overlapHours => $composableBuilder(
    column: $table.overlapHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workerCount => $composableBuilder(
    column: $table.workerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepTranscripts => $composableBuilder(
    column: $table.keepTranscripts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cleanCompletedPayloads => $composableBuilder(
    column: $table.cleanCompletedPayloads,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diagnosticsRetentionDays => $composableBuilder(
    column: $table.diagnosticsRetentionDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useAiClassification => $composableBuilder(
    column: $table.useAiClassification,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get academicIntegrationsEnabled => $composableBuilder(
    column: $table.academicIntegrationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classificationModel => $composableBuilder(
    column: $table.classificationModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryModel => $composableBuilder(
    column: $table.summaryModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get autoClassifyThreshold => $composableBuilder(
    column: $table.autoClassifyThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reviewThreshold => $composableBuilder(
    column: $table.reviewThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryLanguage => $composableBuilder(
    column: $table.summaryLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryDetail => $composableBuilder(
    column: $table.summaryDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notionMetadataEnabled => $composableBuilder(
    column: $table.notionMetadataEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notionSubjectsDataSourceId => $composableBuilder(
    column: $table.notionSubjectsDataSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notionSummariesDataSourceId => $composableBuilder(
    column: $table.notionSummariesDataSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relayBaseUrl => $composableBuilder(
    column: $table.relayBaseUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsRecordsTableAnnotationComposer
    extends Composer<_$ClassSyncDatabase, $SettingsRecordsTable> {
  $$SettingsRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get setupComplete => $composableBuilder(
    column: $table.setupComplete,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get automaticSync => $composableBuilder(
    column: $table.automaticSync,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get launchWithWindows => $composableBuilder(
    column: $table.launchWithWindows,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get syncOnLaunch => $composableBuilder(
    column: $table.syncOnLaunch,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get backgroundMobileSync => $composableBuilder(
    column: $table.backgroundMobileSync,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pollingMinutes => $composableBuilder(
    column: $table.pollingMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overlapHours => $composableBuilder(
    column: $table.overlapHours,
    builder: (column) => column,
  );

  GeneratedColumn<int> get workerCount => $composableBuilder(
    column: $table.workerCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get keepTranscripts => $composableBuilder(
    column: $table.keepTranscripts,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get cleanCompletedPayloads => $composableBuilder(
    column: $table.cleanCompletedPayloads,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diagnosticsRetentionDays => $composableBuilder(
    column: $table.diagnosticsRetentionDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useAiClassification => $composableBuilder(
    column: $table.useAiClassification,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get academicIntegrationsEnabled => $composableBuilder(
    column: $table.academicIntegrationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get classificationModel => $composableBuilder(
    column: $table.classificationModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryModel => $composableBuilder(
    column: $table.summaryModel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get autoClassifyThreshold => $composableBuilder(
    column: $table.autoClassifyThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<double> get reviewThreshold => $composableBuilder(
    column: $table.reviewThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryLanguage => $composableBuilder(
    column: $table.summaryLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryDetail => $composableBuilder(
    column: $table.summaryDetail,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notionMetadataEnabled => $composableBuilder(
    column: $table.notionMetadataEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notionSubjectsDataSourceId => $composableBuilder(
    column: $table.notionSubjectsDataSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notionSummariesDataSourceId => $composableBuilder(
    column: $table.notionSummariesDataSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relayBaseUrl => $composableBuilder(
    column: $table.relayBaseUrl,
    builder: (column) => column,
  );
}

class $$SettingsRecordsTableTableManager
    extends
        RootTableManager<
          _$ClassSyncDatabase,
          $SettingsRecordsTable,
          SettingsRow,
          $$SettingsRecordsTableFilterComposer,
          $$SettingsRecordsTableOrderingComposer,
          $$SettingsRecordsTableAnnotationComposer,
          $$SettingsRecordsTableCreateCompanionBuilder,
          $$SettingsRecordsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<
              _$ClassSyncDatabase,
              $SettingsRecordsTable,
              SettingsRow
            >,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsRecordsTableTableManager(
    _$ClassSyncDatabase db,
    $SettingsRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<bool> setupComplete = const Value.absent(),
                Value<bool> automaticSync = const Value.absent(),
                Value<bool> launchWithWindows = const Value.absent(),
                Value<bool> syncOnLaunch = const Value.absent(),
                Value<bool> backgroundMobileSync = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<int> pollingMinutes = const Value.absent(),
                Value<int> overlapHours = const Value.absent(),
                Value<int> workerCount = const Value.absent(),
                Value<bool> keepTranscripts = const Value.absent(),
                Value<bool> cleanCompletedPayloads = const Value.absent(),
                Value<int> diagnosticsRetentionDays = const Value.absent(),
                Value<bool> useAiClassification = const Value.absent(),
                Value<bool> academicIntegrationsEnabled = const Value.absent(),
                Value<String> classificationModel = const Value.absent(),
                Value<String> summaryModel = const Value.absent(),
                Value<double> autoClassifyThreshold = const Value.absent(),
                Value<double> reviewThreshold = const Value.absent(),
                Value<String> summaryLanguage = const Value.absent(),
                Value<String> summaryDetail = const Value.absent(),
                Value<bool> notionMetadataEnabled = const Value.absent(),
                Value<String?> notionSubjectsDataSourceId =
                    const Value.absent(),
                Value<String?> notionSummariesDataSourceId =
                    const Value.absent(),
                Value<String?> relayBaseUrl = const Value.absent(),
              }) => SettingsRecordsCompanion(
                id: id,
                displayName: displayName,
                setupComplete: setupComplete,
                automaticSync: automaticSync,
                launchWithWindows: launchWithWindows,
                syncOnLaunch: syncOnLaunch,
                backgroundMobileSync: backgroundMobileSync,
                notificationsEnabled: notificationsEnabled,
                pollingMinutes: pollingMinutes,
                overlapHours: overlapHours,
                workerCount: workerCount,
                keepTranscripts: keepTranscripts,
                cleanCompletedPayloads: cleanCompletedPayloads,
                diagnosticsRetentionDays: diagnosticsRetentionDays,
                useAiClassification: useAiClassification,
                academicIntegrationsEnabled: academicIntegrationsEnabled,
                classificationModel: classificationModel,
                summaryModel: summaryModel,
                autoClassifyThreshold: autoClassifyThreshold,
                reviewThreshold: reviewThreshold,
                summaryLanguage: summaryLanguage,
                summaryDetail: summaryDetail,
                notionMetadataEnabled: notionMetadataEnabled,
                notionSubjectsDataSourceId: notionSubjectsDataSourceId,
                notionSummariesDataSourceId: notionSummariesDataSourceId,
                relayBaseUrl: relayBaseUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                required bool setupComplete,
                required bool automaticSync,
                required bool launchWithWindows,
                required bool syncOnLaunch,
                required bool backgroundMobileSync,
                Value<bool> notificationsEnabled = const Value.absent(),
                required int pollingMinutes,
                required int overlapHours,
                required int workerCount,
                required bool keepTranscripts,
                required bool cleanCompletedPayloads,
                required int diagnosticsRetentionDays,
                Value<bool> useAiClassification = const Value.absent(),
                Value<bool> academicIntegrationsEnabled = const Value.absent(),
                required String classificationModel,
                required String summaryModel,
                required double autoClassifyThreshold,
                required double reviewThreshold,
                required String summaryLanguage,
                required String summaryDetail,
                required bool notionMetadataEnabled,
                Value<String?> notionSubjectsDataSourceId =
                    const Value.absent(),
                Value<String?> notionSummariesDataSourceId =
                    const Value.absent(),
                Value<String?> relayBaseUrl = const Value.absent(),
              }) => SettingsRecordsCompanion.insert(
                id: id,
                displayName: displayName,
                setupComplete: setupComplete,
                automaticSync: automaticSync,
                launchWithWindows: launchWithWindows,
                syncOnLaunch: syncOnLaunch,
                backgroundMobileSync: backgroundMobileSync,
                notificationsEnabled: notificationsEnabled,
                pollingMinutes: pollingMinutes,
                overlapHours: overlapHours,
                workerCount: workerCount,
                keepTranscripts: keepTranscripts,
                cleanCompletedPayloads: cleanCompletedPayloads,
                diagnosticsRetentionDays: diagnosticsRetentionDays,
                useAiClassification: useAiClassification,
                academicIntegrationsEnabled: academicIntegrationsEnabled,
                classificationModel: classificationModel,
                summaryModel: summaryModel,
                autoClassifyThreshold: autoClassifyThreshold,
                reviewThreshold: reviewThreshold,
                summaryLanguage: summaryLanguage,
                summaryDetail: summaryDetail,
                notionMetadataEnabled: notionMetadataEnabled,
                notionSubjectsDataSourceId: notionSubjectsDataSourceId,
                notionSummariesDataSourceId: notionSummariesDataSourceId,
                relayBaseUrl: relayBaseUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClassSyncDatabase,
      $SettingsRecordsTable,
      SettingsRow,
      $$SettingsRecordsTableFilterComposer,
      $$SettingsRecordsTableOrderingComposer,
      $$SettingsRecordsTableAnnotationComposer,
      $$SettingsRecordsTableCreateCompanionBuilder,
      $$SettingsRecordsTableUpdateCompanionBuilder,
      (
        SettingsRow,
        BaseReferences<_$ClassSyncDatabase, $SettingsRecordsTable, SettingsRow>,
      ),
      SettingsRow,
      PrefetchHooks Function()
    >;
typedef $$ClassificationCorrectionsTableCreateCompanionBuilder =
    ClassificationCorrectionsCompanion Function({
      Value<int> id,
      Value<String?> titlePattern,
      Value<String?> speakerHint,
      Value<int?> weekday,
      Value<String?> timeHint,
      required String subjectId,
      required String subjectName,
      required DateTime createdAt,
    });
typedef $$ClassificationCorrectionsTableUpdateCompanionBuilder =
    ClassificationCorrectionsCompanion Function({
      Value<int> id,
      Value<String?> titlePattern,
      Value<String?> speakerHint,
      Value<int?> weekday,
      Value<String?> timeHint,
      Value<String> subjectId,
      Value<String> subjectName,
      Value<DateTime> createdAt,
    });

class $$ClassificationCorrectionsTableFilterComposer
    extends Composer<_$ClassSyncDatabase, $ClassificationCorrectionsTable> {
  $$ClassificationCorrectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titlePattern => $composableBuilder(
    column: $table.titlePattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerHint => $composableBuilder(
    column: $table.speakerHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeHint => $composableBuilder(
    column: $table.timeHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClassificationCorrectionsTableOrderingComposer
    extends Composer<_$ClassSyncDatabase, $ClassificationCorrectionsTable> {
  $$ClassificationCorrectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titlePattern => $composableBuilder(
    column: $table.titlePattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerHint => $composableBuilder(
    column: $table.speakerHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeHint => $composableBuilder(
    column: $table.timeHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClassificationCorrectionsTableAnnotationComposer
    extends Composer<_$ClassSyncDatabase, $ClassificationCorrectionsTable> {
  $$ClassificationCorrectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get titlePattern => $composableBuilder(
    column: $table.titlePattern,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speakerHint => $composableBuilder(
    column: $table.speakerHint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<String> get timeHint =>
      $composableBuilder(column: $table.timeHint, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ClassificationCorrectionsTableTableManager
    extends
        RootTableManager<
          _$ClassSyncDatabase,
          $ClassificationCorrectionsTable,
          ClassificationCorrectionRow,
          $$ClassificationCorrectionsTableFilterComposer,
          $$ClassificationCorrectionsTableOrderingComposer,
          $$ClassificationCorrectionsTableAnnotationComposer,
          $$ClassificationCorrectionsTableCreateCompanionBuilder,
          $$ClassificationCorrectionsTableUpdateCompanionBuilder,
          (
            ClassificationCorrectionRow,
            BaseReferences<
              _$ClassSyncDatabase,
              $ClassificationCorrectionsTable,
              ClassificationCorrectionRow
            >,
          ),
          ClassificationCorrectionRow,
          PrefetchHooks Function()
        > {
  $$ClassificationCorrectionsTableTableManager(
    _$ClassSyncDatabase db,
    $ClassificationCorrectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassificationCorrectionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ClassificationCorrectionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ClassificationCorrectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> titlePattern = const Value.absent(),
                Value<String?> speakerHint = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
                Value<String?> timeHint = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> subjectName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ClassificationCorrectionsCompanion(
                id: id,
                titlePattern: titlePattern,
                speakerHint: speakerHint,
                weekday: weekday,
                timeHint: timeHint,
                subjectId: subjectId,
                subjectName: subjectName,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> titlePattern = const Value.absent(),
                Value<String?> speakerHint = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
                Value<String?> timeHint = const Value.absent(),
                required String subjectId,
                required String subjectName,
                required DateTime createdAt,
              }) => ClassificationCorrectionsCompanion.insert(
                id: id,
                titlePattern: titlePattern,
                speakerHint: speakerHint,
                weekday: weekday,
                timeHint: timeHint,
                subjectId: subjectId,
                subjectName: subjectName,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClassificationCorrectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClassSyncDatabase,
      $ClassificationCorrectionsTable,
      ClassificationCorrectionRow,
      $$ClassificationCorrectionsTableFilterComposer,
      $$ClassificationCorrectionsTableOrderingComposer,
      $$ClassificationCorrectionsTableAnnotationComposer,
      $$ClassificationCorrectionsTableCreateCompanionBuilder,
      $$ClassificationCorrectionsTableUpdateCompanionBuilder,
      (
        ClassificationCorrectionRow,
        BaseReferences<
          _$ClassSyncDatabase,
          $ClassificationCorrectionsTable,
          ClassificationCorrectionRow
        >,
      ),
      ClassificationCorrectionRow,
      PrefetchHooks Function()
    >;
typedef $$AcademicCacheRecordsTableCreateCompanionBuilder =
    AcademicCacheRecordsCompanion Function({
      required String recordKey,
      required String source,
      required String kind,
      required String externalId,
      Value<String?> subjectId,
      required String title,
      Value<DateTime?> startsAt,
      Value<DateTime?> endsAt,
      required String payloadJson,
      required String fingerprint,
      Value<String> changedFieldsJson,
      Value<DateTime?> lastChangedAt,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$AcademicCacheRecordsTableUpdateCompanionBuilder =
    AcademicCacheRecordsCompanion Function({
      Value<String> recordKey,
      Value<String> source,
      Value<String> kind,
      Value<String> externalId,
      Value<String?> subjectId,
      Value<String> title,
      Value<DateTime?> startsAt,
      Value<DateTime?> endsAt,
      Value<String> payloadJson,
      Value<String> fingerprint,
      Value<String> changedFieldsJson,
      Value<DateTime?> lastChangedAt,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$AcademicCacheRecordsTableFilterComposer
    extends Composer<_$ClassSyncDatabase, $AcademicCacheRecordsTable> {
  $$AcademicCacheRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startsAt => $composableBuilder(
    column: $table.startsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastChangedAt => $composableBuilder(
    column: $table.lastChangedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AcademicCacheRecordsTableOrderingComposer
    extends Composer<_$ClassSyncDatabase, $AcademicCacheRecordsTable> {
  $$AcademicCacheRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startsAt => $composableBuilder(
    column: $table.startsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastChangedAt => $composableBuilder(
    column: $table.lastChangedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AcademicCacheRecordsTableAnnotationComposer
    extends Composer<_$ClassSyncDatabase, $AcademicCacheRecordsTable> {
  $$AcademicCacheRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordKey =>
      $composableBuilder(column: $table.recordKey, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startsAt =>
      $composableBuilder(column: $table.startsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastChangedAt => $composableBuilder(
    column: $table.lastChangedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$AcademicCacheRecordsTableTableManager
    extends
        RootTableManager<
          _$ClassSyncDatabase,
          $AcademicCacheRecordsTable,
          AcademicCacheRow,
          $$AcademicCacheRecordsTableFilterComposer,
          $$AcademicCacheRecordsTableOrderingComposer,
          $$AcademicCacheRecordsTableAnnotationComposer,
          $$AcademicCacheRecordsTableCreateCompanionBuilder,
          $$AcademicCacheRecordsTableUpdateCompanionBuilder,
          (
            AcademicCacheRow,
            BaseReferences<
              _$ClassSyncDatabase,
              $AcademicCacheRecordsTable,
              AcademicCacheRow
            >,
          ),
          AcademicCacheRow,
          PrefetchHooks Function()
        > {
  $$AcademicCacheRecordsTableTableManager(
    _$ClassSyncDatabase db,
    $AcademicCacheRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AcademicCacheRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AcademicCacheRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AcademicCacheRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> recordKey = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime?> startsAt = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> changedFieldsJson = const Value.absent(),
                Value<DateTime?> lastChangedAt = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AcademicCacheRecordsCompanion(
                recordKey: recordKey,
                source: source,
                kind: kind,
                externalId: externalId,
                subjectId: subjectId,
                title: title,
                startsAt: startsAt,
                endsAt: endsAt,
                payloadJson: payloadJson,
                fingerprint: fingerprint,
                changedFieldsJson: changedFieldsJson,
                lastChangedAt: lastChangedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordKey,
                required String source,
                required String kind,
                required String externalId,
                Value<String?> subjectId = const Value.absent(),
                required String title,
                Value<DateTime?> startsAt = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                required String payloadJson,
                required String fingerprint,
                Value<String> changedFieldsJson = const Value.absent(),
                Value<DateTime?> lastChangedAt = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => AcademicCacheRecordsCompanion.insert(
                recordKey: recordKey,
                source: source,
                kind: kind,
                externalId: externalId,
                subjectId: subjectId,
                title: title,
                startsAt: startsAt,
                endsAt: endsAt,
                payloadJson: payloadJson,
                fingerprint: fingerprint,
                changedFieldsJson: changedFieldsJson,
                lastChangedAt: lastChangedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AcademicCacheRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClassSyncDatabase,
      $AcademicCacheRecordsTable,
      AcademicCacheRow,
      $$AcademicCacheRecordsTableFilterComposer,
      $$AcademicCacheRecordsTableOrderingComposer,
      $$AcademicCacheRecordsTableAnnotationComposer,
      $$AcademicCacheRecordsTableCreateCompanionBuilder,
      $$AcademicCacheRecordsTableUpdateCompanionBuilder,
      (
        AcademicCacheRow,
        BaseReferences<
          _$ClassSyncDatabase,
          $AcademicCacheRecordsTable,
          AcademicCacheRow
        >,
      ),
      AcademicCacheRow,
      PrefetchHooks Function()
    >;
typedef $$AcademicChangeRecordsTableCreateCompanionBuilder =
    AcademicChangeRecordsCompanion Function({
      Value<int> id,
      required String recordKey,
      required String kind,
      required String previousPayloadJson,
      required String changedFieldsJson,
      required DateTime changedAt,
    });
typedef $$AcademicChangeRecordsTableUpdateCompanionBuilder =
    AcademicChangeRecordsCompanion Function({
      Value<int> id,
      Value<String> recordKey,
      Value<String> kind,
      Value<String> previousPayloadJson,
      Value<String> changedFieldsJson,
      Value<DateTime> changedAt,
    });

class $$AcademicChangeRecordsTableFilterComposer
    extends Composer<_$ClassSyncDatabase, $AcademicChangeRecordsTable> {
  $$AcademicChangeRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousPayloadJson => $composableBuilder(
    column: $table.previousPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AcademicChangeRecordsTableOrderingComposer
    extends Composer<_$ClassSyncDatabase, $AcademicChangeRecordsTable> {
  $$AcademicChangeRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousPayloadJson => $composableBuilder(
    column: $table.previousPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AcademicChangeRecordsTableAnnotationComposer
    extends Composer<_$ClassSyncDatabase, $AcademicChangeRecordsTable> {
  $$AcademicChangeRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordKey =>
      $composableBuilder(column: $table.recordKey, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get previousPayloadJson => $composableBuilder(
    column: $table.previousPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changedFieldsJson => $composableBuilder(
    column: $table.changedFieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);
}

class $$AcademicChangeRecordsTableTableManager
    extends
        RootTableManager<
          _$ClassSyncDatabase,
          $AcademicChangeRecordsTable,
          AcademicChangeRow,
          $$AcademicChangeRecordsTableFilterComposer,
          $$AcademicChangeRecordsTableOrderingComposer,
          $$AcademicChangeRecordsTableAnnotationComposer,
          $$AcademicChangeRecordsTableCreateCompanionBuilder,
          $$AcademicChangeRecordsTableUpdateCompanionBuilder,
          (
            AcademicChangeRow,
            BaseReferences<
              _$ClassSyncDatabase,
              $AcademicChangeRecordsTable,
              AcademicChangeRow
            >,
          ),
          AcademicChangeRow,
          PrefetchHooks Function()
        > {
  $$AcademicChangeRecordsTableTableManager(
    _$ClassSyncDatabase db,
    $AcademicChangeRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AcademicChangeRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AcademicChangeRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AcademicChangeRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordKey = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> previousPayloadJson = const Value.absent(),
                Value<String> changedFieldsJson = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
              }) => AcademicChangeRecordsCompanion(
                id: id,
                recordKey: recordKey,
                kind: kind,
                previousPayloadJson: previousPayloadJson,
                changedFieldsJson: changedFieldsJson,
                changedAt: changedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordKey,
                required String kind,
                required String previousPayloadJson,
                required String changedFieldsJson,
                required DateTime changedAt,
              }) => AcademicChangeRecordsCompanion.insert(
                id: id,
                recordKey: recordKey,
                kind: kind,
                previousPayloadJson: previousPayloadJson,
                changedFieldsJson: changedFieldsJson,
                changedAt: changedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AcademicChangeRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClassSyncDatabase,
      $AcademicChangeRecordsTable,
      AcademicChangeRow,
      $$AcademicChangeRecordsTableFilterComposer,
      $$AcademicChangeRecordsTableOrderingComposer,
      $$AcademicChangeRecordsTableAnnotationComposer,
      $$AcademicChangeRecordsTableCreateCompanionBuilder,
      $$AcademicChangeRecordsTableUpdateCompanionBuilder,
      (
        AcademicChangeRow,
        BaseReferences<
          _$ClassSyncDatabase,
          $AcademicChangeRecordsTable,
          AcademicChangeRow
        >,
      ),
      AcademicChangeRow,
      PrefetchHooks Function()
    >;

class $ClassSyncDatabaseManager {
  final _$ClassSyncDatabase _db;
  $ClassSyncDatabaseManager(this._db);
  $$CachedSubjectsTableTableManager get cachedSubjects =>
      $$CachedSubjectsTableTableManager(_db, _db.cachedSubjects);
  $$SyncJobsTableTableManager get syncJobs =>
      $$SyncJobsTableTableManager(_db, _db.syncJobs);
  $$JobEventsTableTableManager get jobEvents =>
      $$JobEventsTableTableManager(_db, _db.jobEvents);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$SettingsRecordsTableTableManager get settingsRecords =>
      $$SettingsRecordsTableTableManager(_db, _db.settingsRecords);
  $$ClassificationCorrectionsTableTableManager get classificationCorrections =>
      $$ClassificationCorrectionsTableTableManager(
        _db,
        _db.classificationCorrections,
      );
  $$AcademicCacheRecordsTableTableManager get academicCacheRecords =>
      $$AcademicCacheRecordsTableTableManager(_db, _db.academicCacheRecords);
  $$AcademicChangeRecordsTableTableManager get academicChangeRecords =>
      $$AcademicChangeRecordsTableTableManager(_db, _db.academicChangeRecords);
}
