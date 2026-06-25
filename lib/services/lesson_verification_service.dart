import 'package:cloud_firestore/cloud_firestore.dart';

class LessonVerificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _docId(String classId, String subject, String date) {
    return '${classId}_${subject}_$date'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  Future<Map<String, dynamic>?> getVerification(String classId, String subject, String date) async {
    final doc = await _db.collection('lesson_verifications').doc(_docId(classId, subject, date)).get();
    return doc.data();
  }

  Future<void> vote(String classId, String subject, String date, String startTime, String endTime, String voterId, bool taught) async {
    final docId = _docId(classId, subject, date);
    final ref = _db.collection('lesson_verifications').doc(docId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);

      if (!snap.exists) {
        transaction.set(ref, {
          'classId': classId,
          'subject': subject,
          'date': date,
          'startTime': startTime,
          'endTime': endTime,
          'votesFor': taught ? [voterId] : [],
          'votesAgainst': taught ? [] : [voterId],
          'isConfirmed': false,
          'confirmedAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      List<dynamic> votesFor = List.from(data['votesFor'] ?? []);
      List<dynamic> votesAgainst = List.from(data['votesAgainst'] ?? []);

      // Remove existing vote if any
      votesFor.remove(voterId);
      votesAgainst.remove(voterId);

      // Add new vote
      if (taught) {
        votesFor.add(voterId);
      } else {
        votesAgainst.add(voterId);
      }

      // Check if confirmed
      final classDoc = await transaction.get(_db.collection('classes').doc(classId));
      final members = List.from((classDoc.data()?['members'] as List<dynamic>?) ?? []);
      final totalStudents = members.length;
      final threshold = (totalStudents / 2).ceil();

      final isConfirmed = votesFor.length >= threshold && totalStudents > 0;

      transaction.update(ref, {
        'votesFor': votesFor,
        'votesAgainst': votesAgainst,
        'isConfirmed': isConfirmed,
        'confirmedAt': isConfirmed ? FieldValue.serverTimestamp() : null,
      });
    });
  }

  Future<void> removeVote(String classId, String subject, String date, String voterId) async {
    final docId = _docId(classId, subject, date);
    final ref = _db.collection('lesson_verifications').doc(docId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      List<dynamic> votesFor = List.from(data['votesFor'] ?? []);
      List<dynamic> votesAgainst = List.from(data['votesAgainst'] ?? []);
      votesFor.remove(voterId);
      votesAgainst.remove(voterId);

      if (votesFor.isEmpty && votesAgainst.isEmpty) {
        transaction.delete(ref);
      } else {
        transaction.update(ref, {
          'votesFor': votesFor,
          'votesAgainst': votesAgainst,
        });
      }
    });
  }

  Stream<QuerySnapshot> getVerificationsForClass(String classId) {
    return _db
        .collection('lesson_verifications')
        .where('classId', isEqualTo: classId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getVerifiedLessons(String? department) async {
    Query q = _db.collection('lesson_verifications').where('isConfirmed', isEqualTo: true);
    final snap = await q.orderBy('date', descending: true).get();
    final results = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      data['id'] = doc.id;
      results.add(data);
    }

    if (department != null && department.isNotEmpty) {
      // Filter by classes whose name/ID contains the department keyword
      final classIds = results.map((r) => r['classId'] as String).toSet();
      final filteredClasses = <String>{};
      for (final cid in classIds) {
        if (cid.toLowerCase().contains(department.toLowerCase())) {
          filteredClasses.add(cid);
        }
      }
      results.removeWhere((r) => !filteredClasses.contains(r['classId']));
    }

    return results;
  }

  Stream<QuerySnapshot> allVerificationsStream() {
    return _db.collection('lesson_verifications').orderBy('date', descending: true).snapshots();
  }
}
