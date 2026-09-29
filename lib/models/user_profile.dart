// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import '../utils/term_utils.dart';

class UserProfile {
  final String registrationNumber; // Also functions as Staff ID or Teacher TSC
  final String fullName;
  final String profilePhotoUrl;
  final String mobileNumber;
  final String email;
  final bool isHostelResident;
  final String role; // 'Student', 'Leader', 'Teacher', 'Official'
  final String? designation; // e.g. 'Prefect', 'HOD'
  final List<String> enrolledClasses;
  final int classChangeCount;
  final int enrolledTerm;
  final int enrolledYear;
  final String gender;
  final String nationality;
  final String accountStatus; // 'active' | 'restricted' | 'banned'
  final String? statusReason;
  final DateTime? statusUpdatedAt;

  UserProfile({
    required this.registrationNumber,
    required this.fullName,
    required this.profilePhotoUrl,
    required this.mobileNumber,
    required this.email,
    required this.isHostelResident,
    this.role = 'Student',
    this.designation,
    this.enrolledClasses = const [],
    this.classChangeCount = 0,
    int? enrolledTerm,
    int? enrolledYear,
    this.gender = '',
    this.nationality = 'Kenyan',
    this.accountStatus = 'active',
    this.statusReason,
    this.statusUpdatedAt,
  }) : enrolledTerm = enrolledTerm ?? TermUtils.getCurrentTerm(),
       enrolledYear = enrolledYear ?? TermUtils.getCurrentYear();

  bool get isAccountActive => accountStatus == 'active';
  bool get isRestricted => accountStatus == 'restricted';
  bool get isBanned => accountStatus == 'banned';

  bool get isNewStudent {
    final currentTerm = TermUtils.getCurrentTerm();
    final currentYear = TermUtils.getCurrentYear();
    return enrolledTerm == currentTerm && enrolledYear == currentYear;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      registrationNumber: json['registrationNumber'] ?? '',
      fullName: json['fullName'] ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      email: json['email'] ?? '',
      isHostelResident: json['isHostelResident'] ?? false,
      role: json['role'] ?? 'Student',
      designation: json['designation'],
      enrolledClasses: List<String>.from(json['enrolledClasses'] ?? []),
      classChangeCount: json['classChangeCount'] ?? 0,
      enrolledTerm: json['enrolledTerm'],
      enrolledYear: json['enrolledYear'],
      gender: json['gender'] ?? '',
      nationality: json['nationality'] ?? 'Kenyan',
      accountStatus: json['accountStatus'] ?? 'active',
      statusReason: json['statusReason'],
      statusUpdatedAt: (json['statusUpdatedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registrationNumber': registrationNumber,
      'fullName': fullName,
      'profilePhotoUrl': profilePhotoUrl,
      'mobileNumber': mobileNumber,
      'email': email,
      'isHostelResident': isHostelResident,
      'role': role,
      'designation': designation,
      'enrolledClasses': enrolledClasses,
      'classChangeCount': classChangeCount,
      'enrolledTerm': enrolledTerm,
      'enrolledYear': enrolledYear,
      'gender': gender,
      'nationality': nationality,
      'accountStatus': accountStatus,
      'statusReason': statusReason,
      'statusUpdatedAt': statusUpdatedAt,
    };
  }

  bool get canChangeClass => classChangeCount < 2;
  int get classChangesRemaining => 2 - classChangeCount;

  // Helper getters
  bool get isAdmin => role == 'Official';
  bool get isTeacher => role == 'Teacher' || role == 'Official';
  bool get isLeader => role == 'Leader';
}
