import 'package:classsync/domain/academic/academic_models.dart';
import 'package:classsync/domain/sync/classification_policy.dart';
import 'package:classsync/domain/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = ClassificationPolicy(
    autoPublishThreshold: 0.85,
    reviewThreshold: 0.60,
  );

  test('publishes only a confident match', () {
    expect(policy.evaluate(_result(0.85)), ClassificationAction.autoPublish);
    expect(policy.evaluate(_result(0.84)), ClassificationAction.review);
  });

  test('holds classification below review threshold', () {
    expect(policy.evaluate(_result(0.59)), ClassificationAction.hold);
  });

  test('uncertain decision never auto-publishes', () {
    expect(
      policy.evaluate(
        _result(0.99, decision: ClassificationDecision.uncertain),
      ),
      ClassificationAction.review,
    );
  });

  test('rejects a Gemini subject outside active candidates', () {
    final result = _result(0.95, subjectId: 'invented');
    final subjects = [
      AcademicSubject(
        notionId: 'valid',
        name: 'Valid',
        year: '3º',
        semester: '1º',
        status: 'In progress',
        lastSyncedAt: DateTime.utc(2026),
      ),
    ];

    expect(result.hasValidSubject(subjects), isFalse);
  });
}

ClassificationResult _result(
  double confidence, {
  ClassificationDecision decision = ClassificationDecision.match,
  String subjectId = 'subject',
}) => ClassificationResult(
  decision: decision,
  subjectId: subjectId,
  subjectName: 'AI',
  confidence: confidence,
  candidates: const [],
  reasoningSummary: const [],
);
