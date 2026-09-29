import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/settings/fireflies_connection.dart';

enum CredentialKey {
  firefliesApiKey('fireflies_api_key'),
  firefliesConnections('fireflies_connections'),
  geminiApiKey('gemini_api_key'),
  notionToken('notion_token'),
  portalUsername('portal_username'),
  portalPassword('portal_password'),
  moodleToken('moodle_token'),
  relayDeviceToken('relay_device_token'),
  relayDeviceCredential('relay_device_credential'),
  syncAccountId('sync_account_id'),
  syncAccountAuthSecret('sync_account_auth_secret'),
  syncEncryptionKey('sync_encryption_key'),
  syncDeviceId('sync_device_id'),
  syncLocalOwnerId('sync_local_owner_id'),
  syncConfigRevision('sync_config_revision'),
  syncJobsRevision('sync_jobs_revision'),
  githubReleaseToken('github_release_token');

  const CredentialKey(this.storageKey);
  final String storageKey;
}

class SecureCredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read(CredentialKey key) => _storage.read(key: key.storageKey);

  Future<void> write(CredentialKey key, String value) async {
    final normalized = key == CredentialKey.portalPassword
        ? value
        : value.trim();
    if (normalized.isEmpty) {
      await delete(key);
      return;
    }
    await _storage.write(key: key.storageKey, value: normalized);
  }

  Future<void> writeAll(Map<CredentialKey, String> values) async {
    for (final entry in values.entries) {
      await write(entry.key, entry.value);
    }
  }

  Future<List<FirefliesConnection>> readFirefliesConnections() async {
    final encoded = await read(CredentialKey.firefliesConnections);
    if (encoded?.isNotEmpty == true) {
      try {
        final decoded = jsonDecode(encoded!);
        if (decoded is List) {
          final connections = decoded
              .whereType<Map<String, dynamic>>()
              .map(FirefliesConnection.fromJson)
              .toList();
          if (connections.isNotEmpty &&
              connections.length <= FirefliesConnection.maxConnections &&
              connections.map((item) => item.id).toSet().length ==
                  connections.length) {
            return connections;
          }
        }
      } on FormatException {
        // Fall back to the v1 primary key below.
      }
    }
    final legacy = await read(CredentialKey.firefliesApiKey);
    if (legacy?.isNotEmpty != true) return const [];
    return [
      FirefliesConnection(
        id: FirefliesConnection.legacyId,
        name: 'Primary',
        apiKey: legacy!,
      ),
    ];
  }

  Future<void> writeFirefliesConnections(
    List<FirefliesConnection> connections,
  ) async {
    final accountIds = connections
        .map((item) => item.firefliesUserId)
        .whereType<String>()
        .toList();
    if (connections.length > FirefliesConnection.maxConnections ||
        connections.map((item) => item.id).toSet().length !=
            connections.length ||
        accountIds.toSet().length != accountIds.length) {
      throw const FormatException(
        'Use at most 20 Fireflies sources with unique source and account IDs.',
      );
    }
    for (final connection in connections) {
      connection.validate();
    }
    await write(
      CredentialKey.firefliesConnections,
      jsonEncode(connections.map((item) => item.toJson()).toList()),
    );
    if (connections.isEmpty) {
      await delete(CredentialKey.firefliesApiKey);
    } else {
      await write(CredentialKey.firefliesApiKey, connections.first.apiKey);
    }
  }

  Future<void> delete(CredentialKey key) =>
      _storage.delete(key: key.storageKey);

  Future<bool> isConfigured(CredentialKey key) async =>
      key == CredentialKey.firefliesApiKey
      ? (await readFirefliesConnections()).isNotEmpty
      : (await read(key))?.isNotEmpty ?? false;
}
