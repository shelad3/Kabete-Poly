import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../services/auth_provider.dart' as app_auth;
import '../services/class_provider.dart';
import '../services/unread_badge_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'admin/admin_home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;
  bool _timeout = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    try {
      await auth.currentUser?.reload().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _timeout = true);
    } catch (_) {
      // offline — use cached auth state
    }

    if (!mounted) return;
    final user = auth.currentUser;

    if (user != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 15));

        if (doc.exists && mounted) {
          final profile = UserProfile.fromJson(doc.data() as Map<String, dynamic>);
          final classProv = context.read<ClassProvider>();

          if (profile.enrolledClasses.isNotEmpty) {
            classProv.setFromEnrolled(profile.enrolledClasses);
          }

          final badgeProv = context.read<UnreadBadgeProvider>();
          badgeProv.init(
            user.uid,
            profile.registrationNumber,
            profile.enrolledClasses,
            classProv.currentClass,
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => profile.isAdmin
                  ? const AdminHomeScreen()
                  : const HomeScreen(),
            ),
          );
          return;
        }
      } catch (_) {
        // Firestore unavailable — try fallback via AuthProvider
      }

      // offline fallback: check AuthProvider's cached state
      final authProv = context.read<app_auth.AuthProvider>();
      if (authProv.isLoading) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }

      final cachedProfile = authProv.currentUser;
      if (cachedProfile != null && mounted) {
        final classProv = context.read<ClassProvider>();
        if (cachedProfile.enrolledClasses.isNotEmpty) {
          classProv.setFromEnrolled(cachedProfile.enrolledClasses);
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => cachedProfile.isAdmin
                ? const AdminHomeScreen()
                : const HomeScreen(),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() => _error = 'Could not load profile. Check your connection.');
      }
      return;
    }

    OnboardingScreen.hasSeen().then((seen) {
      if (!seen && mounted) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            );
          }
        });
      } else if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'KNP Management System',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kabete National Polytechnique\nManagement System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 1),
              if (_error != null) ...[
                Icon(Icons.wifi_off, size: 48, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _timeout = false;
                    });
                    _init();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Retry', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ] else ...[
                CircularProgressIndicator(color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(height: 8),
                Text(
                  _timeout ? 'Connection is slow...' : 'Loading...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const Spacer(flex: 1),
              Text(
                'v2.1.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
