import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Default config assuming Nairobi or system local
    tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // v18+ named parameter strict signature (now called setup or something, wait. flutter analyze said 'settings')
    await _flutterLocalNotificationsPlugin.initialize(
       settings: initializationSettings,
       onDidReceiveNotificationResponse: _onSelectNotification,
    );
  }

  void _onSelectNotification(NotificationResponse response) {
    debugPrint('Notification clicked with payload: ${response.payload}');
    if (response.payload != null && response.payload!.startsWith('install:')) {
      final filePath = response.payload!.substring('install:'.length);
      // Attempt installation when notification is tapped
      _openApk(filePath);
    }
  }

  Future<void> _openApk(String filePath) async {
    try {
      // Dynamic import to avoid circular dependency
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        debugPrint('Failed to open APK from notification: ${result.message}');
      }
    } catch (e) {
      debugPrint('Error opening APK from notification: $e');
    }
  }

  /// Show a persistent download progress notification
  Future<void> showDownloadProgressNotification({
    required int id,
    required int progress,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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

  /// Show notification that download is complete and ready to install
  Future<void> showDownloadCompleteNotification(String filePath) async {
    final AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
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

  /// Cancel download notifications. Pass specific [ids] or cancel all.
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

  /// Request permissions on Android 13+
  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// Schedule a generic notification for a class
  /// [dayOfWeek] 1 = Monday, 7 = Sunday
  /// [timeStr] formatted like "0800"
  Future<void> scheduleClassReminder({
    required int id,
    required String className,
    required String room,
    required int dayOfWeek,
    required int hour,
    required int minute,
  }) async {
    
    // Create the Daily 08:00 AM Agenda Alert
    await _scheduleWeeklyAtDayAndTime(
        id: id * 10,
        title: 'Daily Class Briefing',
        body: 'You have $className today in $room.',
        dayOfWeek: dayOfWeek,
        hour: 8,
        minute: 0,
    );

    // Create the 30-Minute prior 'Urgent' alert
    int reminderHour = hour;
    int reminderMinute = minute - 30;
    if (reminderMinute < 0) {
      reminderMinute += 60;
      reminderHour -= 1;
    }

    await _scheduleWeeklyAtDayAndTime(
        id: (id * 10) + 1,
        title: 'Class Starting Soon!',
        body: '$className begins in 30 minutes at $room.',
        dayOfWeek: dayOfWeek,
        hour: reminderHour,
        minute: reminderMinute,
    );
  }

  Future<void> _scheduleWeeklyAtDayAndTime({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required int hour,
    required int minute,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      title: title,
      body: body,
      id: id,
      scheduledDate: _nextInstanceOfDayAndTime(dayOfWeek, hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Notifications for upcoming scheduled classes',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
