import 'package:classsync/core/integrations/fireflies/fireflies_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection validation returns stable Fireflies identity', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.fireflies.ai/graphql'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.headers['authorization'], 'Bearer api-key');
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
}
