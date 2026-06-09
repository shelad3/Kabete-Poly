import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'services/auth_provider.dart';
import 'services/class_provider.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/analytics_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school, size: 80, color: Color(0xFF1A237E)),
                    SizedBox(height: 24),
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          }
          if (auth.isAuthenticated) {
            if (auth.currentUser?.isAdmin == true) {
              return const AdminHomeScreen();
            }
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
