// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Analytics that is safe to construct on every
/// platform. Firebase Analytics has no Windows/Linux implementation, so calls
/// on those targets are simply no-ops instead of throwing.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logScreenView(String screenName) async {
    if (!isSupported) return;
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logLogin(String method) async {
    if (!isSupported) return;
    await _analytics.logLogin(loginMethod: method);
  }

  Future<void> logSignUp(String method) async {
    if (!isSupported) return;
    await _analytics.logSignUp(signUpMethod: method);
  }

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!isSupported) return;
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}
