import 'sync_models.dart';

enum ClassificationAction { autoPublish, review, hold }

class ClassificationPolicy {
  const ClassificationPolicy({
    required this.autoPublishThreshold,
    required this.reviewThreshold,
  }) : assert(reviewThreshold <= autoPublishThreshold);

  final double autoPublishThreshold;
  final double reviewThreshold;

  ClassificationAction evaluate(ClassificationResult result) {
    if (result.decision == ClassificationDecision.match &&
        result.confidence >= autoPublishThreshold) {
      return ClassificationAction.autoPublish;
    }
    if (result.confidence >= reviewThreshold) {
      return ClassificationAction.review;
    }
    return ClassificationAction.hold;
  }
}
