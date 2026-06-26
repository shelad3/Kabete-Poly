import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/house.dart';

class HouseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<House>> getHousesStream() =>
    _db.collection('houses').orderBy('name').snapshots().map(
      (snap) => snap.docs.map((d) => House.fromJson(d.data(), d.id)).toList(),
    );

  Stream<List<House>> getHousesByCategoryStream(String category) =>
    _db.collection('houses')
      .where('category', isEqualTo: category)
      .orderBy('name')
      .snapshots().map(
        (snap) => snap.docs.map((d) => House.fromJson(d.data(), d.id)).toList(),
      );

  Future<House?> getHouse(String id) async {
    final doc = await _db.collection('houses').doc(id).get();
    if (!doc.exists) return null;
    return House.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<String> addHouse(House house) async {
    final ref = await _db.collection('houses').add(house.toJson());
    return ref.id;
  }

  Future<void> updateHouse(String id, House house) =>
    _db.collection('houses').doc(id).update(house.toJson());

  Future<void> deleteHouse(String id) =>
    _db.collection('houses').doc(id).delete();
}
