// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/foundation.dart';

import '../models/access_config.dart';
import '../services/access_control_service.dart';

class AccessControlProvider extends ChangeNotifier {
  final AccessControlService _service = AccessControlService();
  AccessConfig _config = const AccessConfig();
  bool _loaded = false;

  AccessConfig get config => _config;
  bool get isLoaded => _loaded;

  bool get loginEnabled => _config.loginEnabled;
  bool get registrationEnabled => _config.registrationEnabled;

  Future<void> init() async {
    _config = await _service.fetchConfig();
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    _config = await _service.fetchConfig();
    notifyListeners();
  }

  Future<void> save({
    required bool loginEnabled,
    required bool registrationEnabled,
    List<String>? loginAllowedRoles,
    List<String>? registrationAllowedRoles,
    required String adminUid,
  }) async {
    await _service.updateConfig(
      loginEnabled: loginEnabled,
      registrationEnabled: registrationEnabled,
      loginAllowedRoles: loginAllowedRoles,
      registrationAllowedRoles: registrationAllowedRoles,
      adminUid: adminUid,
    );
    await refresh();
  }
}