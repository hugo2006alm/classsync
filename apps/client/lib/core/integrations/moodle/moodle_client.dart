import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../domain/academic/academic_hub_models.dart';
import '../bounded_response.dart';
import '../integration_exception.dart';

class MoodleAssignment {
  const MoodleAssignment({
    required this.externalId,
    required this.courseId,
    required this.name,
    required this.dueAt,
    required this.url,
    this.submissionState,
    this.modifiedAt,
  });

  final String externalId;
  final String courseId;
  final String name;
  final DateTime dueAt;
  final String url;
  final String? submissionState;
  final DateTime? modifiedAt;

  MoodleAssignment copyWith({String? submissionState}) => MoodleAssignment(
    externalId: externalId,
    courseId: courseId,
    name: name,
    dueAt: dueAt,
    url: url,
    submissionState: submissionState ?? this.submissionState,
    modifiedAt: modifiedAt,
  );
}

class MoodleSyncBundle {
  const MoodleSyncBundle({
    required this.courses,
    required this.assignments,
    required this.announcements,
  });

  final List<MoodleCourse> courses;
  final List<MoodleAssignment> assignments;
  final List<MoodleAnnouncement> announcements;
}

class MoodleClient {
  MoodleClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://moodle.isep.ipp.pt',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 30),
              responseType: ResponseType.json,
              headers: const {'accept': 'application/json'},
            ),
          );

  final Dio _dio;

  Future<String> testConnection(String token) async {
    final site = await _call(token, 'core_webservice_get_site_info');
    return site['fullname']?.toString() ?? 'Moodle ISEP';
  }

  Future<MoodleSyncBundle> synchronize(String token, {DateTime? since}) async {
    final site = await _call(token, 'core_webservice_get_site_info');
    final userId = site['userid'];
    if (userId is! num) {
      throw const IntegrationException(
        integration: 'Moodle',
        code: 'invalid_response',
        userMessage: 'Moodle did not return the connected user identity.',
        retryable: false,
      );
    }
    final coursesJson = await _call(
      token,
      'core_enrol_get_users_courses',
      parameters: {'userid': userId.toInt()},
    );
    final courses = decodeCourses(
      coursesJson,
      baseUrl: _dio.options.baseUrl,
    ).take(100).toList();
    if (courses.isEmpty) {
      return const MoodleSyncBundle(
        courses: [],
        assignments: [],
        announcements: [],
      );
    }
    final ids = courses
        .map((course) => int.tryParse(course.externalId))
        .whereType<int>()
        .toList();
    final assignmentsJson = await _call(
      token,
      'mod_assign_get_assignments',
      parameters: {
        for (var index = 0; index < ids.length; index++)
          'courseids[$index]': ids[index],
      },
    );
    final assignments = decodeAssignments(
      assignmentsJson,
      baseUrl: _dio.options.baseUrl,
      since: since,
    ).take(300).toList();
    final assignmentsWithStatus = <MoodleAssignment>[];
    for (final assignment in assignments) {
      try {
        final status = await _call(
          token,
          'mod_assign_get_submission_status',
          parameters: {'assignid': int.parse(assignment.externalId)},
        );
        assignmentsWithStatus.add(
          assignment.copyWith(submissionState: decodeSubmissionState(status)),
        );
      } on IntegrationException catch (error) {
        if (error.code == 'invalidtoken') rethrow;
        // Some student token roles omit submission-status permission. The due
        // date remains useful and an unknown state is safer than an inference.
        assignmentsWithStatus.add(assignment);
      }
    }
    final forumsJson = await _call(
      token,
      'mod_forum_get_forums_by_courses',
      parameters: {
        for (var index = 0; index < ids.length; index++)
          'courseids[$index]': ids[index],
      },
    );
    final newsForums = _asList(
      forumsJson,
    ).where((item) => item['type'] == 'news').take(100).toList();
    final announcements = <MoodleAnnouncement>[];
    for (final forum in newsForums) {
      final forumId = forum['id'];
      if (forumId is! num) continue;
      final discussions = await _call(
        token,
        'mod_forum_get_forum_discussions_paginated',
        parameters: {
          'forumid': forumId.toInt(),
          'sortdirection': 'DESC',
          'perpage': 20,
        },
      );
      announcements.addAll(
        decodeAnnouncements(
          discussions,
          courseId: forum['course']?.toString() ?? '',
          baseUrl: _dio.options.baseUrl,
          since: since,
        ),
      );
    }
    return MoodleSyncBundle(
      courses: courses,
      assignments: assignmentsWithStatus,
      announcements: announcements.take(300).toList(),
    );
  }

  Future<dynamic> _call(
    String token,
    String function, {
    Map<String, dynamic> parameters = const {},
  }) async {
    final base = Uri.parse(_dio.options.baseUrl);
    final endpoint = base.resolve('/webservice/rest/server.php');
    if (endpoint.scheme != 'https' ||
        endpoint.host.toLowerCase() != 'moodle.isep.ipp.pt' ||
        (endpoint.hasPort && endpoint.port != 443)) {
      throw const IntegrationException(
        integration: 'Moodle',
        code: 'unsafe_moodle_url',
        userMessage: 'Moodle must use the trusted ISEP HTTPS host.',
        retryable: false,
      );
    }
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await _dio.get<dynamic>(
          endpoint.toString(),
          queryParameters: {
            'wstoken': token,
            'wsfunction': function,
            'moodlewsrestformat': 'json',
            ...parameters,
          },
          options: Options(responseType: ResponseType.stream),
        );
        final bytes = await readBoundedResponse(
          response.data,
          response.headers,
        );
        final data = jsonDecode(utf8.decode(bytes, allowMalformed: true));
        if (data is Map && data['exception'] != null) {
          final code = data['errorcode']?.toString() ?? 'moodle_error';
          throw IntegrationException(
            integration: 'Moodle',
            code: code,
            userMessage: code == 'invalidtoken'
                ? 'Moodle access expired or was revoked. Save a new token.'
                : 'Moodle rejected $function: ${data['message'] ?? code}',
            retryable: false,
          );
        }
        return data;
      } on IntegrationPayloadTooLarge {
        throw const IntegrationException(
          integration: 'Moodle',
          code: 'response_too_large',
          userMessage:
              'Moodle returned more data than ClassSync can safely process.',
          retryable: false,
        );
      } on DioException catch (error) {
        if (attempt == 3) {
          throw IntegrationException.fromDio('Moodle', error);
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      } on FormatException {
        throw const IntegrationException(
          integration: 'Moodle',
          code: 'invalid_response',
          userMessage: 'Moodle returned an invalid response.',
          retryable: false,
        );
      }
    }
    throw StateError('Moodle retry loop completed unexpectedly.');
  }

  static List<MoodleCourse> decodeCourses(
    dynamic json, {
    required String baseUrl,
  }) => _asList(json)
      .where((item) => item['id'] != null)
      .map(
        (item) => MoodleCourse(
          externalId: item['id'].toString(),
          name:
              item['fullname']?.toString() ??
              item['shortname']?.toString() ??
              'Course',
          shortName: item['shortname']?.toString() ?? '',
          url: '$baseUrl/course/view.php?id=${item['id']}',
        ),
      )
      .toList();

  static List<MoodleAssignment> decodeAssignments(
    dynamic json, {
    required String baseUrl,
    DateTime? since,
  }) {
    if (json is! Map) return const [];
    final result = <MoodleAssignment>[];
    for (final course in _asList(json['courses'])) {
      final courseId = course['id']?.toString() ?? '';
      for (final item in _asList(course['assignments'])) {
        final due = item['duedate'];
        if (item['id'] == null || due is! num || due <= 0) continue;
        final modifiedSeconds = item['timemodified'] as num?;
        final modifiedAt = modifiedSeconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                modifiedSeconds.toInt() * 1000,
                isUtc: true,
              );
        if (since != null && modifiedAt != null && !modifiedAt.isAfter(since)) {
          continue;
        }
        final moduleId = item['cmid'] ?? item['id'];
        result.add(
          MoodleAssignment(
            externalId: item['id'].toString(),
            courseId: courseId,
            name: item['name']?.toString() ?? 'Assignment',
            dueAt: DateTime.fromMillisecondsSinceEpoch(
              due.toInt() * 1000,
              isUtc: true,
            ),
            url: '$baseUrl/mod/assign/view.php?id=$moduleId',
            submissionState: item['submissionstatus']?.toString(),
            modifiedAt: modifiedAt,
          ),
        );
      }
    }
    return result;
  }

  static List<MoodleAnnouncement> decodeAnnouncements(
    dynamic json, {
    required String courseId,
    required String baseUrl,
    DateTime? since,
  }) {
    if (json is! Map) return const [];
    return _asList(json['discussions'])
        .where((item) => item['discussion'] != null || item['id'] != null)
        .where((item) {
          if (since == null) return true;
          final modified = item['timemodified'] ?? item['created'];
          if (modified is! num) return true;
          return DateTime.fromMillisecondsSinceEpoch(
            modified.toInt() * 1000,
            isUtc: true,
          ).isAfter(since);
        })
        .map((item) {
          final id = (item['discussion'] ?? item['id']).toString();
          final timestamp = (item['created'] as num?)?.toInt() ?? 0;
          final message = item['message']?.toString() ?? '';
          return MoodleAnnouncement(
            externalId: id,
            courseId: courseId,
            title:
                item['name']?.toString() ??
                item['subject']?.toString() ??
                'Announcement',
            preview: (html_parser.parseFragment(message).text ?? '')
                .trim()
                .replaceAll(RegExp(r'\s+'), ' '),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              timestamp * 1000,
              isUtc: true,
            ),
            url: '$baseUrl/mod/forum/discuss.php?d=$id',
          );
        })
        .toList();
  }

  static String? decodeSubmissionState(dynamic json) {
    if (json is! Map) return null;
    final attempt = json['lastattempt'];
    if (attempt is! Map) return null;
    final submission = attempt['submission'];
    if (submission is Map && submission['status'] != null) {
      return submission['status'].toString();
    }
    return attempt['submissionsenabled'] == false ? 'closed' : null;
  }
}

List<Map<String, dynamic>> _asList(dynamic value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
