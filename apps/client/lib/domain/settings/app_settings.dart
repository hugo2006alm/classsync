enum SummaryDetail { concise, balanced, detailed }

class GeminiModelOption {
  const GeminiModelOption({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

const geminiTextModels = <GeminiModelOption>[
  GeminiModelOption(
    id: 'gemini-3.8-flash',
    label: 'Gemini 3.8 Flash',
    description: 'Best Flash quality; recommended for detailed summaries.',
  ),
  GeminiModelOption(
    id: 'gemini-3.7-flash',
    label: 'Gemini 3.7 Flash',
    description: 'Previous high-quality Flash model.',
  ),
  GeminiModelOption(
    id: 'gemini-3.6-flash',
    label: 'Gemini 3.6 Flash',
    description: 'Balanced speed and capability.',
  ),
  GeminiModelOption(
    id: 'gemini-3.5-flash',
    label: 'Gemini 3.5 Flash',
    description: 'Fast general-purpose model.',
  ),
  GeminiModelOption(
    id: 'gemini-3.5-flash-lite',
    label: 'Gemini 3.5 Flash-Lite',
    description: 'Lower-cost lightweight model.',
  ),
  GeminiModelOption(
    id: 'gemini-3.1-flash-lite',
    label: 'Gemini 3.1 Flash-Lite',
    description: 'Fast, low-cost model recommended for class identification.',
  ),
  GeminiModelOption(
    id: 'gemini-2.5-flash',
    label: 'Gemini 2.5 Flash',
    description: 'Stable compatibility fallback.',
  ),
  GeminiModelOption(
    id: 'gemini-2.5-flash-lite',
    label: 'Gemini 2.5 Flash-Lite',
    description: 'Lowest-cost stable compatibility fallback.',
  ),
];

String geminiModelLabel(String id) =>
    geminiTextModels
        .where((model) => model.id == id)
        .map((model) => model.label)
        .firstOrNull ??
    id;

const _unsetSetting = Object();

class AppSettings {
  static const productionRelayBaseUrl =
      'https://classsync-relay.classsync-relay.workers.dev';
  static const siteBaseUrl = String.fromEnvironment(
    'CLASSSYNC_SITE_URL',
    defaultValue: 'https://hugo2006alm.github.io/classsync-site',
  );

  const AppSettings({
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
    displayName: '',
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
    useAiClassification: true,
    classificationModel: 'gemini-3.1-flash-lite',
    summaryModel: 'gemini-3.8-flash',
    autoClassifyThreshold: 0.85,
    reviewThreshold: 0.60,
    summaryLanguage: 'Português (Portugal)',
    summaryDetail: SummaryDetail.detailed,
    notionMetadataEnabled: true,
    relayBaseUrl: productionRelayBaseUrl,
  );

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
    if (displayName.length > 80) {
      throw const FormatException(
        'Account name must be 80 characters or fewer.',
      );
    }
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
