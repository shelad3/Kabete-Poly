import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson.dart';
import '../models/schedule_item.dart';
import '../models/class_notification.dart';
import '../models/ticket.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Lessons ---
  Stream<List<Lesson>> getLessonsStream([String? classId]) {
    Query query = _firestore.collection('lessons').orderBy('date', descending: true).limit(200);
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

  Future<String> addLesson(Lesson lesson) async {
    final doc = await _firestore.collection('lessons').add(lesson.toJson());
    return doc.id;
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

  Stream<List<ScheduleItem>> getScheduleTimelineStream(String classId) {
    return _firestore
        .collection('schedules')
        .where('classId', isEqualTo: classId)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ScheduleItem.fromJson(doc.data(), doc.id)).toList());
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
      final helpRequestsSnap = await _firestore.collection('help_requests').where('status', isEqualTo: 'pending').count().get();
      final classChangeSnap = await _firestore.collection('class_change_requests').where('status', isEqualTo: 'pending').count().get();
      final errorReportsSnap = await _firestore.collection('error_reports').where('status', isEqualTo: 'pending').count().get();
      
      return {
        'students': studentsSnap.count ?? 0,
        'lessons': lessonsSnap.count ?? 0,
        'tickets': (helpRequestsSnap.count ?? 0) + (classChangeSnap.count ?? 0) + (errorReportsSnap.count ?? 0),
      };
    } catch (e) {
      return {'students': 0, 'lessons': 0, 'tickets': 0};
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // --- Tickets ---

  Future<String> submitHelpRequest(HelpRequest request) async {
    final doc = await _firestore.collection('help_requests').add(request.toJson());
    return doc.id;
  }

  Stream<List<HelpRequest>> getHelpRequestsStream({String? status}) {
    Query q = _firestore.collection('help_requests').orderBy('timestamp', descending: true).limit(100);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots().map((s) => s.docs.map((d) => HelpRequest.fromJson(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Future<void> resolveHelpRequest(String id, String resolvedBy) async {
    await _firestore.collection('help_requests').doc(id).update({
      'status': 'resolved',
      'resolvedBy': resolvedBy,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Error Reports ---

  Future<String> submitErrorReport(ErrorReport report) async {
    final doc = await _firestore.collection('error_reports').add(report.toJson());
    return doc.id;
  }

  Stream<List<ErrorReport>> getErrorReportsStream({String? status}) {
    Query q = _firestore.collection('error_reports').orderBy('timestamp', descending: true).limit(100);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots().map((s) => s.docs.map((d) => ErrorReport.fromJson(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Future<void> updateErrorReportStatus(String id, String status) async {
    await _firestore.collection('error_reports').doc(id).update({'status': status});
  }

  // --- Feedback ---

  Future<String> submitFeedback(AppFeedback feedback) async {
    final doc = await _firestore.collection('feedback').add(feedback.toJson());
    return doc.id;
  }

  Stream<List<AppFeedback>> getFeedbackStream() {
    return _firestore.collection('feedback').orderBy('timestamp', descending: true).limit(100).snapshots()
        .map((s) => s.docs.map((d) => AppFeedback.fromJson(d.data(), d.id)).toList());
  }

  Future<void> markFeedbackRead(String id) async {
    await _firestore.collection('feedback').doc(id).update({'status': 'read'});
  }

  // --- Alerts ---

  Future<String> sendAlert(Alert alert) async {
    final doc = await _firestore.collection('alerts').add(alert.toJson());
    return doc.id;
  }

  Stream<List<Alert>> getAlertsForUser(String userId, String regNo, List<String> enrolledClasses) {
    // Get alerts targeted at: all, this user, this regNo, or any of their classes
    return _firestore
        .collection('alerts')
        .where('targetType', whereIn: ['all', 'user', 'class', 'regNo'])
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
          .map((d) => Alert.fromJson(d.data(), d.id))
          .where((a) =>
            a.targetType == 'all' ||
            (a.targetType == 'user' && a.targetId == userId) ||
            (a.targetType == 'regNo' && regNo.isNotEmpty && a.targetId == regNo) ||
            (a.targetType == 'class' && enrolledClasses.contains(a.targetId))
          )
          .toList());
  }

  Stream<List<Alert>> getAllAlertsStream() {
    return _firestore.collection('alerts').orderBy('timestamp', descending: true).limit(100).snapshots()
        .map((s) => s.docs.map((d) => Alert.fromJson(d.data(), d.id)).toList());
  }

  Future<void> markAlertRead(String alertId, String userId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'readBy': FieldValue.arrayUnion([userId]),
    });
  }

  // --- Class Change Requests (after limit reached) ---

  Future<String> submitClassChangeRequest(String userId, String userName, String userEmail, String desiredClass, String reason) async {
    final doc = await _firestore.collection('class_change_requests').add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'desiredClass': desiredClass,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    return doc.id;
  }

  Stream<QuerySnapshot> getClassChangeRequestsStream() {
    return _firestore.collection('class_change_requests')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> approveClassChangeRequest(String requestId, String userId, String newClass) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('class_change_requests').doc(requestId), {'status': 'approved'});
    batch.update(_firestore.collection('users').doc(userId), {
      'enrolledClasses': [newClass],
    });
    await batch.commit();
  }
}
