import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows system notifications on Android (status bar + device sound) when app
/// is in background or screen is off. Uses device default notification sound.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const _channelId = 'cage_app_notifications';
  static const _channelName = 'Golden Dragon';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Call from main() when app starts (Android only). Requests permission on Android 13+.
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Executive dashboard alerts',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Show a system notification with device default sound. No-op on non-Android / web.
  Future<void> show({required String title, required String body}) async {
    if (!Platform.isAndroid) return;
    if (!_initialized) return;

    const details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Executive dashboard alerts',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
    );
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(0x7FFFFFFF),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: details),
    );
  }
}
