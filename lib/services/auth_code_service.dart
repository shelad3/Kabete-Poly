import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthCode {
  final String id;
  final String code;
  final String role;
  final bool isUsed;
  final String? usedBy;
  final DateTime createdAt;
  final String createdBy;

  AuthCode({
    required this.id,
    required this.code,
    required this.role,
    this.isUsed = false,
    this.usedBy,
    required this.createdAt,
    required this.createdBy,
  });

  factory AuthCode.fromJson(Map<String, dynamic> json, String docId) {
    return AuthCode(
      id: docId,
      code: json['code'] ?? '',
      role: json['role'] ?? 'Student',
      isUsed: json['isUsed'] ?? false,
      usedBy: json['usedBy'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'])
              : (json['createdAt'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
      createdBy: json['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'role': role,
      'isUsed': isUsed,
      'usedBy': usedBy,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }
}

class AuthCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final _random = Random();

  Stream<List<AuthCode>> getCodesStream() {
    return _firestore
        .collection('auth_codes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AuthCode.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<String> generateCode(String role, String createdBy) async {
    final code = _generateRandomCode();
    final authCode = AuthCode(
      id: '',
      code: code,
      role: role,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    final doc = await _firestore.collection('auth_codes').add(authCode.toJson());
    return doc.id;
  }

  Future<void> revokeCode(String codeId) async {
    await _firestore.collection('auth_codes').doc(codeId).delete();
  }

  Future<String?> verifyCode(String code) async {
    final snap = await _firestore
        .collection('auth_codes')
        .where('code', isEqualTo: code)
        .where('isUsed', isEqualTo: false)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['role'] as String?;
  }

  Future<void> markCodeUsed(String code, String userId) async {
    final snap = await _firestore
        .collection('auth_codes')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({
        'isUsed': true,
        'usedBy': userId,
      });
    }
  }

  String _generateRandomCode() {
    return List.generate(8, (_) => _chars[_random.nextInt(_chars.length)]).join();
  }
}
