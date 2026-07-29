// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feature_flag.dart';

class FeatureFlagService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;
  final Map<String, FeatureFlag> _cache = {};
  final _controller = StreamController<Map<String, FeatureFlag>>.broadcast();

  Stream<Map<String, FeatureFlag>> get flagsStream => _controller.stream;

  /// Starts listening to real-time flag changes from Firestore.
  void startListening() {
    _subscription?.cancel();
    _subscription = _db.collection('feature_flags').snapshots().listen((
      snapshot,
    ) {
      for (final doc in snapshot.docs) {
        final flag = FeatureFlag.fromFirestore(doc);
        _cache[flag.name] = flag;
      }
      _controller.add(Map.unmodifiable(_cache));
    });
  }

  /// Loads all flags once (for initial startup before stream is ready).
  Future<void> loadFlags() async {
    final snapshot = await _db.collection('feature_flags').get();
    for (final doc in snapshot.docs) {
      final flag = FeatureFlag.fromFirestore(doc);
      _cache[flag.name] = flag;
    }
    _controller.add(Map.unmodifiable(_cache));
  }

  /// Checks if a feature is effectively enabled (respects schedule).
  bool isEnabled(String flagName) {
    final flag = _cache[flagName];
    if (flag == null) return true; // fail-open: unknown features are enabled
    return flag.isEffectivelyEnabled;
  }

  /// Returns the disabled message for a feature, or null if enabled.
  String? getDisabledMessage(String flagName) {
    final flag = _cache[flagName];
    if (flag == null || flag.isEffectivelyEnabled) return null;
    return flag.disabledMessage;
  }

  /// Returns a flag by name.
  FeatureFlag? getFlag(String flagName) => _cache[flagName];

  /// Returns all cached flags.
  List<FeatureFlag> getAllFlags() => _cache.values.toList();

  /// Seeds default feature flags if the collection is empty.
  Future<void> seedDefaultsIfEmpty() async {
    final snapshot = await _db.collection('feature_flags').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (final data in kDefaultFeatureFlags) {
      final ref = _db.collection('feature_flags').doc();
      batch.set(ref, {
        ...data,
        'schedule': {'autoDisableAt': null, 'autoEnableAt': null},
        'lastModifiedBy': null,
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Admin: updates a feature flag.
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
    final updateData = <String, dynamic>{
      'enabled': enabled,
      'lastModifiedBy': adminUid,
      'lastModifiedAt': FieldValue.serverTimestamp(),
    };
    if (description != null) updateData['description'] = description;
    if (disabledMessage != null) {
      updateData['disabledMessage'] = disabledMessage;
    }
    if (allowedRoles != null) updateData['allowedRoles'] = allowedRoles;
    updateData['schedule'] = {
      'autoDisableAt': autoDisableAt,
      'autoEnableAt': autoEnableAt,
    };

    await _db.collection('feature_flags').doc(flagId).update(updateData);
  }

  /// Cleans up the Firestore listener.
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
