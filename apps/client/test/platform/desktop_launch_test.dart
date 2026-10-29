import 'package:classsync/domain/settings/app_settings.dart';
import 'package:classsync/platform/desktop/desktop_launch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final configured = AppSettings.defaults.copyWith(setupComplete: true);

  test('login honors both minimized choices and legacy login entries', () {
    for (final flag in ['--startup', '--background']) {
      expect(shouldStartHidden([flag], configured), isTrue);
      expect(
        shouldStartHidden([flag], configured.copyWith(startMinimized: false)),
        isFalse,
      );
    }
  });

  test('manual launch and incomplete setup always open visibly', () {
    expect(shouldStartHidden([], configured), isFalse);
    expect(shouldStartHidden(['--startup'], AppSettings.defaults), isFalse);
  });
}
