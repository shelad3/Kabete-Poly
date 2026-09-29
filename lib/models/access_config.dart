// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

/// Global login/registration access rules mirrored from
/// `access_control/global` in Firestore.
class AccessConfig {
  final bool loginEnabled;
  final bool registrationEnabled;
  final List<String> loginAllowedRoles;
  final List<String> registrationAllowedRoles;
  final DateTime? updatedAt;
  final String? updatedBy;

  const AccessConfig({
    this.loginEnabled = true,
    this.registrationEnabled = true,
    this.loginAllowedRoles = const [],
    this.registrationAllowedRoles = const [],
    this.updatedAt,
    this.updatedBy,
  });

  bool get allowsAllLogin => loginAllowedRoles.isEmpty;
  bool get allowsAllRegistration => registrationAllowedRoles.isEmpty;

  bool isRoleAllowedForLogin(String role) =>
      allowsAllLogin || loginAllowedRoles.contains(role);

  bool isRoleAllowedForRegistration(String role) =>
      allowsAllRegistration || registrationAllowedRoles.contains(role);

  factory AccessConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const AccessConfig();
    return AccessConfig(
      loginEnabled: json['loginEnabled'] as bool? ?? true,
      registrationEnabled: json['registrationEnabled'] as bool? ?? true,
      loginAllowedRoles: List<String>.from(json['loginAllowedRoles'] ?? []),
      registrationAllowedRoles:
          List<String>.from(json['registrationAllowedRoles'] ?? []),
      updatedAt: (json['updatedAt'] as dynamic)?.toDate(),
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'loginEnabled': loginEnabled,
        'registrationEnabled': registrationEnabled,
        'loginAllowedRoles': loginAllowedRoles,
        'registrationAllowedRoles': registrationAllowedRoles,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };
}