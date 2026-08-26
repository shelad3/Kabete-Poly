// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

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
import 'guest_home_screen.dart';
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

    final authProv = context.read<app_auth.AuthProvider>();
    if (authProv.isGuest) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GuestHomeScreen()),
      );
      return;
    }

    final user = auth.currentUser;

    if (user != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 15));

        if (doc.exists && mounted) {
          final profile = UserProfile.fromJson(
            doc.data() as Map<String, dynamic>,
          );
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
        setState(
          () => _error = 'Could not load profile. Check your connection.',
        );
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary,
              Color.lerp(primary, Colors.black, 0.18)!,
              Color.lerp(primary, Colors.black, 0.38)!,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school_rounded, size: 72, color: Colors.white),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Kabete National Polytechnique',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                height: 3,
                width: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8F00),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bidii Na Uaminifu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  letterSpacing: 2.5,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 1),
              if (_error != null) ...[
                Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
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
                  label: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 34,
                  width: 34,
                  child: CircularProgressIndicator(
                    color: Colors.white.withValues(alpha: 0.9),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _timeout ? 'Connection is slow...' : 'Loading your portal...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const Spacer(flex: 1),
              Text(
                'v2.7.1',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1,
                  color: Colors.white.withValues(alpha: 0.45),
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
