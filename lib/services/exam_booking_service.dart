// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam.dart';

class ExamBookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Gets available exams for a student's class.
  Stream<List<Exam>> getAvailableExamsStream(String classId) {
    return _db
        .collection('exams')
        .where('classId', isEqualTo: classId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Exam.fromFirestore).toList());
  }

  /// Gets a student's exam bookings.
  Stream<List<ExamBooking>> getMyExamBookingsStream(String studentId) {
    return _db
        .collection('exam_bookings')
        .where('studentId', isEqualTo: studentId)
        .orderBy('registeredAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ExamBooking.fromFirestore).toList(),
        );
  }

  /// Checks if a student is already registered for an exam.
  Future<bool> isRegistered(String studentId, String examId) async {
    final snap = await _db
        .collection('exam_bookings')
        .where('studentId', isEqualTo: studentId)
        .where('examId', isEqualTo: examId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Registers a student for an exam atomically.
  Future<ExamBooking> registerForExam({
    required String studentId,
    required String examId,
    List<String> courseIds = const [],
  }) async {
    return await _db.runTransaction((transaction) async {
      // Check exam exists and registration is open
      final examDoc = await _db.collection('exams').doc(examId).get();
      if (!examDoc.exists) throw Exception('Exam not found.');
      final exam = Exam.fromFirestore(examDoc);

      if (!exam.isRegistrationOpen) {
        throw Exception('Registration is closed for this exam.');
      }

      // Check not already registered
      final existingBookings = await _db
          .collection('exam_bookings')
          .where('studentId', isEqualTo: studentId)
          .where('examId', isEqualTo: examId)
          .limit(1)
          .get();
      if (existingBookings.docs.isNotEmpty) {
        throw Exception('You are already registered for this exam.');
      }

      // Check seats
      if (exam.registeredCount >= exam.maxSeats) {
        throw Exception('No seats available.');
      }

      // Create booking
      final ref = _db.collection('exam_bookings').doc();
      final booking = ExamBooking(
        id: ref.id,
        studentId: studentId,
        examId: examId,
        registeredCourseIds: courseIds,
        status: 'registered',
        registeredAt: DateTime.now(),
      );
      transaction.set(ref, booking.toJson());

      // Increment registered count
      transaction.update(examDoc.reference, {
        'registeredCount': FieldValue.increment(1),
      });

      return booking;
    });
  }

  /// Cancels an exam registration.
  Future<void> cancelRegistration(String bookingId, String examId) async {
    await _db.runTransaction((transaction) async {
      final bookingDoc = await _db
          .collection('exam_bookings')
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) throw Exception('Booking not found.');

      transaction.delete(bookingDoc.reference);

      // Decrement registered count
      final examRef = _db.collection('exams').doc(examId);
      transaction.update(examRef, {
        'registeredCount': FieldValue.increment(-1),
      });
    });
  }

  // ---- Admin methods ----

  /// Admin: creates a new exam.
  Future<String> createExam({
    required String title,
    required String type,
    required String classId,
    required DateTime registrationDeadline,
    required DateTime startDate,
    required DateTime endDate,
    int maxSeats = 200,
  }) async {
    final ref = _db.collection('exams').doc();
    await ref.set(
      Exam(
        id: ref.id,
        title: title,
        type: type,
        classId: classId,
        registrationDeadline: registrationDeadline,
        startDate: startDate,
        endDate: endDate,
        maxSeats: maxSeats,
      ).toJson(),
    );
    return ref.id;
  }

  /// Admin: toggles registration open/close.
  Future<void> toggleRegistration(String examId, bool open) async {
    await _db.collection('exams').doc(examId).update({
      'registrationOpen': open,
    });
  }
}
