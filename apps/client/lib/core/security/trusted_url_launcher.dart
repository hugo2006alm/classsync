import 'package:url_launcher/url_launcher.dart';

Future<bool> launchTrustedUrl(
  String value, {
  required Set<String> allowedHosts,
}) async {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final trusted = allowedHosts.any(
    (allowed) => host == allowed || host.endsWith('.$allowed'),
  );
  if (!trusted) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
