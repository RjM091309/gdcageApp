import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'constants/api_config.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final res = await http.get(Uri.parse(notificationsApiUrl), headers: headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return true;
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      final list = json?['notifications'] as List<dynamic>?;
      if (list == null || list.isEmpty) return true;

      final unread = list.where((e) => e is Map && e['read'] != true).toList();
      if (unread.isEmpty) return true;

      final plugin = FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(
        settings: const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (_) {},
      );
      const channel = AndroidNotificationChannel(
        'cage_app_notifications',
        'Golden Dragon',
        description: 'Executive dashboard alerts',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      );
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final latest = unread.first as Map<String, dynamic>;
      final title = latest['title']?.toString() ?? 'Notification';
      final body = latest['message']?.toString() ?? '';
      const details = AndroidNotificationDetails(
        'cage_app_notifications',
        'Golden Dragon',
        channelDescription: 'Executive dashboard alerts',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        enableVibration: true,
      );
      final notifTitle = unread.length > 1 ? 'You have ${unread.length} unread notifications' : title;
      final notifBody = unread.length > 1 ? (body.isEmpty ? 'Open app to view.' : body) : body;
      await plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(0x7FFFFFFF),
        title: notifTitle,
        body: notifBody,
        notificationDetails: const NotificationDetails(android: details),
      );
    } catch (_) {}
    return true;
  });
}
