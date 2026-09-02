// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing.dart';

class ListingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Listing>> getListingsStream() => _db
      .collection('listings')
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Listing.fromJson(d.data(), d.id)).toList(),
      );

  Stream<List<Listing>> getListingsByAreaStream(String area) => _db
      .collection('listings')
      .where('isActive', isEqualTo: true)
      .where('area', isEqualTo: area)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Listing.fromJson(d.data(), d.id)).toList(),
      );

  /// All listings regardless of active state (admin management + map).
  Stream<List<Listing>> getAllListingsStream() => _db
      .collection('listings')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Listing.fromJson(d.data(), d.id)).toList(),
      );

  /// Snapshot of active listings used by campus map markers.
  Stream<List<Listing>> getActiveListingsStream() => getListingsStream();

  Future<Listing?> getListing(String id) async {
    final doc = await _db.collection('listings').doc(id).get();
    if (!doc.exists) return null;
    return Listing.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<String> addListing(Listing listing) async {
    final ref = await _db.collection('listings').add(listing.toJson());
    return ref.id;
  }

  Future<void> updateListing(String id, Listing listing) =>
      _db.collection('listings').doc(id).update(listing.toJson());

  Future<void> deleteListing(String id) =>
      _db.collection('listings').doc(id).delete();
}
