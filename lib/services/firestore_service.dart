import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson.dart';
import '../models/schedule_item.dart';
import '../models/class_notification.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Lessons ---
  Stream<List<Lesson>> getLessonsStream([String? classId]) {
    Query query = _firestore.collection('lessons').orderBy('date', descending: true);
    if (classId != null && classId.isNotEmpty && classId != 'Global / General Assembly') {
      query = query.where('classId', isEqualTo: classId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return Lesson.fromJson(data);
      }).toList();
    });
  }

  Future<void> addLesson(Lesson lesson) async {
    await _firestore.collection('lessons').doc(lesson.id).set(lesson.toJson());
  }

  Future<void> updateLesson(Lesson lesson) async {
    await _firestore.collection('lessons').doc(lesson.id).update(lesson.toJson());
  }

  Future<void> deleteLesson(String lessonId) async {
    await _firestore.collection('lessons').doc(lessonId).delete();
  }

  Stream<List<ScheduleItem>> getScheduleStream(String classId, DateTime currentDate) {
    // 1. Get dynamic items for today specifically
    final startOfDay = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // For an ideal setup, we'd use a single Stream with an 'OR' query (not natively supported by Firestore).
    // Instead, we pull everything for the class and filter locally for maximum flexibility.
    
    return _firestore
        .collection('schedules')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
      final allItems = snapshot.docs.map((doc) => ScheduleItem.fromJson(doc.data(), doc.id)).toList();
      
      // Filter logic: 
      // Keep if: (Is a default recurring item matching today's DayOfWeek) 
      // OR (Is a specific dynamic item originally scheduled for today's Date)
      final filteredList = allItems.where((item) {
        if (item.isDefault) {
          return item.dayOfWeek == currentDate.weekday;
        } else {
          return item.date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) && 
                 item.date.isBefore(endOfDay);
        }
      }).toList();

      // Sort by start time natively in Dart
      filteredList.sort((a, b) => a.startTime.compareTo(b.startTime));
      return filteredList;
    });
  }

  Stream<List<ScheduleItem>> getDefaultScheduleStream(String classId) {
    return _firestore
        .collection('schedules')
        .where('classId', isEqualTo: classId)
        .where('isDefault', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) => ScheduleItem.fromJson(doc.data(), doc.id)).toList();
      items.sort((a, b) {
        if (a.dayOfWeek != b.dayOfWeek) {
          return (a.dayOfWeek ?? 0).compareTo(b.dayOfWeek ?? 0);
        }
        return a.startTime.compareTo(b.startTime);
      });
      return items;
    });
  }

  Future<void> addScheduleItem(ScheduleItem item) async {
    await _firestore.collection('schedules').add(item.toJson());
  }
  
  Future<void> deleteScheduleItem(String id) async {
    await _firestore.collection('schedules').doc(id).delete();
  }

  // --- Notifications ---
  Stream<List<ClassNotification>> getNotificationsStream(String classId) {
    return _firestore
        .collection('notifications')
        .where('classId', whereIn: [classId, 'General']) // Get specific class + global announcements
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ClassNotification.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> sendNotification(ClassNotification notification) async {
    await _firestore.collection('notifications').add(notification.toJson());
  }

  // --- Admin Stats ---
  Future<Map<String, int>> getAdminStats() async {
    try {
      final studentsSnap = await _firestore.collection('users').where('role', isEqualTo: 'Student').count().get();
      final lessonsSnap = await _firestore.collection('lessons').count().get();
      
      return {
        'students': studentsSnap.count ?? 0,
        'lessons': lessonsSnap.count ?? 0,
      };
    } catch (e) {
      return {'students': 0, 'lessons': 0};
    }
  }
}
