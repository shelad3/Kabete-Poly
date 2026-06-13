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
      final snapshot = await FirebaseFirestore.instance.collection('classes').get();
      _mergeFirestoreClasses(snapshot.docs.map((d) => d.id).toList());
    } catch (e) {
      debugPrint("Class Provider failed to fetch dynamic classes: $e");
    }
  }

  Future<void> refreshClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('classes').get();
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
    if (availableClasses.contains(newClass) && _currentClass != newClass) {
      _currentClass = newClass;
      notifyListeners();
    }
  }

  /// Set current class from user's enrolled classes. Called after login.
  void setFromEnrolled(List<String> enrolledClasses) {
    if (enrolledClasses.isNotEmpty) {
      final firstClass = enrolledClasses.first;
      if (!availableClasses.contains(firstClass)) {
        availableClasses.add(firstClass);
      }
      if (_currentClass == 'Global / General Assembly' || _currentClass != firstClass) {
        _currentClass = firstClass;
        notifyListeners();
      }
    }
  }
}
