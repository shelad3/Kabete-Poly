import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cube.dart';
import '../models/cube_booking.dart';

class CubeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- Cubes ----

  Stream<List<Cube>> getCubesStream() =>
    _db.collection('cubes').where('isActive', isEqualTo: true).snapshots().map(
      (snap) => snap.docs.map((d) => Cube.fromJson(d.data(), d.id)).toList(),
    );

  Stream<List<Cube>> getCubesByHouseStream(String house) =>
    _db.collection('cubes')
      .where('houseName', isEqualTo: house)
      .where('isActive', isEqualTo: true)
      .snapshots().map(
        (snap) => snap.docs.map((d) => Cube.fromJson(d.data(), d.id)).toList(),
      );

  Future<List<Cube>> getCubesByHouse(String house) async {
    final snap = await _db.collection('cubes')
      .where('houseName', isEqualTo: house)
      .where('isActive', isEqualTo: true)
      .get();
    return snap.docs.map((d) => Cube.fromJson(d.data(), d.id)).toList();
  }

  Future<List<String>> getDistinctHouses() async {
    final snap = await _db.collection('cubes')
      .where('isActive', isEqualTo: true)
      .get();
    final houses = snap.docs.map((d) => d['houseName'] as String? ?? '').toSet();
    return houses.where((h) => h.isNotEmpty).toList()..sort();
  }

  Future<void> addCube(Cube cube) =>
    _db.collection('cubes').add(cube.toJson());

  Future<void> updateCube(String id, Cube cube) =>
    _db.collection('cubes').doc(id).update(cube.toJson());

  Future<void> deleteCube(String id) =>
    _db.collection('cubes').doc(id).update({'isActive': false});

  // ---- Bookings ----

  Future<bool> isCubeAvailable(String cubeId, DateTime date, String start, String end) async {
    final bookings = await _db.collection('cube_bookings')
      .where('cubeId', isEqualTo: cubeId)
      .where('date', isEqualTo: Timestamp.fromDate(DateTime(date.year, date.month, date.day)))
      .where('status', whereIn: ['pending', 'confirmed', 'checked_in'])
      .get();

    for (final doc in bookings.docs) {
      final bStart = doc['startTime'] as String? ?? '';
      final bEnd = doc['endTime'] as String? ?? '';
      if (_timesOverlap(start, end, bStart, bEnd)) return false;
    }
    return true;
  }

  bool _timesOverlap(String aStart, String aEnd, String bStart, String bEnd) {
    final as = _toMinutes(aStart);
    final ae = _toMinutes(aEnd);
    final bs = _toMinutes(bStart);
    final be = _toMinutes(bEnd);
    return as < be && ae > bs;
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  Future<CubeBooking> createBooking(CubeBooking booking) async {
    final ref = await _db.collection('cube_bookings').add(booking.toJson());
    return CubeBooking.fromJson({...booking.toJson(), 'id': ref.id}, ref.id);
  }

  Future<void> cancelBooking(String id) =>
    _db.collection('cube_bookings').doc(id).update({'status': 'cancelled'});

  Future<void> updateBookingStatus(String id, String status) =>
    _db.collection('cube_bookings').doc(id).update({'status': status});

  Stream<List<CubeBooking>> getMyBookingsStream(String studentId) =>
    _db.collection('cube_bookings')
      .where('studentId', isEqualTo: studentId)
      .orderBy('date', descending: true)
      .snapshots().map(
        (snap) => snap.docs.map((d) => CubeBooking.fromJson(d.data(), d.id)).toList(),
      );

  Stream<List<CubeBooking>> getAllBookingsStream() =>
    _db.collection('cube_bookings')
      .orderBy('date', descending: true)
      .snapshots().map(
        (snap) => snap.docs.map((d) => CubeBooking.fromJson(d.data(), d.id)).toList(),
      );

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
