// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../screens/notification_screen.dart';

/// Holds the app-wide [navigatorKey] so non-widget code (e.g. push
/// notification tap handlers) can navigate to deep-linked screens.
class NavigationService {
  NavigationService._();

  static final NavigationService instance = NavigationService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Routes a tapped push notification to the relevant screen.
  ///
  /// The resolver honours a simple `type`/`id` payload convention sent by the
  /// push Cloud Functions (e.g. `{"type": "alert", "id": "<alertId>"}`).
  /// Unknown or empty payloads fall back to the in-app Alerts screen.
  void handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final id = data['id'];

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // Fall back to the Alerts screen so a tap is always useful even when no
    // deep-link payload is present.
    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );

    if (type == null || id == null) return;

    // TODO: route `type==lesson` etc. to the matching detail screen once the
    // push functions emit those payloads. See docs/deploy-runbook.
    switch (type) {
      case 'alert':
      case 'announcement':
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        );
        break;
      default:
        break;
    }
  }
}
