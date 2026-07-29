// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cube.dart';
import '../models/cube_booking.dart';
import '../models/waitlist_entry.dart';
import '../utils/term_utils.dart';

class CubeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- Cubes ----

  Stream<List<Cube>> getCubesByHouseStream(String houseId) => _db
      .collection('cubes')
      .where('houseId', isEqualTo: houseId)
      .where('isActive', isEqualTo: true)
      .orderBy('cubeNumber')
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Cube.fromJson(d.data(), d.id)).toList(),
      );

  Future<List<Cube>> getCubesByHouse(String houseId) async {
    final snap = await _db
        .collection('cubes')
        .where('houseId', isEqualTo: houseId)
        .where('isActive', isEqualTo: true)
        .orderBy('cubeNumber')
        .get();
    return snap.docs.map((d) => Cube.fromJson(d.data(), d.id)).toList();
  }

  Future<void> generateCubesForHouse(
    String houseId,
    String houseName,
    int count, {
    int defaultCapacity = 4,
  }) async {
    final batch = _db.batch();
    for (int i = 1; i <= count; i++) {
      final ref = _db.collection('cubes').doc();
      batch.set(ref, {
        'houseId': houseId,
        'houseName': houseName,
        'cubeNumber': i,
        'maxOccupancy': defaultCapacity,
        'isActive': true,
      });
    }
    await batch.commit();
  }

  Future<void> updateCube(String id, Cube cube) =>
      _db.collection('cubes').doc(id).update(cube.toJson());

  Future<void> deleteCube(String id) =>
      _db.collection('cubes').doc(id).update({'isActive': false});

  // ---- Availability ----

  static const _activeStatuses = [
    'pending',
    'confirmed',
    'checked_in',
    'completed',
  ];

  Future<int> getBookedCountForCube(String cubeId, int term, int year) async {
    final snap = await _db
        .collection('cube_bookings')
        .where('cubeId', isEqualTo: cubeId)
        .where('term', isEqualTo: term)
        .where('year', isEqualTo: year)
        .where('status', whereIn: _activeStatuses)
        .get();
    return snap.docs.length;
  }

  Stream<int> getAvailableCountStream(
    String cubeId,
    int maxOccupancy,
    int term,
    int year,
  ) {
    return _db
        .collection('cube_bookings')
        .where('cubeId', isEqualTo: cubeId)
        .where('term', isEqualTo: term)
        .where('year', isEqualTo: year)
        .where('status', whereIn: _activeStatuses)
        .snapshots()
        .map((snap) => maxOccupancy - snap.docs.length);
  }

  Future<int> getAvailableSpots(
    String cubeId,
    int maxOccupancy,
    int term,
    int year,
  ) async {
    final booked = await getBookedCountForCube(cubeId, term, year);
    return maxOccupancy - booked;
  }

  Future<bool> isCubeAvailable(
    String cubeId,
    int maxOccupancy,
    int term,
    int year,
  ) async {
    final available = await getAvailableSpots(cubeId, maxOccupancy, term, year);
    return available > 0;
  }

  // ---- Bookings ----

  /// Creates a booking atomically using a Firestore transaction.
  /// Checks both student's existing active bookings AND cube capacity in one
  /// transaction, preventing race conditions from double-taps or concurrent users.
  Future<CubeBooking> createBooking(CubeBooking booking) async {
    final term = booking.term;
    final year = booking.year;

    return await _db.runTransaction((transaction) async {
      // 1. Check student has no existing active booking this term
      final existingSnap = await _db
          .collection('cube_bookings')
          .where('studentId', isEqualTo: booking.studentId)
          .where('term', isEqualTo: term)
          .where('year', isEqualTo: year)
          .where('status', whereIn: _activeStatuses)
          .limit(1)
          .get();
      if (existingSnap.docs.isNotEmpty) {
        throw const BookingConflictException(
          'You already have an active booking this term.',
        );
      }

      // 2. Check cube has capacity
      final cubeDoc = await _db.collection('cubes').doc(booking.cubeId).get();
      final maxOccupancy =
          (cubeDoc.data()?['maxOccupancy'] as num?)?.toInt() ?? 4;
      final cubeBookingsSnap = await _db
          .collection('cube_bookings')
          .where('cubeId', isEqualTo: booking.cubeId)
          .where('term', isEqualTo: term)
          .where('year', isEqualTo: year)
          .where('status', whereIn: _activeStatuses)
          .get();
      if (cubeBookingsSnap.docs.length >= maxOccupancy) {
        throw const BookingConflictException('This cubicle is fully booked.');
      }

      // 3. Create the booking
      final ref = _db.collection('cube_bookings').doc();
      transaction.set(ref, booking.toJson());
      return CubeBooking.fromJson({...booking.toJson(), 'id': ref.id}, ref.id);
    });
  }

  /// Gets any booking (active or completed) for the student this term.
  /// Used to block re-booking after checkout.
  Future<CubeBooking?> getMyActiveBooking(String studentId) async {
    final term = TermUtils.getCurrentTerm();
    final year = TermUtils.getCurrentYear();
    final snap = await _db
        .collection('cube_bookings')
        .where('studentId', isEqualTo: studentId)
        .where('term', isEqualTo: term)
        .where('year', isEqualTo: year)
        .where('status', whereIn: _activeStatuses)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return CubeBooking.fromJson(snap.docs.first.data(), snap.docs.first.id);
  }

  Future<void> cancelBooking(String id) =>
      _db.collection('cube_bookings').doc(id).update({'status': 'cancelled'});

  Future<void> updateBookingStatus(String id, String status) =>
      _db.collection('cube_bookings').doc(id).update({'status': status});

  Future<void> updatePaymentStatus(String id, String paymentStatus) => _db
      .collection('cube_bookings')
      .doc(id)
      .update({'paymentStatus': paymentStatus});

  Stream<List<CubeBooking>> getMyBookingsStream(String studentId) {
    final term = TermUtils.getCurrentTerm();
    final year = TermUtils.getCurrentYear();
    return _db
        .collection('cube_bookings')
        .where('studentId', isEqualTo: studentId)
        .where('term', isEqualTo: term)
        .where('year', isEqualTo: year)
        .orderBy('houseName')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CubeBooking.fromJson(d.data(), d.id))
              .toList(),
        );
  }

  Stream<List<CubeBooking>> getAllBookingsStream({int? term, int? year}) {
    final t = term ?? TermUtils.getCurrentTerm();
    final y = year ?? TermUtils.getCurrentYear();
    var query = _db
        .collection('cube_bookings')
        .where('term', isEqualTo: t)
        .where('year', isEqualTo: y)
        .orderBy('houseName')
        .orderBy('cubeNumber');
    return query.snapshots().map(
      (snap) =>
          snap.docs.map((d) => CubeBooking.fromJson(d.data(), d.id)).toList(),
    );
  }

  // ---- Waiting List ----

  Future<void> joinWaitlist({
    required String studentId,
    required String studentName,
    required String cubeId,
    required String houseName,
    required int cubeNumber,
  }) async {
    final term = TermUtils.getCurrentTerm();
    final year = TermUtils.getCurrentYear();

    // Check if already on waitlist for this cube this term
    final existing = await _db
        .collection('waitlist')
        .where('studentId', isEqualTo: studentId)
        .where('cubeId', isEqualTo: cubeId)
        .where('term', isEqualTo: term)
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw const BookingConflictException(
        'You are already on the waiting list for this cubicle.',
      );
    }

    // Get next position
    final currentWaitlist = await _db
        .collection('waitlist')
        .where('cubeId', isEqualTo: cubeId)
        .where('term', isEqualTo: term)
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'waiting')
        .get();
    final nextPosition = currentWaitlist.docs.length + 1;

    await _db.collection('waitlist').add({
      'studentId': studentId,
      'studentName': studentName,
      'cubeId': cubeId,
      'houseName': houseName,
      'cubeNumber': cubeNumber,
      'term': term,
      'year': year,
      'position': nextPosition,
      'status': 'waiting',
      'joinedAt': FieldValue.serverTimestamp(),
      'promotedAt': null,
    });
  }

  Stream<List<WaitlistEntry>> getMyWaitlistStream(String studentId) {
    final term = TermUtils.getCurrentTerm();
    final year = TermUtils.getCurrentYear();
    return _db
        .collection('waitlist')
        .where('studentId', isEqualTo: studentId)
        .where('term', isEqualTo: term)
        .where('year', isEqualTo: year)
        .orderBy('position')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(WaitlistEntry.fromFirestore).toList(),
        );
  }

  Future<bool> isOnWaitlist(String studentId, String cubeId) async {
    final term = TermUtils.getCurrentTerm();
    final year = TermUtils.getCurrentYear();
    final snap = await _db
        .collection('waitlist')
        .where('studentId', isEqualTo: studentId)
        .where('cubeId', isEqualTo: cubeId)
        .where('term', isEqualTo: term)
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> cancelWaitlistEntry(String entryId) =>
      _db.collection('waitlist').doc(entryId).update({'status': 'expired'});
}

/// Thrown when a booking conflicts with an existing booking or capacity limit.
class BookingConflictException implements Exception {
  final String message;
  const BookingConflictException(this.message);
  @override
  String toString() => message;
}
