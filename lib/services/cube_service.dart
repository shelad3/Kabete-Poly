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
        'occupied': 0,
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
        .collection('cubes')
        .doc(cubeId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return maxOccupancy;
          final occupied =
              ((snap.data()?['occupied'] as num?) ?? 0).toInt();
          final cap =
              ((snap.data()?['maxOccupancy'] as num?) ?? maxOccupancy).toInt();
          return (cap - occupied).clamp(0, cap);
        });
  }

  Future<int> getAvailableSpots(
    String cubeId,
    int maxOccupancy,
    int term,
    int year,
  ) async {
    final cubeDoc = await _db.collection('cubes').doc(cubeId).get();
    if (!cubeDoc.exists) return maxOccupancy;
    final occupied =
        ((cubeDoc.data()?['occupied'] as num?) ?? 0).toInt();
    final cap = ((cubeDoc.data()?['maxOccupancy'] as num?) ?? maxOccupancy)
        .toInt();
    return (cap - occupied).clamp(0, cap);
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

  // Deterministic doc that records a student's active booking this term/year.
  // Used to enforce one-active-booking-per-student atomically inside a
  // transaction (Firestore transactions can only read/write documents, not
  // run queries atomically).
  DocumentReference<Map<String, dynamic>> _activeRef(String studentId) =>
      _db.collection('cube_bookings').doc('student_active_$studentId');

  // ---- Bookings ----

  /// Creates a booking atomically using a Firestore transaction.
  ///
  /// Enforces both invariants inside the SAME transaction using real
  /// `transaction.get` document reads (the only reads Firestore guarantees to
  /// be atomic with the transaction's writes):
  ///   1. one-active-booking-per-student this term/year
  ///   2. cube capacity (via the cube doc's `occupied` counter, incremented
  ///      atomically here and decremented on cancel/checkout)
  ///
  /// Throws `BookingConflictException` on any violation.
  Future<CubeBooking> createBooking(CubeBooking booking) async {
    final term = booking.term;
    final year = booking.year;

    return await _db.runTransaction((transaction) async {
      // 1. One-active-booking per student (atomic doc-based check)
      final activeRef = _activeRef(booking.studentId);
      final activeSnap = await transaction.get(activeRef);
      if (activeSnap.exists) {
        final activeData = activeSnap.data();
        final sameTerm =
            activeData?['term'] == term && activeData?['year'] == year;
        if (sameTerm) {
          throw const BookingConflictException(
            'You already have an active booking this term.',
          );
        }
      }

      // 2. Cube capacity (atomic read of the cube's occupancy counter)
      final cubeRef = _db.collection('cubes').doc(booking.cubeId);
      final cubeSnap = await transaction.get(cubeRef);
      if (!cubeSnap.exists) {
        throw const BookingConflictException('This cubicle no longer exists.');
      }
      final cubeData = cubeSnap.data()!;
      final maxOcc =
          ((cubeData['maxOccupancy'] as num?) ?? 4).toInt();
      final occupied = ((cubeData['occupied'] as num?) ?? 0).toInt();
      if (occupied >= maxOcc) {
        throw const BookingConflictException('This cubicle is fully booked.');
      }

      // 3. Create the booking + increment occupancy + mark student active atomically
      final ref = _db.collection('cube_bookings').doc();
      transaction.set(ref, booking.toJson());
      transaction.update(cubeRef, {'occupied': FieldValue.increment(1)});
      transaction.set(
        activeRef,
        {
          'bookingId': ref.id,
          'term': term,
          'year': year,
          'status': booking.status,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return CubeBooking.fromJson({...booking.toJson(), 'id': ref.id}, ref.id);
    });
  }

  /// Gets any booking (active or completed) for the student this term.
  /// Used to block re-booking after checkout.
  Future<CubeBooking?> getMyActiveBooking(String studentId) async {
    final activeRef = _activeRef(studentId);
    final activeSnap = await activeRef.get();
    if (!activeSnap.exists) return null;
    final bookingId = activeSnap.data()?['bookingId'] as String?;
    if (bookingId == null) return null;
    final bSnap = await _db.collection('cube_bookings').doc(bookingId).get();
    if (!bSnap.exists) return null;
    return CubeBooking.fromJson(bSnap.data()!, bSnap.id);
  }

  Future<void> cancelBooking(String id, String studentId) async {
    await _db.runTransaction((transaction) async {
      final bookingRef = _db.collection('cube_bookings').doc(id);
      final bSnap = await transaction.get(bookingRef);
      if (bSnap.exists) {
        final bookId = bSnap.data()?['cubeId'] as String?;
        transaction.update(bookingRef, {'status': 'cancelled'});
        if (bookId != null) {
          transaction.update(
            _db.collection('cubes').doc(bookId),
            {'occupied': FieldValue.increment(-1)},
          );
        }
      }
      transaction.delete(_activeRef(studentId));
    });
  }

  Future<void> updateBookingStatus(String id, String status) async {
    await _db.runTransaction((transaction) async {
      final bookingRef = _db.collection('cube_bookings').doc(id);
      final bSnap = await transaction.get(bookingRef);
      if (!bSnap.exists) return;
      transaction.update(bookingRef, {'status': status});

      if (status == 'cancelled') {
        final cubeId = bSnap.data()?['cubeId'] as String?;
        final studentId = bSnap.data()?['studentId'] as String?;
        if (cubeId != null) {
          transaction.update(
            _db.collection('cubes').doc(cubeId),
            {'occupied': FieldValue.increment(-1)},
          );
        }
        if (studentId != null) {
          transaction.delete(_activeRef(studentId));
        }
      }
    });
  }

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

    await _db.runTransaction((transaction) async {
      // Atomic per-cube position counter doc to avoid duplicate positions.
      final metaRef = _db.collection('waitlist').doc('meta_$cubeId');
      final metaSnap = await transaction.get(metaRef);
      final nextPosition =
          (((metaSnap.data()?['positionSeq'] as num?) ?? 0)).toInt() + 1;

      final ref = _db.collection('waitlist').doc();
      transaction.set(ref, {
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
      transaction.set(
        metaRef,
        {'positionSeq': nextPosition},
        SetOptions(merge: true),
      );
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
