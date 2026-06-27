import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'services/auth_provider.dart';
import 'services/class_provider.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/analytics_service.dart';
import 'services/unread_badge_provider.dart';
import 'services/connectivity_provider.dart';
import 'widgets/offline_banner.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/guest_home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint('Unhandled Flutter error: ${details.exception}');
  };

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    } else {
      await Firebase.initializeApp();
    }

    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      try {
        await FirebaseFirestore.instance.enableNetwork();
      } catch (_) {}

      final NotificationService notificationService = NotificationService();
      await notificationService.init();
      await notificationService.requestPermissions();

      final PushNotificationService pushService = PushNotificationService();
      await pushService.init();
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ClassProvider()),
          ChangeNotifierProvider(create: (_) => ThemeNotifier()),
          ChangeNotifierProvider(create: (_) => UnreadBadgeProvider()),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ],
        child: const KabeteApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('Fatal error during startup: $e\n$stack');
  }
}

class KabeteApp extends StatelessWidget {
  const KabeteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final auth = context.watch<AuthProvider>();

    final (ThemeData theme, ThemeData? darkTheme, ThemeMode themeMode) = switch (themeNotifier.mode) {
      AppThemeMode.knp  => (AppTheme.knpTheme, AppTheme.darkTheme, ThemeMode.light),
      AppThemeMode.light => (AppTheme.lightTheme, AppTheme.darkTheme, ThemeMode.light),
      AppThemeMode.dark  => (AppTheme.darkTheme, null, ThemeMode.dark),
    };

    Widget home;
    if (auth.isLoading) {
      home = const SplashScreen();
    } else if (auth.isGuest) {
      home = const GuestHomeScreen();
    } else if (!auth.isAuthenticated) {
      home = FutureBuilder<bool>(
        future: OnboardingScreen.hasSeen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          return snapshot.data == true ? const LoginScreen() : const OnboardingScreen();
        },
      );
    } else {
      final user = auth.currentUser;
      if (user != null) {
        home = user.isAdmin ? const AdminHomeScreen() : const HomeScreen();
      } else {
        home = const LoginScreen();
      }
    }

    return MaterialApp(
      key: ValueKey('${auth.isAuthenticated}_${auth.isGuest}_${auth.currentUserId}'),
      title: 'Kabete Poly',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      navigatorObservers: [AnalyticsService().observer],
      home: OfflineBanner(child: home),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF0D0D1A), const Color(0xFF1A1A2E)]
                  : [const Color(0xFF1A237E), const Color(0xFF283593)],
            ),
          ),
          child: child,
        );
      },
    );
  }
}
