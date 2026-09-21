const mobilePushTaskName = 'classsync.pushSync';

bool needsMobilePushToken({
  required bool automaticSync,
  required bool backgroundMobileSync,
  required bool notificationsEnabled,
}) => notificationsEnabled || (automaticSync && backgroundMobileSync);

String mobilePushUniqueWorkName({
  String? eventId,
  String? messageId,
  int? fallbackMicros,
}) {
  final discriminator =
      _firstNonEmpty(eventId, messageId) ??
      (fallbackMicros ?? DateTime.now().microsecondsSinceEpoch).toString();
  return '$mobilePushTaskName.${_stableHash(discriminator)}';
}

String? _firstNonEmpty(String? first, String? second) {
  final normalizedFirst = first?.trim();
  if (normalizedFirst?.isNotEmpty == true) return normalizedFirst;
  final normalizedSecond = second?.trim();
  return normalizedSecond?.isNotEmpty == true ? normalizedSecond : null;
}

String _stableHash(String value) {
  var first = 0x811c9dc5;
  var second = 0x9e3779b9;
  for (final unit in value.codeUnits) {
    first = ((first ^ unit) * 0x01000193) & 0xffffffff;
    second = ((second ^ unit) * 0x85ebca6b) & 0xffffffff;
  }
  return '${first.toRadixString(16).padLeft(8, '0')}'
      '${second.toRadixString(16).padLeft(8, '0')}';
}
