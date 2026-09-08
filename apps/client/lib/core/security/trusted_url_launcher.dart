import 'package:url_launcher/url_launcher.dart';

const Set<String> trustedNotionHosts = {
  'notion.so',
  'notion.site',
  'notion.com',
};

typedef TrustedUrlLaunch = Future<bool> Function(Uri uri, LaunchMode mode);

Future<bool> launchTrustedUrl(
  String value, {
  required Set<String> allowedHosts,
  TrustedUrlLaunch? launcher,
}) async {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final trusted = allowedHosts.any(
    (allowed) => host == allowed || host.endsWith('.$allowed'),
  );
  if (!trusted) return false;
  final launch = launcher ?? (uri, mode) => launchUrl(uri, mode: mode);
  try {
    if (await launch(uri, LaunchMode.externalApplication)) return true;
  } catch (_) {
    // Some platform launchers throw instead of returning false. The default
    // mode still gives the OS a chance to open the trusted HTTPS URL.
  }
  try {
    return await launch(uri, LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}
