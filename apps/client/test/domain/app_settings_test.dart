import 'package:classsync/domain/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production relay is available without manual URL entry', () {
    expect(
      AppSettings.defaults.relayBaseUrl,
      AppSettings.productionRelayBaseUrl,
    );
  });

  test('public site URL is always an HTTPS build-time setting', () {
    final site = Uri.parse(AppSettings.siteBaseUrl);
    expect(site.scheme, 'https');
    expect(site.host, isNotEmpty);
  });

  test('nullable integration mappings can be cleared', () {
    final configured = AppSettings.defaults.copyWith(
      notionSubjectsDataSourceId: 'subjects',
      notionSummariesDataSourceId: 'summaries',
      relayBaseUrl: 'https://relay.example',
    );
    final cleared = configured.copyWith(
      notionSubjectsDataSourceId: null,
      notionSummariesDataSourceId: null,
      relayBaseUrl: null,
    );
    expect(cleared.notionSubjectsDataSourceId, isNull);
    expect(cleared.notionSummariesDataSourceId, isNull);
    expect(cleared.relayBaseUrl, isNull);
  });

  test('invalid threshold ordering is rejected outside assertions', () {
    final invalid = AppSettings.defaults.copyWith(
      reviewThreshold: 0.9,
      autoClassifyThreshold: 0.8,
    );
    expect(invalid.validate, throwsFormatException);
  });

  test('account name is retained and bounded', () {
    final named = AppSettings.defaults.copyWith(displayName: 'Hugo');
    expect(named.displayName, 'Hugo');
    expect(
      AppSettings.defaults
          .copyWith(displayName: List.filled(81, 'x').join())
          .validate,
      throwsFormatException,
    );
  });
}
