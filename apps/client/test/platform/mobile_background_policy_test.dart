import 'package:classsync/platform/mobile/mobile_background_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps push token for background automation without visible alerts', () {
    expect(
      needsMobilePushToken(
        automaticSync: true,
        backgroundMobileSync: true,
        notificationsEnabled: false,
      ),
      isTrue,
    );
    expect(
      needsMobilePushToken(
        automaticSync: false,
        backgroundMobileSync: true,
        notificationsEnabled: false,
      ),
      isFalse,
    );
  });

  test('deduplicates one push event without dropping different events', () {
    final first = mobilePushUniqueWorkName(eventId: 'event-one');
    expect(mobilePushUniqueWorkName(eventId: 'event-one'), first);
    expect(mobilePushUniqueWorkName(eventId: 'event-two'), isNot(first));
    expect(first, startsWith('$mobilePushTaskName.'));
  });

  test('uses message id and then a deterministic fallback', () {
    expect(
      mobilePushUniqueWorkName(messageId: 'message-one'),
      mobilePushUniqueWorkName(messageId: 'message-one'),
    );
    expect(
      mobilePushUniqueWorkName(fallbackMicros: 42),
      mobilePushUniqueWorkName(fallbackMicros: 42),
    );
  });
}
