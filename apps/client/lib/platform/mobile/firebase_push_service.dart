import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/database/classsync_database.dart';
import '../../core/integrations/integration_exception.dart';
import '../../core/integrations/relay/relay_client.dart';
import '../../core/security/secure_credential_store.dart';
import '../../domain/settings/app_settings.dart';
import '../../firebase_options.dart';
import 'background_sync.dart';
import 'mobile_background_policy.dart';

@pragma('vm:entry-point')
Future<void> classSyncFirebaseBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  await enqueueMobileSyncFromPush(
    eventId: message.data['eventId'],
    messageId: message.messageId,
  );
}

class FirebasePushService {
  FirebasePushService({
    required ClassSyncDatabase database,
    required SecureCredentialStore credentials,
    required RelayClient relay,
    required Future<void> Function() onEvent,
  }) : _database = database,
       _credentials = credentials,
       _relay = relay,
       _onEvent = onEvent;

  final ClassSyncDatabase _database;
  final SecureCredentialStore _credentials;
  final RelayClient _relay;
  final Future<void> Function() _onEvent;

  StreamSubscription<AppSettings>? _settingsSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  AppSettings? _settings;
  String? _registeredToken;
  Future<void> _serial = Future.value();

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    _settingsSubscription = _database.watchSettings().listen((settings) {
      _settings = settings;
      _enqueueTokenSync();
    });
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      _registeredToken = token;
      _enqueueTokenSync();
    });
    _messageSubscription = FirebaseMessaging.onMessage.listen((_) {
      unawaited(_onEvent());
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((_) {
      unawaited(_onEvent());
    });
    if (await FirebaseMessaging.instance.getInitialMessage() != null) {
      unawaited(_onEvent());
    }
  }

  void _enqueueTokenSync() {
    _serial = _serial.then((_) => _syncToken()).catchError((_) {});
  }

  Future<void> _syncToken() async {
    final settings = _settings;
    final baseUrl = settings?.relayBaseUrl;
    final bootstrapToken = await _credentials.read(
      CredentialKey.relayDeviceToken,
    );
    final accountSecret = await _credentials.read(
      CredentialKey.syncAccountAuthSecret,
    );
    final existingDevice = await _credentials.read(
      CredentialKey.relayDeviceCredential,
    );
    if (settings == null ||
        !settings.setupComplete ||
        baseUrl == null ||
        baseUrl.isEmpty ||
        (bootstrapToken?.isNotEmpty != true &&
            accountSecret?.isNotEmpty != true &&
            existingDevice?.isNotEmpty != true)) {
      return;
    }
    final deviceToken = await _relay.ensureDeviceSession(
      baseUrl: baseUrl,
      bootstrapToken: bootstrapToken ?? '',
      credentials: _credentials,
    );

    final keepPushToken = needsMobilePushToken(
      automaticSync: settings.automaticSync,
      backgroundMobileSync: settings.backgroundMobileSync,
      notificationsEnabled: settings.notificationsEnabled,
    );
    if (!keepPushToken) {
      final token =
          _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _relay.unregisterPushToken(
          baseUrl: baseUrl,
          deviceToken: deviceToken,
          pushToken: token,
        );
      }
      await FirebaseMessaging.instance.deleteToken();
      _registeredToken = null;
      return;
    }

    final token =
        _registeredToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await _relay.registerPushToken(
        baseUrl: baseUrl,
        deviceToken: deviceToken,
        pushToken: token,
      );
      _registeredToken = token;
    } on IntegrationException catch (error) {
      if (error.statusCode != 409) rethrow;
      // Rejoining can create a new relay device identity while FCM retains
      // the old installation token. Rotate locally instead of taking ownership
      // of a token registered to another identity.
      await FirebaseMessaging.instance.deleteToken();
      _registeredToken = null;
      final replacement = await FirebaseMessaging.instance.getToken();
      if (replacement == null) return;
      await _relay.registerPushToken(
        baseUrl: baseUrl,
        deviceToken: deviceToken,
        pushToken: replacement,
      );
      _registeredToken = replacement;
    }
  }

  Future<void> dispose() async {
    await _settingsSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
