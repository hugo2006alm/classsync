abstract interface class SyncNotifier {
  Future<void> success(String jobId, String subjectName);
  Future<void> needsReview(String jobId);
  Future<void> failure(String jobId, String message);
}

class NoopSyncNotifier implements SyncNotifier {
  const NoopSyncNotifier();

  @override
  Future<void> failure(String jobId, String message) async {}

  @override
  Future<void> needsReview(String jobId) async {}

  @override
  Future<void> success(String jobId, String subjectName) async {}
}
