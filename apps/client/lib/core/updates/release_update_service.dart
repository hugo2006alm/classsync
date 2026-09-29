import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const _repository = 'hugo2006alm/classsync';
const _latestRelease =
    'https://api.github.com/repos/$_repository/releases/latest';
const _maxAssetBytes = 300 * 1024 * 1024;

enum ReleasePlatform { windows, android }

class ReleaseUpdate {
  const ReleaseUpdate({
    required this.version,
    required this.assetUrl,
    required this.assetName,
    required this.checksumUrl,
    required this.assetSize,
  });

  final String version;
  final Uri assetUrl;
  final String assetName;
  final Uri checksumUrl;
  final int assetSize;
}

class ReleaseUpdateService {
  ReleaseUpdateService({
    Dio? dio,
    String? currentVersion,
    String? token,
    ReleasePlatform? platform,
  }) : _dio = dio ?? Dio(),
       _currentVersion = currentVersion,
       _token = token,
       _platform =
           platform ??
           (Platform.isAndroid
               ? ReleasePlatform.android
               : Platform.isWindows
               ? ReleasePlatform.windows
               : null);

  final Dio _dio;
  final String? _currentVersion;
  final String? _token;
  final ReleasePlatform? _platform;

  Map<String, String> _headers(String accept) => {
    'Accept': accept,
    'X-GitHub-Api-Version': '2022-11-28',
    if (_token?.isNotEmpty == true) 'Authorization': 'Bearer $_token',
  };

  Future<ReleaseUpdate?> check() async {
    if (_platform == null) return null;
    final current =
        _currentVersion ?? (await PackageInfo.fromPlatform()).version;
    final response = await _dio.get<Map<String, dynamic>>(
      _latestRelease,
      options: Options(
        headers: _headers('application/vnd.github+json'),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final release = response.data;
    if (release == null) throw const FormatException('Empty release response.');
    final tag = release['tag_name'];
    if (tag is! String || !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(tag)) {
      throw const FormatException('Invalid release version.');
    }
    final version = tag.substring(1);
    if (compareVersions(version, current) <= 0) return null;
    final assets = release['assets'];
    if (assets is! List) throw const FormatException('Missing release assets.');
    final wanted = _platform == ReleasePlatform.android
        ? 'ClassSync-Android.apk'
        : 'ClassSync-Setup-$version.exe';
    final asset = _asset(assets, wanted);
    final checksum = _asset(assets, 'SHA256SUMS.txt');
    final size = asset['size'];
    if (size is! int || size <= 0 || size > _maxAssetBytes) {
      throw const FormatException('Invalid update size.');
    }
    return ReleaseUpdate(
      version: version,
      assetUrl: _assetApiUrl(asset),
      assetName: wanted,
      checksumUrl: _assetApiUrl(checksum),
      assetSize: size,
    );
  }

  Future<File> download(
    ReleaseUpdate update, {
    void Function(int received, int total)? onProgress,
  }) async {
    final checksumStream = (await _openAsset(update.checksumUrl)).stream;
    final checksumBytes = <int>[];
    await for (final chunk in checksumStream) {
      checksumBytes.addAll(chunk);
      if (checksumBytes.length > 32768) {
        throw const FormatException('Checksum list too large.');
      }
    }
    final expected = checksumForAsset(
      utf8.decode(checksumBytes),
      update.assetName,
    );
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}classsync-updates',
    );
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}${update.assetName}',
    );
    final partial = File('${file.path}.part');
    try {
      final stream = (await _openAsset(update.assetUrl)).stream;
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in stream) {
          received += chunk.length;
          if (received > update.assetSize || received > _maxAssetBytes) {
            throw const FormatException('Update exceeds expected size.');
          }
          sink.add(chunk);
          onProgress?.call(received, update.assetSize);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received != update.assetSize) {
        throw const FormatException('Incomplete update download.');
      }
      final actual = (await sha256.bind(partial.openRead()).first).toString();
      if (actual != expected) {
        throw const FormatException('Update checksum mismatch.');
      }
      if (await file.exists()) await file.delete();
      return await partial.rename(file.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<ResponseBody> _openAsset(Uri uri) async {
    if (uri.scheme != 'https' ||
        uri.host != 'api.github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        !RegExp(
          r'^/repos/hugo2006alm/classsync/releases/assets/\d+$',
        ).hasMatch(uri.path)) {
      throw const FormatException('Untrusted release asset URL.');
    }
    final response = await _dio.get<ResponseBody>(
      uri.toString(),
      options: Options(
        headers: _headers('application/octet-stream'),
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (status) => status == 200 || status == 302,
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return response.data!;
    }
    final location = Uri.tryParse(response.headers.value('location') ?? '');
    if (location == null ||
        location.scheme != 'https' ||
        !location.host.endsWith('.githubusercontent.com') ||
        location.userInfo.isNotEmpty) {
      throw const FormatException('Untrusted release redirect.');
    }
    final redirected = await _dio.get<ResponseBody>(
      location.toString(),
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (status) => status == 200,
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    if (redirected.data == null) {
      throw const FormatException('Empty release asset.');
    }
    return redirected.data!;
  }

  static Map<String, dynamic> _asset(List<dynamic> assets, String name) {
    for (final item in assets) {
      if (item is Map<String, dynamic> && item['name'] == name) return item;
    }
    throw FormatException('Release asset missing: $name');
  }

  static Uri _assetApiUrl(Map<String, dynamic> asset) {
    final raw = asset['url'];
    if (raw is! String) throw const FormatException('Invalid release URL.');
    final uri = Uri.tryParse(raw);
    final id = asset['id'];
    if (uri == null ||
        id is! int ||
        id <= 0 ||
        uri.scheme != 'https' ||
        uri.host != 'api.github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.path != '/repos/$_repository/releases/assets/$id') {
      throw const FormatException('Untrusted release URL.');
    }
    return uri;
  }
}

int compareVersions(String left, String right) {
  final expression = RegExp(r'^\d+\.\d+\.\d+$');
  if (!expression.hasMatch(left) || !expression.hasMatch(right)) {
    throw const FormatException('Invalid app version.');
  }
  final a = left.split('.').map(int.parse).toList();
  final b = right.split('.').map(int.parse).toList();
  for (var index = 0; index < 3; index++) {
    if (a[index] != b[index]) return a[index].compareTo(b[index]);
  }
  return 0;
}

String checksumForAsset(String body, String name) {
  for (final line in const LineSplitter().convert(body)) {
    final match = RegExp(
      r'^([a-fA-F0-9]{64})\s+\*?(.+)$',
    ).firstMatch(line.trim());
    if (match != null && match.group(2) == name) {
      return match.group(1)!.toLowerCase();
    }
  }
  throw FormatException('Checksum missing for $name.');
}
