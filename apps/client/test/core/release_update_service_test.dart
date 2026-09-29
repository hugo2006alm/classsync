import 'dart:convert';
import 'dart:typed_data';

import 'package:classsync/core/updates/release_update_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'checks a private release with bearer auth and trusted asset URLs',
    () async {
      final adapter = _ReleaseAdapter();
      final service = ReleaseUpdateService(
        dio: Dio()..httpClientAdapter = adapter,
        currentVersion: '0.3.23',
        token: 'local-test-token',
        platform: ReleasePlatform.windows,
      );
      final update = await service.check();
      expect(adapter.authorization, 'Bearer local-test-token');
      expect(update?.version, '0.3.24');
      expect(
        update?.assetUrl.path,
        '/repos/hugo2006alm/classsync/releases/assets/1',
      );
      expect(
        update?.checksumUrl.path,
        '/repos/hugo2006alm/classsync/releases/assets/2',
      );
    },
  );

  test('rejects an asset URL outside the repository API', () async {
    final service = ReleaseUpdateService(
      dio: Dio()
        ..httpClientAdapter = _ReleaseAdapter(
          assetUrl: 'https://example.com/malicious.exe',
        ),
      currentVersion: '0.3.23',
      token: 'local-test-token',
      platform: ReleasePlatform.windows,
    );
    await expectLater(service.check(), throwsFormatException);
  });

  test('compares numeric release components', () {
    expect(compareVersions('0.3.24', '0.3.23'), greaterThan(0));
    expect(compareVersions('0.10.0', '0.9.99'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('0.3.22', '0.3.23'), lessThan(0));
    expect(() => compareVersions('v1.0.0', '1.0.0'), throwsFormatException);
  });

  test('selects the exact asset checksum', () {
    final a = List.filled(64, 'a').join();
    final b = List.filled(64, 'b').join();
    final body =
        '$a  ClassSync-Android.apk\n'
        '$b  ClassSync-Android.aab\n';
    expect(checksumForAsset(body, 'ClassSync-Android.apk'), a);
    expect(
      () => checksumForAsset(body, 'ClassSync-Setup-0.3.24.exe'),
      throwsFormatException,
    );
  });
}

class _ReleaseAdapter implements HttpClientAdapter {
  _ReleaseAdapter({
    this.assetUrl =
        'https://api.github.com/repos/hugo2006alm/classsync/releases/assets/1',
  });

  final String assetUrl;
  String? authorization;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorization = options.headers['Authorization'] as String?;
    final json = jsonEncode({
      'tag_name': 'v0.3.24',
      'assets': [
        {
          'name': 'ClassSync-Setup-0.3.24.exe',
          'size': 123,
          'id': 1,
          'url': assetUrl,
        },
        {
          'name': 'SHA256SUMS.txt',
          'size': 64,
          'id': 2,
          'url':
              'https://api.github.com/repos/hugo2006alm/classsync/releases/assets/2',
        },
      ],
    });
    return ResponseBody.fromString(
      json,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
