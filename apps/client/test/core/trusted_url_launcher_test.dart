import 'package:classsync/core/security/trusted_url_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('trusted Notion links fall back to the platform launcher', () async {
    final modes = <LaunchMode>[];

    final opened = await launchTrustedUrl(
      ' https://www.notion.so/example ',
      allowedHosts: trustedNotionHosts,
      launcher: (uri, mode) async {
        modes.add(mode);
        return mode == LaunchMode.platformDefault;
      },
    );

    expect(opened, isTrue);
    expect(modes, [LaunchMode.externalApplication, LaunchMode.platformDefault]);
  });

  test('untrusted links never reach the platform launcher', () async {
    var called = false;

    final opened = await launchTrustedUrl(
      'https://notion.so.attacker.example/page',
      allowedHosts: trustedNotionHosts,
      launcher: (uri, mode) async {
        called = true;
        return true;
      },
    );

    expect(opened, isFalse);
    expect(called, isFalse);
  });
}
