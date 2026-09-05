enum SummaryDetail { concise, balanced, detailed }

const _unsetSetting = Object();

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
    Object? notionSubjectsDataSourceId = _unsetSetting,
    Object? notionSummariesDataSourceId = _unsetSetting,
    Object? relayBaseUrl = _unsetSetting,
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
        identical(notionSubjectsDataSourceId, _unsetSetting)
        ? this.notionSubjectsDataSourceId
        : notionSubjectsDataSourceId as String?,
    notionSummariesDataSourceId:
        identical(notionSummariesDataSourceId, _unsetSetting)
        ? this.notionSummariesDataSourceId
        : notionSummariesDataSourceId as String?,
    relayBaseUrl: identical(relayBaseUrl, _unsetSetting)
        ? this.relayBaseUrl
        : relayBaseUrl as String?,
  );

  void validate() {
    if (pollingMinutes < 15 || pollingMinutes > 1440) {
      throw const FormatException('Polling interval must be 15–1440 minutes.');
    }
    if (overlapHours < 1 || overlapHours > 168) {
      throw const FormatException('Recovery overlap must be 1–168 hours.');
    }
    if (workerCount < 1 || workerCount > 2) {
      throw const FormatException('Worker count must be 1 or 2.');
    }
    if (reviewThreshold < 0 ||
        autoClassifyThreshold > 1 ||
        reviewThreshold > autoClassifyThreshold) {
      throw const FormatException(
        'Review threshold must be between 0 and the auto-publish threshold.',
      );
    }
    if (classificationModel.trim().isEmpty || summaryModel.trim().isEmpty) {
      throw const FormatException('Gemini model names cannot be empty.');
    }
    if (diagnosticsRetentionDays < 1 || diagnosticsRetentionDays > 365) {
      throw const FormatException('Retention must be 1–365 days.');
    }
    final relay = relayBaseUrl?.trim();
    if (relay != null && relay.isNotEmpty) {
      final uri = Uri.tryParse(relay);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Relay URL must be a valid HTTPS URL.');
      }
    }
    if (setupComplete &&
        ((notionSubjectsDataSourceId?.trim().isEmpty ?? true) ||
            (notionSummariesDataSourceId?.trim().isEmpty ?? true))) {
      throw const FormatException('Both Notion data sources are required.');
    }
  }
}
