// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';

class Exam {
  final String id;
  final String title;
  final String type; // 'midterm', 'final', 'cat', 'supplementary'
  final String classId;
  final DateTime registrationDeadline;
  final DateTime startDate;
  final DateTime endDate;
  final bool registrationOpen;
  final int maxSeats;
  final int registeredCount;
  final DateTime? createdAt;

  const Exam({
    required this.id,
    required this.title,
    required this.type,
    required this.classId,
    required this.registrationDeadline,
    required this.startDate,
    required this.endDate,
    this.registrationOpen = true,
    this.maxSeats = 200,
    this.registeredCount = 0,
    this.createdAt,
  });

  bool get isRegistrationOpen {
    final now = DateTime.now();
    return registrationOpen &&
        now.isBefore(registrationDeadline) &&
        registeredCount < maxSeats;
  }

  bool get hasStarted => DateTime.now().isAfter(startDate);
  bool get hasEnded => DateTime.now().isAfter(endDate);

  int get availableSeats => maxSeats - registeredCount;

  factory Exam.fromJson(Map<String, dynamic> json, String id) {
    return Exam(
      id: id,
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'final',
      classId: json['classId'] as String? ?? '',
      registrationDeadline: json['registrationDeadline'] != null
          ? (json['registrationDeadline'] as dynamic).toDate() as DateTime
          : DateTime.now(),
      startDate: json['startDate'] != null
          ? (json['startDate'] as dynamic).toDate() as DateTime
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? (json['endDate'] as dynamic).toDate() as DateTime
          : DateTime.now(),
      registrationOpen: json['registrationOpen'] as bool? ?? true,
      maxSeats: json['maxSeats'] as int? ?? 200,
      registeredCount: json['registeredCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  factory Exam.fromFirestore(DocumentSnapshot doc) {
    return Exam.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      'classId': classId,
      'registrationDeadline': Timestamp.fromDate(registrationDeadline),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'registrationOpen': registrationOpen,
      'maxSeats': maxSeats,
      'registeredCount': registeredCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get typeLabel {
    switch (type) {
      case 'midterm':
        return 'Mid-Term';
      case 'final':
        return 'Final Exam';
      case 'cat':
        return 'CAT';
      case 'supplementary':
        return 'Supplementary';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }
}

class ExamBooking {
  final String id;
  final String studentId;
  final String examId;
  final List<String> registeredCourseIds;
  final String status; // 'registered', 'confirmed', 'pending'
  final DateTime registeredAt;

  const ExamBooking({
    required this.id,
    required this.studentId,
    required this.examId,
    required this.registeredCourseIds,
    required this.status,
    required this.registeredAt,
  });

  factory ExamBooking.fromJson(Map<String, dynamic> json, String id) {
    return ExamBooking(
      id: id,
      studentId: json['studentId'] as String? ?? '',
      examId: json['examId'] as String? ?? '',
      registeredCourseIds: List<String>.from(
        (json['registeredCourseIds'] as List<dynamic>?) ?? [],
      ),
      status: json['status'] as String? ?? 'pending',
      registeredAt: json['registeredAt'] != null
          ? (json['registeredAt'] as dynamic).toDate() as DateTime
          : DateTime.now(),
    );
  }

  factory ExamBooking.fromFirestore(DocumentSnapshot doc) {
    return ExamBooking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'examId': examId,
      'registeredCourseIds': registeredCourseIds,
      'status': status,
      'registeredAt': Timestamp.fromDate(registeredAt),
    };
  }
}
