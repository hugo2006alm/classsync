import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/database/classsync_database.dart';
import '../../core/integrations/relay/relay_client.dart';
import '../../core/security/secure_credential_store.dart';
import '../../domain/settings/app_settings.dart';
import '../../firebase_options.dart';
import 'background_sync.dart';

@pragma('vm:entry-point')
Future<void> classSyncFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  await enqueueMobileSyncFromPush();
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
    if (settings == null ||
        !settings.setupComplete ||
        baseUrl == null ||
        baseUrl.isEmpty ||
        bootstrapToken == null ||
        bootstrapToken.isEmpty) {
      return;
    }
    final deviceToken = await _relay.ensureDeviceSession(
      baseUrl: baseUrl,
      bootstrapToken: bootstrapToken,
      credentials: _credentials,
    );

    if (!settings.notificationsEnabled) {
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

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: false,
    );
    final token =
        _registeredToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _relay.registerPushToken(
      baseUrl: baseUrl,
      deviceToken: deviceToken,
      pushToken: token,
    );
    _registeredToken = token;
  }

  Future<void> dispose() async {
    await _settingsSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
