// SPDX-License-Identifier: AGPL-3.0-or-Later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _prefAutoReminders = 'auto_reminders_enabled';

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );
  }

  void _onSelectNotification(NotificationResponse response) {
    debugPrint('Notification clicked: ${response.payload}');
    if (response.payload != null && response.payload!.startsWith('install:')) {
      final filePath = response.payload!.substring('install:'.length);
      _openApk(filePath);
    }
    // Vibrate triple-pulse on any class reminder tap
    if (response.payload != null && response.payload!.startsWith('class:')) {
      _vibrateTriple();
    }
  }

  /// Triple-pulse vibration pattern: 400ms vibrate, 200ms pause, repeat 3x
  Future<void> _vibrateTriple() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          pattern: [0, 400, 200, 400, 200, 400],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      }
    } catch (_) {
      // Fallback: use HapticFeedback
      try {
        for (int i = 0; i < 3; i++) {
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 600));
        }
      } catch (_) {}
    }
  }

  Future<void> _openApk(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        debugPrint('Failed to open APK from notification: ${result.message}');
      }
    } catch (e) {
      debugPrint('Error opening APK from notification: $e');
    }
  }

  // ── Auto-reminder scheduling ────────────────────────────────

  bool _autoRemindersEnabled = true;

  bool get autoRemindersEnabled => _autoRemindersEnabled;

  Future<void> loadAutoReminderPref() async {
    final prefs = await SharedPreferences.getInstance();
    _autoRemindersEnabled = prefs.getBool(_prefAutoReminders) ?? true;
  }

  Future<void> setAutoRemindersEnabled(bool enabled) async {
    _autoRemindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoReminders, enabled);
    if (!enabled) {
      await cancelAllAutoReminders();
    }
  }

  /// Schedule reminders for all lessons in a class.
  /// Each lesson gets a weekly recurring notification at its scheduled start time.
  /// [lessons] from Firestore timetable subcollection.
  Future<int> autoScheduleClassReminders({
    required String className,
    required List<Map<String, dynamic>> lessons,
  }) async {
    if (!_autoRemindersEnabled) return 0;

    // Cancel existing auto reminders first
    await cancelAllAutoReminders();

    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday',
    ];

    int scheduled = 0;
    final prefs = await SharedPreferences.getInstance();
    final List<String> reminderIds = [];

    for (final lesson in lessons) {
      final dayStr = lesson['day'] as String? ?? '';
      final timeStr = lesson['time'] as String? ?? '';
      final unit = lesson['unit'] as String? ?? '';
      final room = lesson['room'] as String? ?? '';

      if (dayStr.isEmpty || timeStr.isEmpty || unit.isEmpty) continue;

      final dayIndex = days.indexOf(dayStr) + 1;
      if (dayIndex < 1 || dayIndex > 7) continue;

      // Reminder fires at the scheduled class start time.
      final start = parseLessonStartTime(timeStr);
      if (start == null) continue;
      final int hour = start.$1;
      final int minute = start.$2;

      final uniqueId = _generateReminderId(dayIndex, unit, room);
      reminderIds.add(uniqueId.toString());

      await _scheduleWeeklyReminder(
        id: uniqueId,
        title: '$unit starting now',
        body: 'Room: $room — $className',
        dayOfWeek: dayIndex,
        hour: hour,
        minute: minute,
        payload: 'class:$className:$unit:$dayStr',
      );
      scheduled++;
    }

    // Store reminder IDs for cleanup
    await prefs.setStringList('auto_reminder_ids', reminderIds);
    debugPrint('Scheduled $scheduled auto reminders for $className');
    return scheduled;
  }

  int _generateReminderId(int dayIndex, String unit, String room) {
    final hash = '$dayIndex:$unit:$room'.hashCode;
    // Use prefix 90000-99999 range for auto reminders to avoid collisions
    return 90000 + (hash.abs() % 10000);
  }

  /// Cancel all auto-scheduled class reminders
  Future<void> cancelAllAutoReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('auto_reminder_ids') ?? [];
    for (final idStr in ids) {
      final id = int.tryParse(idStr);
      if (id != null) {
        await _flutterLocalNotificationsPlugin.cancel(id: id);
      }
    }
    await prefs.remove('auto_reminder_ids');
  }

  Future<void> _scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      title: title,
      body: body,
      id: id,
      scheduledDate: _nextInstanceOfDayAndTime(dayOfWeek, hour, minute),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Automatic reminders before scheduled classes',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  // ── Manual single-lesson reminder (scheduled at class start) ──

  Future<void> scheduleClassReminder({
    required int id,
    required String className,
    required String room,
    required int dayOfWeek,
    required int hour,
    required int minute,
  }) async {
    // Fires at the scheduled class start time.
    await _scheduleWeeklyReminder(
      id: id,
      title: '$className starting now',
      body: 'Room: $room',
      dayOfWeek: dayOfWeek,
      hour: hour,
      minute: minute,
      payload: 'class:$className:$className:manual',
    );
  }

  // ── Download notifications (unchanged) ──

  Future<void> showDownloadProgressNotification({
    required int id,
    required int progress,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'apk_downloads',
      'App Updates',
      channelDescription: 'APK download progress for app updates',
      importance: Importance.low,
      priority: Priority.defaultPriority,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      autoCancel: false,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: 'Downloading Update...',
      body: progress >= 0 ? '$progress%' : 'Starting download...',
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showDownloadCompleteNotification(String filePath) async {
    final AndroidNotificationDetails androidDetails =
        const AndroidNotificationDetails(
      'apk_downloads',
      'App Updates',
      channelDescription: 'APK download progress for app updates',
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
      showProgress: false,
      ongoing: false,
      autoCancel: true,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: 9998,
      title: 'Update Downloaded',
      body: 'Tap to install the latest version of Kabete Poly',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: 'install:$filePath',
    );
  }

  Future<void> cancelDownloadNotification({List<int>? ids}) async {
    if (ids != null) {
      for (final id in ids) {
        await _flutterLocalNotificationsPlugin.cancel(id: id);
      }
    } else {
      await _flutterLocalNotificationsPlugin.cancel(id: 9999);
      await _flutterLocalNotificationsPlugin.cancel(id: 9998);
    }
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      // Exact alarm permission is required for `exactAllowWhileIdle` weekly
      // class reminders (SO 13+).
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  // ── Helpers ──

  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}

/// Parses a timetable start time string (e.g. "08:30", "1430") into
/// `(hour, minute)`, or `null` when it cannot be parsed.
(int, int)? parseLessonStartTime(String timeStr) {
  final clean = timeStr.replaceAll(RegExp(r'[^0-9]'), '');
  if (clean.length < 4) return null;
  final h = int.tryParse(clean.substring(0, 2));
  final m = int.tryParse(clean.substring(2, 4));
  if (h == null || m == null) return null;
  return (h, m);
}
