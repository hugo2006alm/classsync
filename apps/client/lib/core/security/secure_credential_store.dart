import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum CredentialKey {
  firefliesApiKey('fireflies_api_key'),
  geminiApiKey('gemini_api_key'),
  notionToken('notion_token'),
  relayDeviceToken('relay_device_token'),
  relayDeviceCredential('relay_device_credential'),
  syncAccountId('sync_account_id'),
  syncAccountAuthSecret('sync_account_auth_secret'),
  syncEncryptionKey('sync_encryption_key'),
  syncDeviceId('sync_device_id'),
  syncLocalOwnerId('sync_local_owner_id'),
  syncConfigRevision('sync_config_revision'),
  syncJobsRevision('sync_jobs_revision');

  const CredentialKey(this.storageKey);
  final String storageKey;
}

class SecureCredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read(CredentialKey key) => _storage.read(key: key.storageKey);

  Future<void> write(CredentialKey key, String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await delete(key);
      return;
    }
    await _storage.write(key: key.storageKey, value: normalized);
  }

  Future<void> delete(CredentialKey key) =>
      _storage.delete(key: key.storageKey);

  Future<bool> isConfigured(CredentialKey key) async =>
      (await read(key))?.isNotEmpty ?? false;
}
