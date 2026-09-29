// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';

class TeachingMaterial {
  final String id;
  final String title;
  final String subject;
  final String level;
  final String? classId;
  final String type; // 'notes', 'past_paper', 'practical', 'checklist',
  // 'course_outline', 'book', 'timetable', 'notice', 'general'
  final String fileUrl;
  final String fileName;
  final String fileType;
  final int? fileSize;
  final String description;
  final String uploadedBy;
  final int? uploadedByRole;
  final DateTime uploadedAt;

  const TeachingMaterial({
    required this.id,
    required this.title,
    required this.subject,
    this.level = '',
    this.classId,
    this.type = 'notes',
    required this.fileUrl,
    required this.fileName,
    this.fileType = '',
    this.fileSize,
    this.description = '',
    required this.uploadedBy,
    this.uploadedByRole,
    required this.uploadedAt,
  });

  factory TeachingMaterial.fromJson(Map<String, dynamic> json, String id) {
    DateTime asDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return TeachingMaterial(
      id: id,
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      level: json['level'] as String? ?? '',
      classId: json['classId'] as String?,
      type: json['type'] as String? ?? 'notes',
      fileUrl: json['fileUrl'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileType: json['fileType'] as String? ?? '',
      fileSize: json['fileSize'] as int?,
      description: json['description'] as String? ?? '',
      uploadedBy: json['uploadedBy'] as String? ?? '',
      uploadedByRole: json['uploadedByRole'] as int?,
      uploadedAt: asDate(json['uploadedAt']),
    );
  }

  factory TeachingMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TeachingMaterial.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subject': subject,
      'level': level,
      'classId': classId,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'description': description,
      'uploadedBy': uploadedBy,
      'uploadedByRole': uploadedByRole,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }
}