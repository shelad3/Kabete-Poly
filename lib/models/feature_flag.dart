// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';

class FeatureFlag {
  final String id;
  final String name;
  final String displayName;
  final bool enabled;
  final String description;
  final DateTime? autoDisableAt;
  final DateTime? autoEnableAt;
  final String disabledMessage;
  final List<String> allowedRoles;
  final String? lastModifiedBy;
  final DateTime? lastModifiedAt;
  final DateTime? createdAt;

  const FeatureFlag({
    required this.id,
    required this.name,
    required this.displayName,
    required this.enabled,
    this.description = '',
    this.autoDisableAt,
    this.autoEnableAt,
    this.disabledMessage = 'This feature is currently unavailable.',
    this.allowedRoles = const [],
    this.lastModifiedBy,
    this.lastModifiedAt,
    this.createdAt,
  });

  /// Returns whether the feature is effectively enabled right now,
  /// accounting for schedule-based auto-disable/enable.
  bool get isEffectivelyEnabled {
    final now = DateTime.now();
    if (autoDisableAt != null && now.isAfter(autoDisableAt!)) return false;
    if (autoEnableAt != null && now.isAfter(autoEnableAt!)) return true;
    return enabled;
  }

  bool isAllowedForRole(String role) {
    if (allowedRoles.isEmpty) return true;
    return allowedRoles.contains(role);
  }

  factory FeatureFlag.fromJson(Map<String, dynamic> json, String id) {
    return FeatureFlag(
      id: id,
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      autoDisableAt:
          (json['schedule'] as Map<String, dynamic>?)?['autoDisableAt']
              as DateTime?,
      autoEnableAt:
          (json['schedule'] as Map<String, dynamic>?)?['autoEnableAt']
              as DateTime?,
      disabledMessage:
          json['disabledMessage'] as String? ??
          'This feature is currently unavailable.',
      allowedRoles: List<String>.from(
        (json['allowedRoles'] as List<dynamic>?) ?? [],
      ),
      lastModifiedBy: json['lastModifiedBy'] as String?,
      lastModifiedAt: json['lastModifiedAt'] as DateTime?,
      createdAt: json['createdAt'] as DateTime?,
    );
  }

  factory FeatureFlag.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FeatureFlag.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'enabled': enabled,
      'description': description,
      'schedule': {
        'autoDisableAt': autoDisableAt,
        'autoEnableAt': autoEnableAt,
      },
      'disabledMessage': disabledMessage,
      'allowedRoles': allowedRoles,
      'lastModifiedBy': lastModifiedBy,
      'lastModifiedAt': FieldValue.serverTimestamp(),
      'createdAt': createdAt,
    };
  }

  FeatureFlag copyWith({
    String? name,
    String? displayName,
    bool? enabled,
    String? description,
    DateTime? autoDisableAt,
    DateTime? autoEnableAt,
    String? disabledMessage,
    List<String>? allowedRoles,
    String? lastModifiedBy,
  }) {
    return FeatureFlag(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      description: description ?? this.description,
      autoDisableAt: autoDisableAt ?? this.autoDisableAt,
      autoEnableAt: autoEnableAt ?? this.autoEnableAt,
      disabledMessage: disabledMessage ?? this.disabledMessage,
      allowedRoles: allowedRoles ?? this.allowedRoles,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      lastModifiedAt: DateTime.now(),
      createdAt: createdAt,
    );
  }
}

/// Default feature flags seeded into Firestore on first admin access.
const kDefaultFeatureFlags = <Map<String, dynamic>>[
  {
    'name': 'hostel_booking',
    'displayName': 'Hostel Booking',
    'enabled': true,
    'description': 'Student cube/hostel allocation system',
    'disabledMessage':
        'Hostel booking is currently closed. Contact administration for assistance.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'quizzes',
    'displayName': 'Quizzes',
    'enabled': true,
    'description': 'In-app quiz and assessment system',
    'disabledMessage': 'Quizzes are currently unavailable.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'forum',
    'displayName': 'Discussion Forum',
    'enabled': true,
    'description': 'Class discussion and Q&A forum',
    'disabledMessage': 'The forum is currently disabled.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'report_cards',
    'displayName': 'Report Cards',
    'enabled': true,
    'description': 'Student report card viewing',
    'disabledMessage': 'Report cards are not yet available for this term.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'grades',
    'displayName': 'Grades',
    'enabled': true,
    'description': 'Grade and assessment viewing',
    'disabledMessage': 'Grades are currently unavailable.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'timetable',
    'displayName': 'Timetable',
    'enabled': true,
    'description': 'Class timetable and schedule',
    'disabledMessage': 'Timetable is currently unavailable.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'notifications',
    'displayName': 'Notifications',
    'enabled': true,
    'description': 'Push and in-app notifications',
    'disabledMessage': 'Notifications are currently disabled.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'gallery',
    'displayName': 'Gallery',
    'enabled': true,
    'description': 'Campus photo gallery',
    'disabledMessage': 'Gallery is currently unavailable.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'campus_map',
    'displayName': 'Campus Map',
    'enabled': true,
    'description': 'Interactive campus map',
    'disabledMessage': 'Campus map is currently unavailable.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'lesson_verification',
    'displayName': 'Lesson Verification',
    'enabled': true,
    'description': 'QR-code lesson attendance verification',
    'disabledMessage': 'Lesson verification is currently disabled.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'exam_booking',
    'displayName': 'Exam Booking',
    'enabled': true,
    'description': 'Examination sitting booking system',
    'disabledMessage': 'Exam booking is currently closed.',
    'allowedRoles': <String>[],
  },
  {
    'name': 'voting',
    'displayName': 'Student Leader Voting',
    'enabled': true,
    'description': 'Encrypted student leader election voting',
    'disabledMessage': 'Voting is currently not active.',
    'allowedRoles': <String>[],
  },
];
