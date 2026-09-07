import 'academic_hub_models.dart';
import 'academic_models.dart';

class AcademicActionFailure implements Exception {
  const AcademicActionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AcademicHubActions {
  Future<String> readPortalUsername();
  Future<void> connectPortal({required String username, String? password});
  Future<void> connectMoodle(String token);
  Future<void> addManualEvaluation(EvaluationEvent event);
  Future<void> addManualGrade(GradeComponent component);
  Future<void> setEvaluationReminder(AcademicRecord record, int? minutes);
  Future<void> setTuitionReminder(
    AcademicRecord record,
    int? minutes, {
    required bool overdueReminder,
  });
  Future<void> setEvaluationTypeReminder(String type, int? minutes);
  Future<void> setMoodleCourseSubject(
    AcademicRecord course,
    AcademicSubject subject,
  );
  Future<void> confirmFormula(AcademicRecord record);
  Future<void> updateLectureTask(
    AcademicRecord record, {
    String? title,
    String? description,
    DateTime? dueAt,
    bool clearDueAt,
    LectureTaskStatus? status,
  });
  Future<void> markPortalNotificationRead(AcademicRecord record);
  Future<void> setAcademicUpdateNotifications(String source, bool enabled);
  Future<void> openSource(String url);
}
