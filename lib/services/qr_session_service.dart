import 'package:cloud_firestore/cloud_firestore.dart';

class QRSessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> isQrActiveForClass(String classId) async {
    final snap = await _db
        .collection('active_qr_sessions')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .orderBy('activatedAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return false;

    final data = snap.docs.first.data();
    final expiresAt = data['expiresAt'] as String?;
    if (expiresAt == null) return false;

    final expires = DateTime.tryParse(expiresAt);
    if (expires == null || DateTime.now().isAfter(expires)) {
      await snap.docs.first.reference.update({'isActive': false});
      return false;
    }
    return true;
  }

  Stream<QuerySnapshot> activeStatusStream(String classId) {
    return _db
        .collection('active_qr_sessions')
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }
}
