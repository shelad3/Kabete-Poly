// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/access_config.dart';

/// Reads/writes the global `access_control/global` document that admins use
/// to gate login and registration (globally and per role).
class AccessControlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const path = 'access_control/global';

  Future<AccessConfig> fetchConfig() async {
    try {
      final doc = await _firestore
          .collection('access_control')
          .doc('global')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
      if (doc.exists) {
        return AccessConfig.fromJson(doc.data());
      }
    } catch (e) {
      debugPrint('AccessConfig read failed (fail-open): $e');
    }
    return const AccessConfig();
  }

  Future<void> updateConfig({
    required bool loginEnabled,
    required bool registrationEnabled,
    List<String>? loginAllowedRoles,
    List<String>? registrationAllowedRoles,
    required String adminUid,
  }) async {
    final data = <String, dynamic>{
      'loginEnabled': loginEnabled,
      'registrationEnabled': registrationEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': adminUid,
    };
    if (loginAllowedRoles != null) {
      data['loginAllowedRoles'] = loginAllowedRoles;
    }
    if (registrationAllowedRoles != null) {
      data['registrationAllowedRoles'] = registrationAllowedRoles;
    }
    await _firestore
        .collection('access_control')
        .doc('global')
        .set(data, SetOptions(merge: true));
  }
}