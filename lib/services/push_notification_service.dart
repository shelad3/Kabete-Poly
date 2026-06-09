import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  String? _fcmToken;
  bool _initialized = false;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openSubscription;

  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _requestPermission();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotif.initialize(
      settings: InitializationSettings(android: androidSettings),
    );

    _fcmToken = await _fcm.getToken();

    _tokenSubscription = _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
    });

    _messageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _openSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    _openSubscription?.cancel();
  }

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');
  }

  Future<void> saveTokenToFirestore(String userId) async {
    if (_fcmToken == null) return;
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
    }, SetOptions(merge: true));
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    if (notification != null) {
      _localNotif.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'push_notifications',
            'Push Notifications',
            channelDescription: 'Server push notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
  }
}
