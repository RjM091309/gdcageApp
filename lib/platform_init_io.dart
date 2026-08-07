// Android init when dart:io is available (mobile/desktop).

import 'dart:io' show Platform;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

import 'background_notification_task.dart';
import 'constants/feature_flags.dart';
import 'services/local_notification_service.dart';

bool get isAndroid => Platform.isAndroid;

Future<void> initAndroidIfNeeded() async {
  if (!Platform.isAndroid) return;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  if (!kNotificationsEnabled) return;
  await LocalNotificationService.instance.initialize();
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'cage-notification-check',
    'checkNotifications',
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(seconds: 30),
  );
}

/// Call when app goes to background so we check for notifications ~1 min later (Android).
Future<void> scheduleOneOffNotificationCheck() async {
  if (!kNotificationsEnabled) return;
  if (!Platform.isAndroid) return;
  await Workmanager().registerOneOffTask(
    'cage-notification-oneoff',
    'checkNotifications',
    initialDelay: const Duration(minutes: 1),
  );
}
