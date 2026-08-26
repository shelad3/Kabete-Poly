// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Installs global handlers that forward uncaught Flutter and Dart
/// exceptions to Firebase Crashlytics. Must be called after
/// `Firebase.initializeApp()` and before `runApp()`.
void setupCrashReporting() {
  if (kIsWeb) {
    return;
  }
  final crashlytics = FirebaseCrashlytics.instance;
  FlutterError.onError = (details) {
    debugPrint('Unhandled Flutter error: ${details.exception}');
    try {
      crashlytics.recordFlutterFatalError(details);
    } catch (_) {}
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      crashlytics.recordError(error, stack, fatal: true);
    } catch (_) {}
    return true;
  };
}

/// Records a non-fatal error, e.g. from a caught Firestore write failure.
void reportError(Object error, StackTrace stack, {String? reason}) {
  if (kIsWeb) {
    return;
  }
  try {
    final crashlytics = FirebaseCrashlytics.instance;
    if (reason != null) {
      crashlytics.setCustomKey('reason', reason);
    }
    crashlytics.recordError(error, stack, fatal: false);
  } catch (_) {}
}
