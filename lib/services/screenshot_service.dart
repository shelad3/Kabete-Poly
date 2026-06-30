// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/services.dart';

class ScreenshotService {
  static const _channel = MethodChannel('com.kabete/screenshot');

  static Future<void> enableSecure() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {}
  }

  static Future<void> disableSecure() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {}
  }
}
