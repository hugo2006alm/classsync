enum SummaryDetail { concise, balanced, detailed }

class AppSettings {
  const AppSettings({
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

  static const defaults = AppSettings(
    setupComplete: false,
    automaticSync: true,
    launchWithWindows: true,
    syncOnLaunch: true,
    backgroundMobileSync: true,
    notificationsEnabled: true,
    pollingMinutes: 30,
    overlapHours: 48,
    workerCount: 1,
    keepTranscripts: false,
    cleanCompletedPayloads: true,
    diagnosticsRetentionDays: 14,
    classificationModel: 'gemini-3.8-flash',
    summaryModel: 'gemini-3.8-flash',
    autoClassifyThreshold: 0.85,
    reviewThreshold: 0.60,
    summaryLanguage: 'Português (Portugal)',
    summaryDetail: SummaryDetail.detailed,
    notionMetadataEnabled: true,
  );

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
  final String classificationModel;
  final String summaryModel;
  final double autoClassifyThreshold;
  final double reviewThreshold;
  final String summaryLanguage;
  final SummaryDetail summaryDetail;
  final bool notionMetadataEnabled;
  final String? notionSubjectsDataSourceId;
  final String? notionSummariesDataSourceId;
  final String? relayBaseUrl;

  AppSettings copyWith({
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
    String? classificationModel,
    String? summaryModel,
    double? autoClassifyThreshold,
    double? reviewThreshold,
    String? summaryLanguage,
    SummaryDetail? summaryDetail,
    bool? notionMetadataEnabled,
    String? notionSubjectsDataSourceId,
    String? notionSummariesDataSourceId,
    String? relayBaseUrl,
  }) => AppSettings(
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
    classificationModel: classificationModel ?? this.classificationModel,
    summaryModel: summaryModel ?? this.summaryModel,
    autoClassifyThreshold: autoClassifyThreshold ?? this.autoClassifyThreshold,
    reviewThreshold: reviewThreshold ?? this.reviewThreshold,
    summaryLanguage: summaryLanguage ?? this.summaryLanguage,
    summaryDetail: summaryDetail ?? this.summaryDetail,
    notionMetadataEnabled: notionMetadataEnabled ?? this.notionMetadataEnabled,
    notionSubjectsDataSourceId:
        notionSubjectsDataSourceId ?? this.notionSubjectsDataSourceId,
    notionSummariesDataSourceId:
        notionSummariesDataSourceId ?? this.notionSummariesDataSourceId,
    relayBaseUrl: relayBaseUrl ?? this.relayBaseUrl,
  );
}
