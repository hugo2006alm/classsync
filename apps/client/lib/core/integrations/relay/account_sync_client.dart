import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../security/secure_credential_store.dart';
import '../integration_exception.dart';

enum AccountRegistrationMode { open, invite, token }

class AccountRegistrationPolicy {
  const AccountRegistrationPolicy(this.mode);

  final AccountRegistrationMode mode;
  bool get needsCredential => mode != AccountRegistrationMode.open;
}

class SyncAccount {
  const SyncAccount({
    required this.id,
    required this.authSecret,
    required this.encryptionKey,
    required this.deviceId,
  });

  final String id;
  final String authSecret;
  final String encryptionKey;
  final String deviceId;

  String get recoveryCode => 'CS1.$id.$authSecret.$encryptionKey';
  String get relaySession => 'account:$id.$authSecret.$deviceId';
}

class AccountWebhookConfig {
  const AccountWebhookConfig({
    required this.webhookUrl,
    required this.signingSecret,
    this.lastReceivedAt,
    this.lastEventType,
  });
  final String webhookUrl;
  final String signingSecret;
  final DateTime? lastReceivedAt;
  final String? lastEventType;
}

class EncryptedSnapshot {
  const EncryptedSnapshot({
    required this.revision,
    this.ciphertext,
    this.nonce,
  });
  final int revision;
  final String? ciphertext;
  final String? nonce;
  bool get exists => revision > 0 && ciphertext != null && nonce != null;
}

class AccountSyncClient {
  AccountSyncClient({Dio? dio}) : _dio = dio ?? createDio();

  final Dio _dio;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<AccountRegistrationPolicy> registrationPolicy({
    required String baseUrl,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${_base(baseUrl)}/registration',
      );
      final raw = response.data?['mode']?.toString().trim().toLowerCase();
      final mode = switch (raw) {
        'open' => AccountRegistrationMode.open,
        'invite' => AccountRegistrationMode.invite,
        'token' => AccountRegistrationMode.token,
        _ => throw const FormatException(
          'This relay returned an unsupported account registration mode.',
        ),
      };
      return AccountRegistrationPolicy(mode);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const AccountRegistrationPolicy(AccountRegistrationMode.token);
      }
      throw IntegrationException.fromDio('Device sync', error);
    }
  }

  Future<SyncAccount?> readAccount(SecureCredentialStore store) async {
    final values = await Future.wait([
      store.read(CredentialKey.syncAccountId),
      store.read(CredentialKey.syncAccountAuthSecret),
      store.read(CredentialKey.syncEncryptionKey),
      store.read(CredentialKey.syncDeviceId),
    ]);
    if (values.any((value) => value == null || value.isEmpty)) return null;
    await store.delete(CredentialKey.relayDeviceToken);
    await store.delete(CredentialKey.relayDeviceCredential);
    return SyncAccount(
      id: values[0]!,
      authSecret: values[1]!,
      encryptionKey: values[2]!,
      deviceId: values[3]!,
    );
  }

  Future<SyncAccount> createAccount({
    required String baseUrl,
    String? registrationCredential,
    String? setupToken,
    required SecureCredentialStore store,
  }) async {
    final owner = await store.read(CredentialKey.syncLocalOwnerId);
    if (owner?.isNotEmpty == true) {
      throw const FormatException(
        'This local profile already belongs to an account. Rejoin that account with its recovery code.',
      );
    }
    try {
      final credential = (registrationCredential ?? setupToken)?.trim();
      final response = await _dio.post<Map<String, dynamic>>(
        '${_base(baseUrl)}/accounts',
        options: Options(
          headers: credential?.isNotEmpty == true
              ? {'authorization': 'Bearer $credential'}
              : const {},
        ),
      );
      final data = response.data ?? const {};
      final account = SyncAccount(
        id: data['accountId'] as String,
        authSecret: data['authSecret'] as String,
        encryptionKey: _randomSecret(32),
        deviceId: const Uuid().v4(),
      );
      await _saveAccount(store, account);
      return account;
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Device sync', error);
    }
  }

  Future<SyncAccount> joinAccount({
    required String baseUrl,
    required String recoveryCode,
    required SecureCredentialStore store,
  }) async {
    final account = parseRecoveryCode(recoveryCode);
    try {
      await _dio.get<void>(
        '${_base(baseUrl)}/account/session',
        options: Options(headers: _headers(account)),
      );
      await _saveAccount(store, account);
      return account;
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Device sync', error);
    }
  }

  SyncAccount parseRecoveryCode(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4 ||
        parts[0].toUpperCase() != 'CS1' ||
        parts.skip(1).any((part) => part.length < 20)) {
      throw const FormatException('This ClassSync account code is invalid.');
    }
    return SyncAccount(
      id: parts[1],
      authSecret: parts[2],
      encryptionKey: parts[3],
      deviceId: const Uuid().v4(),
    );
  }

  Future<void> disconnect(SecureCredentialStore store) async {
    for (final key in const [
      CredentialKey.syncAccountId,
      CredentialKey.syncAccountAuthSecret,
      CredentialKey.syncEncryptionKey,
      CredentialKey.syncDeviceId,
      CredentialKey.syncConfigRevision,
      CredentialKey.syncJobsRevision,
    ]) {
      await store.delete(key);
    }
  }

  Future<AccountWebhookConfig> webhookConfig({
    required String baseUrl,
    required SyncAccount account,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${_base(baseUrl)}/account/webhook-config',
        options: Options(headers: _headers(account)),
      );
      return AccountWebhookConfig(
        webhookUrl: response.data?['webhookUrl'] as String,
        signingSecret: response.data?['signingSecret'] as String,
        lastReceivedAt: DateTime.tryParse(
          response.data?['lastReceivedAt'] as String? ?? '',
        )?.toUtc(),
        lastEventType: response.data?['lastEventType'] as String?,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Device sync', error);
    }
  }

  Future<EncryptedSnapshot> readSnapshot({
    required String baseUrl,
    required SyncAccount account,
    required String scope,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${_base(baseUrl)}/account/sync/${Uri.encodeComponent(scope)}',
        options: Options(headers: _headers(account)),
      );
      final data = response.data ?? const {};
      return EncryptedSnapshot(
        revision: (data['revision'] as num? ?? 0).toInt(),
        ciphertext: data['ciphertext'] as String?,
        nonce: data['nonce'] as String?,
      );
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Device sync', error);
    }
  }

  Future<int> writeSnapshot({
    required String baseUrl,
    required SyncAccount account,
    required String scope,
    required int baseRevision,
    required Map<String, dynamic> payload,
  }) async {
    final encrypted = await encrypt(account, payload);
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '${_base(baseUrl)}/account/sync/${Uri.encodeComponent(scope)}',
        data: {
          'baseRevision': baseRevision,
          'ciphertext': encrypted.ciphertext,
          'nonce': encrypted.nonce,
          'schemaVersion': (payload['schemaVersion'] as num?)?.toInt() ?? 1,
        },
        options: Options(headers: _headers(account)),
      );
      return (response.data?['revision'] as num).toInt();
    } on DioException catch (error) {
      throw IntegrationException.fromDio('Device sync', error);
    }
  }

  Future<Map<String, dynamic>> decrypt(
    SyncAccount account,
    EncryptedSnapshot snapshot,
  ) async {
    if (!snapshot.exists) return const {};
    try {
      final combined = base64Url.decode(
        base64Url.normalize(snapshot.ciphertext!),
      );
      if (combined.length < 17) throw const FormatException();
      final box = SecretBox(
        combined.sublist(0, combined.length - 16),
        nonce: base64Url.decode(base64Url.normalize(snapshot.nonce!)),
        mac: Mac(combined.sublist(combined.length - 16)),
      );
      final clear = await _cipher.decrypt(
        box,
        secretKey: SecretKey(_decodeKey(account.encryptionKey)),
      );
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } catch (_) {
      throw const IntegrationException(
        integration: 'Device sync',
        code: 'decrypt_failed',
        userMessage: 'The account code cannot decrypt this synced data.',
        retryable: false,
      );
    }
  }

  Future<({String ciphertext, String nonce})> encrypt(
    SyncAccount account,
    Map<String, dynamic> payload,
  ) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: SecretKey(_decodeKey(account.encryptionKey)),
    );
    return (
      ciphertext: base64UrlEncode([...box.cipherText, ...box.mac.bytes]),
      nonce: base64UrlEncode(box.nonce),
    );
  }

  Future<void> _saveAccount(
    SecureCredentialStore store,
    SyncAccount account,
  ) async {
    final owner = await store.read(CredentialKey.syncLocalOwnerId);
    if (owner != null && owner.isNotEmpty && owner != account.id) {
      throw const FormatException(
        'This local ClassSync profile belongs to another person. Use a different OS user or clear the local app profile first.',
      );
    }
    await store.writeAll({
      CredentialKey.syncAccountId: account.id,
      CredentialKey.syncAccountAuthSecret: account.authSecret,
      CredentialKey.syncEncryptionKey: account.encryptionKey,
      CredentialKey.syncDeviceId: account.deviceId,
      CredentialKey.syncLocalOwnerId: account.id,
      CredentialKey.syncConfigRevision: '0',
      CredentialKey.syncJobsRevision: '0',
    });
    await store.delete(CredentialKey.relayDeviceToken);
    await store.delete(CredentialKey.relayDeviceCredential);
  }

  Map<String, String> _headers(SyncAccount account) => {
    'authorization': 'Bearer ${account.authSecret}',
    'x-classsync-account-id': account.id,
    'x-classsync-device-id': account.deviceId,
  };

  List<int> _decodeKey(String value) =>
      base64Url.decode(base64Url.normalize(value));

  String _randomSecret(int bytes) {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(bytes, (_) => random.nextInt(256)),
    );
  }

  String _base(String value) => value.trim().replaceFirst(RegExp(r'/+$'), '');
}
