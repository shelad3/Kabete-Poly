// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassProvider extends ChangeNotifier {
  List<String> availableClasses = ['Global / General Assembly'];

  String _currentClass = 'Global / General Assembly';

  String get currentClass => _currentClass;

  ClassProvider() {
    _fetchDynamicClasses();
  }

  Future<void> _fetchDynamicClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      _mergeFirestoreClasses(snapshot.docs.map((d) => d.id).toList());
    } catch (e) {
      debugPrint('Class Provider failed to fetch dynamic classes: $e');
    }
  }

  Future<void> refreshClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      _mergeFirestoreClasses(snapshot.docs.map((d) => d.id).toList());
    } catch (_) {}
  }

  void _mergeFirestoreClasses(List<String> fetched) {
    bool updated = false;
    for (String c in fetched) {
      if (!availableClasses.contains(c)) {
        availableClasses.add(c);
        updated = true;
      }
    }
    if (updated) notifyListeners();
  }

  void setClassContext(String newClass) {
    final normalized = _normalizeClassId(newClass);
    if (availableClasses.contains(normalized) && _currentClass != normalized) {
      _currentClass = normalized;
      notifyListeners();
    }
  }

  /// Set current class from user's enrolled classes. Called after login.
  /// Normalizes class IDs: replaces slashes/dashes with spaces to match
  /// Firestore class document IDs (e.g. "ICT/600/M26" → "ICT 600 M26").
  void setFromEnrolled(List<String> enrolledClasses) {
    if (enrolledClasses.isNotEmpty) {
      final firstClass = _normalizeClassId(enrolledClasses.first);
      if (!availableClasses.contains(firstClass)) {
        availableClasses.add(firstClass);
      }
      if (_currentClass == 'Global / General Assembly' ||
          _currentClass != firstClass) {
        _currentClass = firstClass;
        notifyListeners();
      }
    }
  }

  /// Normalize class ID to match Firestore document IDs.
  /// Handles slash-separated (ICT/600/M26) and dash-separated (EOP-500-M25)
  /// formats, converting them to space-separated (ICT 600 M26).
  static String _normalizeClassId(String id) {
    return id.replaceAll(RegExp(r'[/\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
