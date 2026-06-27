import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cube.dart';
import '../models/cube_booking.dart';
import '../utils/term_utils.dart';

class CubeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- Cubes ----

  Stream<List<Cube>> getCubesByHouseStream(String houseId) =>
    _db.collection('cubes')
      .where('houseId', isEqualTo: houseId)
      .where('isActive', isEqualTo: true)
      .orderBy('cubeNumber')
      .snapshots().map(
        (snap) => snap.docs.map((d) => Cube.fromJson(d.data(), d.id)).toList(),
      );

  Future<List<Cube>> getCubesByHouse(String houseId) async {
    final snap = await _db.collection('cubes')
      .where('houseId', isEqualTo: houseId)
      .where('isActive', isEqualTo: true)
      .orderBy('cubeNumber')
      .get();
    return snap.docs.map((d) => Cube.fromJson(d.data(), d.id)).toList();
  }

  Future<void> generateCubesForHouse(String houseId, String houseName, int count, {int defaultCapacity = 4}) async {
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

  Future<int> getBookedCountForCube(String cubeId, int term, int year) async {
    final snap = await _db.collection('cube_bookings')
      .where('cubeId', isEqualTo: cubeId)
      .where('term', isEqualTo: term)
      .where('year', isEqualTo: year)
      .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
      .get();
    return snap.docs.length;
  }

  Stream<int> getAvailableCountStream(String cubeId, int maxOccupancy, int term, int year) {
    return _db.collection('cube_bookings')
      .where('cubeId', isEqualTo: cubeId)
      .where('term', isEqualTo: term)
      .where('year', isEqualTo: year)
      .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
      .snapshots()
      .map((snap) => maxOccupancy - snap.docs.length);
  }

  Future<int> getAvailableSpots(String cubeId, int maxOccupancy, int term, int year) async {
    final booked = await getBookedCountForCube(cubeId, term, year);
    return maxOccupancy - booked;
  }

  Future<bool> isCubeAvailable(String cubeId, int maxOccupancy, int term, int year) async {
    final available = await getAvailableSpots(cubeId, maxOccupancy, term, year);
    return available > 0;
  }

  // ---- Bookings ----

  Future<CubeBooking> createBooking(CubeBooking booking) async {
    final term = booking.term;
    final year = booking.year;
    final existing = await _db.collection('cube_bookings')
      .where('studentId', isEqualTo: booking.studentId)
      .where('term', isEqualTo: term)
      .where('year', isEqualTo: year)
      .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
      .limit(1)
      .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('You already have an active booking this term.');
    }
    final ref = await _db.collection('cube_bookings').add(booking.toJson());
    return CubeBooking.fromJson({...booking.toJson(), 'id': ref.id}, ref.id);
  }

  Future<CubeBooking?> getMyActiveBooking(String studentId) async {
    final term = TermUtils.getCurrentTerm();
    final year = TermUtils.getCurrentYear();
    final snap = await _db.collection('cube_bookings')
      .where('studentId', isEqualTo: studentId)
      .where('term', isEqualTo: term)
      .where('year', isEqualTo: year)
      .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
      .limit(1)
      .get();
    if (snap.docs.isEmpty) return null;
    return CubeBooking.fromJson(snap.docs.first.data(), snap.docs.first.id);
  }

  Future<void> cancelBooking(String id) =>
    _db.collection('cube_bookings').doc(id).update({'status': 'cancelled'});

  Future<void> updateBookingStatus(String id, String status) =>
    _db.collection('cube_bookings').doc(id).update({'status': status});

  Future<void> updatePaymentStatus(String id, String paymentStatus) =>
    _db.collection('cube_bookings').doc(id).update({'paymentStatus': paymentStatus});

  Stream<List<CubeBooking>> getMyBookingsStream(String studentId) {
    final term = TermUtils.getCurrentTerm();
    final year = TermUtils.getCurrentYear();
    return _db.collection('cube_bookings')
      .where('studentId', isEqualTo: studentId)
      .where('term', isEqualTo: term)
      .where('year', isEqualTo: year)
      .orderBy('houseName')
      .snapshots().map(
        (snap) => snap.docs.map((d) => CubeBooking.fromJson(d.data(), d.id)).toList(),
      );
  }

  Stream<List<CubeBooking>> getAllBookingsStream({int? term, int? year}) {
    final t = term ?? TermUtils.getCurrentTerm();
    final y = year ?? TermUtils.getCurrentYear();
    var query = _db.collection('cube_bookings')
      .where('term', isEqualTo: t)
      .where('year', isEqualTo: y)
      .orderBy('houseName')
      .orderBy('cubeNumber');
    return query.snapshots().map(
      (snap) => snap.docs.map((d) => CubeBooking.fromJson(d.data(), d.id)).toList(),
    );
  }

  Stream<List<CubeBooking>> getBookingsForCubeOnDate(String cubeId, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _db.collection('cube_bookings')
      .where('cubeId', isEqualTo: cubeId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
      .where('date', isLessThan: Timestamp.fromDate(dayEnd))
      .snapshots().map(
        (snap) => snap.docs.map((d) => CubeBooking.fromJson(d.data(), d.id)).toList(),
      );
  }
}
