import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/class_provider.dart';
import '../services/unread_badge_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/guest_home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const SplashScreen();
    }

    if (auth.isGuest) {
      return const GuestHomeScreen();
    }

    if (!auth.isAuthenticated) {
      return FutureBuilder<bool>(
        future: OnboardingScreen.hasSeen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.data == true) {
            return const LoginScreen();
          }
          return const OnboardingScreen();
        },
      );
    }

    final user = auth.currentUser;
    if (user != null) {
      final classProv = context.read<ClassProvider>();
      if (user.enrolledClasses.isNotEmpty && classProv.currentClass == 'Global / General Assembly') {
        classProv.setFromEnrolled(user.enrolledClasses);
      }

      final badgeProv = context.read<UnreadBadgeProvider>();
      badgeProv.init(
        auth.currentUserId,
        user.registrationNumber,
        user.enrolledClasses,
        classProv.currentClass,
      );

      return user.isAdmin ? const AdminHomeScreen() : const HomeScreen();
    }

    return const LoginScreen();
  }
}
