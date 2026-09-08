import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:classsync/core/integrations/portal/isep_portal_client.dart';
import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:classsync/core/integrations/bounded_response.dart';

Future<void> main() async {
  final input = jsonDecode(stdin.readLineSync()!) as Map<String, dynamic>;
  final steps = <Object>[];
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://portal.isep.ipp.pt/intranet/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'accept': 'text/html,application/xhtml+xml',
        'accept-language': 'pt-PT,pt;q=0.9,en;q=0.7',
        'user-agent':
            'Mozilla/5.0 ClassSync/0.3 (ISEP Portal read-only client)',
      },
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) async {
        late final List<int> bytes;
        try {
          bytes = await readBoundedResponse(response.data, response.headers);
        } catch (_) {
          handler.reject(DioException(requestOptions: response.requestOptions));
          return;
        }
        final body = latin1.decode(bytes);
        steps.add({
          'method': response.requestOptions.method,
          'path': response.requestOptions.uri.path,
          'status': response.statusCode,
          'redirectPath': Uri.tryParse(
            response.headers.value('location') ?? '',
          )?.path,
          'cookieNames': (response.headers['set-cookie'] ?? [])
              .map((c) => c.split('=').first)
              .toList(),
          'loginField': body.contains(
            'id="ContentPlaceHolderMain_txtLoginISEP"',
          ),
          'passwordField': body.contains('type="password"'),
          'scriptRedirect': RegExp(
            r'(?:location\s*=|location\.href\s*=|location\.replace\s*\()',
          ).hasMatch(body),
          'invalidLoginText': RegExp(
            r'(?:incorret|incorrect|inv.lid|falhou|errad)',
            caseSensitive: false,
          ).hasMatch(body.replaceAll(RegExp(r'<script[\s\S]*?</script>'), '')),
        });
        response.data = ResponseBody.fromBytes(
          bytes,
          response.statusCode!,
          headers: response.headers.map,
        );
        handler.next(response);
      },
    ),
  );
  try {
    final client = IsepPortalClient(dio: dio);
    await client.authenticate(
      PortalCredentials(
        username: input['username'] as String,
        password: input['password'] as String,
      ),
    );
    final sessionValid = await client.validateSession();
    stdout.write(
      jsonEncode({
        'result': sessionValid ? 'success' : 'session_validation_failed',
        'steps': steps,
      }),
    );
  } on IntegrationException catch (error) {
    stdout.write(jsonEncode({'result': error.code, 'steps': steps}));
  } catch (_) {
    stdout.write(jsonEncode({'result': 'probe_error', 'steps': steps}));
  }
}
