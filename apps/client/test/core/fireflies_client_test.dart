import 'package:classsync/core/integrations/fireflies/fireflies_client.dart';
import 'package:classsync/core/integrations/integration_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection validation uses the explicit GraphQL endpoint', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.fireflies.ai'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/graphql');
          expect(options.headers['authorization'], 'Bearer api-key');
          expect(options.contentType, Headers.jsonContentType);
          expect(options.data['query'], contains('user_id'));
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {
                'data': {
                  'user': {
                    'user_id': 'fireflies-user-123',
                    'email': 'owner@example.com',
                    'name': 'Owner',
                  },
                },
              },
            ),
          );
        },
      ),
    );

    final identity = await FirefliesClient(dio: dio).testConnection('api-key');

    expect(identity.userId, 'fireflies-user-123');
    expect(identity.email, 'owner@example.com');
    expect(identity.name, 'Owner');
  });

  test('connection validation surfaces Fireflies GraphQL errors', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.fireflies.ai'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: const {
              'errors': [
                {
                  'message': 'API key is invalid',
                  'extensions': {'code': 'UNAUTHENTICATED'},
                },
              ],
            },
          ),
        ),
      ),
    );

    await expectLater(
      FirefliesClient(dio: dio).testConnection('bad-key'),
      throwsA(
        isA<IntegrationException>()
            .having((error) => error.retryable, 'retryable', isFalse)
            .having(
              (error) => error.userMessage,
              'message',
              contains('API key is invalid'),
            ),
      ),
    );
  });
}
