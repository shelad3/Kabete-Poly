// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment.dart';

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a pending payment record. The actual STK push / charge
  /// is initiated by a Cloud Function listening to this document.
  Future<Payment> initiatePayment({
    required String bookingId,
    required String studentId,
    required double amount,
    required PaymentMethod method,
    String? phoneNumber,
  }) async {
    final ref = _db.collection('payments').doc();
    final payment = Payment(
      id: ref.id,
      bookingId: bookingId,
      studentId: studentId,
      amount: amount,
      method: method,
      status: PaymentStatus.pending,
      phoneNumber: phoneNumber,
      initiatedAt: DateTime.now(),
    );
    await ref.set({
      ...payment.toJson(),
      'initiatedAt': FieldValue.serverTimestamp(),
    });
    return payment;
  }

  /// Watches the status of a payment in real-time.
  Stream<Payment?> watchPayment(String paymentId) {
    return _db
        .collection('payments')
        .doc(paymentId)
        .snapshots()
        .map((doc) => doc.exists ? Payment.fromFirestore(doc) : null);
  }

  /// Checks the current status of a payment (one-shot).
  Future<Payment?> getPayment(String paymentId) async {
    final doc = await _db.collection('payments').doc(paymentId).get();
    return doc.exists ? Payment.fromFirestore(doc) : null;
  }

  /// Gets all payments for a student.
  Stream<List<Payment>> getStudentPayments(String studentId) {
    return _db
        .collection('payments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('initiatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Payment.fromFirestore).toList());
  }

  /// Gets all payments (admin).
  Stream<List<Payment>> getAllPayments() {
    return _db
        .collection('payments')
        .orderBy('initiatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Payment.fromFirestore).toList());
  }

  /// Admin: manually mark a payment as completed (edge case recovery).
  Future<void> markCompleted(String paymentId, String transactionRef) async {
    await _db.collection('payments').doc(paymentId).update({
      'status': 'completed',
      'transactionRef': transactionRef,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin: mark a payment as failed.
  Future<void> markFailed(String paymentId, String reason) async {
    await _db.collection('payments').doc(paymentId).update({
      'status': 'failed',
      'failureReason': reason,
      'failedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Amount for a cube booking (configurable per term).
  static const double cubeBookingAmount = 5000.0; // KES
}
