// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teaching_material.dart';

class TeachingMaterialsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const kTypeLabels = {
    'notes': 'Notes',
    'past_paper': 'Past Paper',
    'practical': 'Practical',
    'checklist': 'Checklist',
    'course_outline': 'Course Outline',
    'book': 'Book',
    'timetable': 'Timetable',
    'notice': 'Notice',
    'general': 'General',
  };

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('teaching_materials');

  Stream<QuerySnapshot> watchAll() => _ref
      .orderBy('uploadedAt', descending: true)
      .snapshots();

  Future<void> addMaterial(TeachingMaterial material) async {
    await _ref.add(material.toJson());
  }

  Future<void> updateMaterial(TeachingMaterial material) async {
    await _ref.doc(material.id).set(material.toJson());
  }

  Future<void> deleteMaterial(String id) async {
    await _ref.doc(id).delete();
  }

  /// Distinct subjects present in the library (for filter chips).
  Future<List<String>> fetchSubjects() async {
    final snap = await _ref.get();
    final subjects = <String>{};
    for (final doc in snap.docs) {
      final s = (doc.data())['subject'] as String?;
      if (s != null && s.isNotEmpty) subjects.add(s);
    }
    final list = subjects.toList()..sort();
    return list;
  }
}