// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';

class WaitlistEntry {
  final String id;
  final String studentId;
  final String studentName;
  final String cubeId;
  final String houseName;
  final int cubeNumber;
  final int term;
  final int year;
  final int position;
  final String status; // 'waiting', 'promoted', 'expired'
  final DateTime joinedAt;
  final DateTime? promotedAt;

  const WaitlistEntry({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.cubeId,
    required this.houseName,
    required this.cubeNumber,
    required this.term,
    required this.year,
    required this.position,
    required this.status,
    required this.joinedAt,
    this.promotedAt,
  });

  factory WaitlistEntry.fromJson(Map<String, dynamic> json, String id) {
    return WaitlistEntry(
      id: id,
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      cubeId: json['cubeId'] as String? ?? '',
      houseName: json['houseName'] as String? ?? '',
      cubeNumber: json['cubeNumber'] as int? ?? 0,
      term: json['term'] as int? ?? 0,
      year: json['year'] as int? ?? 0,
      position: json['position'] as int? ?? 0,
      status: json['status'] as String? ?? 'waiting',
      joinedAt: json['joinedAt'] != null
          ? (json['joinedAt'] as dynamic).toDate() as DateTime
          : DateTime.now(),
      promotedAt: json['promotedAt'] != null
          ? (json['promotedAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  factory WaitlistEntry.fromFirestore(DocumentSnapshot doc) {
    return WaitlistEntry.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'cubeId': cubeId,
      'houseName': houseName,
      'cubeNumber': cubeNumber,
      'term': term,
      'year': year,
      'position': position,
      'status': status,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'promotedAt': promotedAt != null ? Timestamp.fromDate(promotedAt!) : null,
    };
  }

  String get positionLabel {
    switch (position) {
      case 1:
        return '1st in queue';
      case 2:
        return '2nd in queue';
      case 3:
        return '3rd in queue';
      default:
        return '${position}th in queue';
    }
  }
}
