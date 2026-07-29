// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';

class ExamTimetableEntry {
  final String id;
  final String classId;
  final String subject;
  final String teacher;
  final String room;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String type; // 'midterm', 'final', 'cat', 'practical'
  final String? description;
  final String? instructions;
  final int? dayOfWeek;

  const ExamTimetableEntry({
    required this.id,
    required this.classId,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.description,
    this.instructions,
    this.dayOfWeek,
  });

  factory ExamTimetableEntry.fromJson(Map<String, dynamic> json, String id) {
    return ExamTimetableEntry(
      id: id,
      classId: json['classId'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      room: json['room'] as String? ?? '',
      date: json['date'] != null
          ? (json['date'] is String
                ? DateTime.parse(json['date'])
                : (json['date'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
      startTime: json['startTime'] as String? ?? '00:00',
      endTime: json['endTime'] as String? ?? '00:00',
      type: json['type'] as String? ?? 'final',
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      dayOfWeek: json['dayOfWeek'] as int?,
    );
  }

  factory ExamTimetableEntry.fromFirestore(DocumentSnapshot doc) {
    return ExamTimetableEntry.fromJson(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'subject': subject,
      'teacher': teacher,
      'room': room,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'type': type,
      'description': description,
      'instructions': instructions,
      'dayOfWeek': dayOfWeek,
    };
  }

  String get typeLabel {
    switch (type) {
      case 'midterm':
        return 'Mid-Term';
      case 'final':
        return 'Final';
      case 'cat':
        return 'CAT';
      case 'practical':
        return 'Practical';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }
}
