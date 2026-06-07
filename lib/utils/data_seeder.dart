import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_item.dart';

class DataSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Manually extracted from: V2_JAN-APRIL 2026_ELECTRICAL TIMETABLE.pdf
  // Targeting: "Jan 2026 EIT" cohort (acting as E-1E / E-1F) 
  static final List<Map<String, dynamic>> _jan2026EitSchedule = [
    // Monday
    {
      'subject': 'Digital Skills',
      'teacher': 'Jerono',
      'room': 'E-1E',
      'dayOfWeek': DateTime.monday,
      'startTime': '08:00',
      'endTime': '10:00',
      'color': Colors.blue,
      'description': 'Official Timetable',
    },
    {
      'subject': 'Technical Drawing',
      'teacher': 'Samuel Njuguna',
      'room': 'C12-F',
      'dayOfWeek': DateTime.monday,
      'startTime': '10:00',
      'endTime': '12:00',
      'color': Colors.teal,
      'description': 'Official Timetable',
    },
    {
      'subject': 'Communication Skills',
      'teacher': 'Mercy Chepkoech',
      'room': 'E-1F',
      'dayOfWeek': DateTime.monday,
      'startTime': '14:00',
      'endTime': '16:00',
      'color': Colors.orange,
      'description': 'Official Timetable',
    },
    
    // Tuesday
    {
      'subject': 'Apply Analog Electronics I',
      'teacher': 'Charles Yegon',
      'room': 'SMART CLASS',
      'dayOfWeek': DateTime.tuesday,
      'startTime': '08:00',
      'endTime': '10:00',
      'color': Colors.purple,
      'description': 'Official Timetable',
    },
    {
      'subject': 'Engineering Mathematics',
      'teacher': 'Mwaniki',
      'room': 'C12-G',
      'dayOfWeek': DateTime.tuesday,
      'startTime': '10:00',
      'endTime': '12:00',
      'color': Colors.indigo,
      'description': 'Official Timetable',
    },
    
    // Wednesday
    {
      'subject': 'Apply Basic Electrical Principles',
      'teacher': 'JOHN NJOROGE / SOME',
      'room': 'E-1F',
      'dayOfWeek': DateTime.wednesday,
      'startTime': '10:00',
      'endTime': '12:00',
      'color': Colors.amber,
      'description': 'Official Timetable',
    },
    {
      'subject': 'Engineering Technician Mathematics',
      'teacher': 'Emmamuel Mukoya',
      'room': 'E-2E',
      'dayOfWeek': DateTime.wednesday,
      'startTime': '14:00',
      'endTime': '16:00',
      'color': Colors.indigo,
      'description': 'Official Timetable',
    },
  ];

  static Future<void> seedScheduleForClass(String classId) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection('schedules');
    
    // Select the dataset
    List<Map<String, dynamic>> targetData = [];
    if (classId == 'Jan 2026 EIT') {
      targetData = _jan2026EitSchedule;
    }
    
    if (targetData.isEmpty) {
      return;
    }

    for (var data in targetData) {
      final docRef = collection.doc(); // Auto-generate ID
      final item = ScheduleItem(
        id: docRef.id,
        classId: classId,
        subject: data['subject'],
        teacher: data['teacher'],
        room: data['room'],
        startTime: data['startTime'],
        endTime: data['endTime'],
        color: data['color'] as Color,
        description: data['description'],
        date: DateTime.now(), // Irrelevant for default items, but required by model
        isDefault: true,
        dayOfWeek: data['dayOfWeek'],
      );
      
      batch.set(docRef, item.toJson());
    }

    try {
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
