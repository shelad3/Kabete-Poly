import 'package:flutter/material.dart';

class ScheduleItem {
  final String id;
  final String classId; // Maps to enrolledClasses like "Jan 2026 EIT/EET"
  final String subject;
  final String teacher;
  final String room;
  final String startTime; // Format "HH:MM" e.g. "08:00"
  final String endTime;
  final Color color;
  final String description;
  final DateTime date;
  final bool isDefault; // True if from the official unchangeable PDF timetable
  final int? dayOfWeek; // 1 (Monday) to 7 (Sunday) for recurring official classes
  final String? attachmentUrl;
  final String? attachmentName;

  ScheduleItem({
    required this.id,
    required this.classId,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.description,
    required this.date,
    this.isDefault = false,
    this.dayOfWeek,
    this.attachmentUrl,
    this.attachmentName,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json, String id) {
    return ScheduleItem(
      id: id,
      classId: json['classId'] ?? 'General',
      subject: json['subject'] ?? '',
      teacher: json['teacher'] ?? '',
      room: json['room'] ?? '',
      startTime: json['startTime'] ?? '00:00',
      endTime: json['endTime'] ?? '00:00',
      color: Color(json['colorValue'] ?? Colors.blue.toARGB32()),
      description: json['description'],
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      isDefault: json['isDefault'] ?? false,
      dayOfWeek: json['dayOfWeek'],
      attachmentUrl: json['attachmentUrl'],
      attachmentName: json['attachmentName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'subject': subject,
      'teacher': teacher,
      'room': room,
      'startTime': startTime,
      'endTime': endTime,
      'colorValue': color.toARGB32(),
      'description': description,
      'date': date.toIso8601String(),
      'isDefault': isDefault,
      'dayOfWeek': dayOfWeek,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
    };
  }

  // Helper to get duration as a double for the progress bar
  double getProgress(DateTime now) {
    if (now.year != date.year || now.month != date.month || now.day != date.day) {
      return now.isAfter(date) ? 1.0 : 0.0;
    }

    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    
    final start = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
    final end = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));

    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;

    final totalMinutes = end.difference(start).inMinutes;
    final elapsedMinutes = now.difference(start).inMinutes;

    if (totalMinutes == 0) return 1.0;
    return elapsedMinutes / totalMinutes;
  }
}
