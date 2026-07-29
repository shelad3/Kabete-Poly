// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/feature_flag.dart';
import '../services/feature_flag_service.dart';

class FeatureFlagProvider extends ChangeNotifier {
  final FeatureFlagService _service = FeatureFlagService();
  StreamSubscription<Map<String, FeatureFlag>>? _subscription;
  Map<String, FeatureFlag> _flags = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Call on app startup before rendering the UI.
  Future<void> init() async {
    await _service.seedDefaultsIfEmpty();
    await _service.loadFlags();
    _flags = {for (final flag in _service.getAllFlags()) flag.name: flag};
    _flags = Map.unmodifiable(_flags);
    _loaded = true;
    notifyListeners();

    // Start real-time listener for subsequent updates.
    _service.startListening();
    _subscription = _service.flagsStream.listen((flags) {
      _flags = flags;
      notifyListeners();
    });
  }

  /// Whether a feature is effectively enabled right now.
  bool isEnabled(String flagName) {
    final flag = _flags[flagName];
    if (flag == null) return true;
    return flag.isEffectivelyEnabled;
  }

  /// Returns the disabled message, or null if the feature is enabled.
  String? getDisabledMessage(String flagName) {
    final flag = _flags[flagName];
    if (flag == null || flag.isEffectivelyEnabled) return null;
    return flag.disabledMessage;
  }

  /// Returns a specific flag.
  FeatureFlag? getFlag(String flagName) => _flags[flagName];

  /// Returns all flags as a list.
  List<FeatureFlag> getAllFlags() => _flags.values.toList();

  /// Admin: update a flag.
  Future<void> updateFlag({
    required String flagId,
    required String flagName,
    required bool enabled,
    String? description,
    String? disabledMessage,
    DateTime? autoDisableAt,
    DateTime? autoEnableAt,
    List<String>? allowedRoles,
    required String adminUid,
  }) async {
    await _service.updateFlag(
      flagId: flagId,
      flagName: flagName,
      enabled: enabled,
      description: description,
      disabledMessage: disabledMessage,
      autoDisableAt: autoDisableAt,
      autoEnableAt: autoEnableAt,
      allowedRoles: allowedRoles,
      adminUid: adminUid,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
