import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'services/auth_provider.dart';
import 'services/class_provider.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/analytics_service.dart';
import 'services/unread_badge_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final GoogleMapsFlutterPlatform mapsPlatform = GoogleMapsFlutterPlatform.instance;
  if (mapsPlatform is GoogleMapsFlutterAndroid) {
    mapsPlatform.useAndroidViewSurface = false;
  }

  await Firebase.initializeApp();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  try {
    await FirebaseFirestore.instance.enableNetwork();
  } catch (_) {
    // offline — Firestore will use local cache
  }

  final NotificationService notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  final PushNotificationService pushService = PushNotificationService();
  await pushService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ClassProvider()),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => UnreadBadgeProvider()),
      ],
      child: const KabeteApp(),
    ),
  );
}

class KabeteApp extends StatelessWidget {
  const KabeteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    return MaterialApp(
      title: 'Kabete Poly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      navigatorObservers: [AnalyticsService().observer],
      home: const SplashScreen(),
    );
  }
}
