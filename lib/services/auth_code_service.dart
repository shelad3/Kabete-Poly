import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthCodeRule {
  final String label;
  final String id;
  final int? maxUses;
  final Duration? expiresAfter;

  const AuthCodeRule({
    required this.label,
    required this.id,
    this.maxUses,
    this.expiresAfter,
  });

  static const List<AuthCodeRule> predefined = [
    AuthCodeRule(
      label: 'Unlimited, No Expiry',
      id: 'unlimited',
      maxUses: null,
      expiresAfter: null,
    ),
    AuthCodeRule(
      label: '10 Uses, No Expiry',
      id: 'ten_uses',
      maxUses: 10,
      expiresAfter: null,
    ),
    AuthCodeRule(
      label: '5 Uses, 12 Hours',
      id: 'five_uses_12h',
      maxUses: 5,
      expiresAfter: Duration(hours: 12),
    ),
    AuthCodeRule(
      label: '10 Uses, 24 Hours',
      id: 'ten_uses_24h',
      maxUses: 10,
      expiresAfter: Duration(hours: 24),
    ),
    AuthCodeRule(
      label: 'Single Use (Immediate Expiry)',
      id: 'single_use',
      maxUses: 1,
      expiresAfter: Duration.zero,
    ),
  ];
}

class AuthCode {
  final String id;
  final String code;
  final String role;
  final bool isUsed;
  final String? usedBy;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? expiresAt;
  final int? maxUses;
  final int useCount;
  final String ruleId;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isExhausted => maxUses != null && useCount >= maxUses!;
  bool get isValid => !isUsed && !isExpired && !isExhausted;

  AuthCode({
    required this.id,
    required this.code,
    required this.role,
    this.isUsed = false,
    this.usedBy,
    required this.createdAt,
    required this.createdBy,
    this.expiresAt,
    this.maxUses,
    this.useCount = 0,
    this.ruleId = 'unlimited',
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
      expiresAt: json['expiresAt'] != null
          ? (json['expiresAt'] is String
              ? DateTime.parse(json['expiresAt'])
              : (json['expiresAt'] as dynamic).toDate() as DateTime)
          : null,
      maxUses: json['maxUses'],
      useCount: json['useCount'] ?? 0,
      ruleId: json['ruleId'] ?? 'unlimited',
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
      'expiresAt': expiresAt?.toIso8601String(),
      'maxUses': maxUses,
      'useCount': useCount,
      'ruleId': ruleId,
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

  Future<String> generateCode(String role, String createdBy, {AuthCodeRule? rule}) async {
    final r = rule ?? AuthCodeRule.predefined[0];
    final code = _generateRandomCode();
    final now = DateTime.now();
    final authCode = AuthCode(
      id: '',
      code: code,
      role: role,
      createdAt: now,
      createdBy: createdBy,
      expiresAt: r.expiresAfter != null ? now.add(r.expiresAfter!) : null,
      maxUses: r.maxUses,
      useCount: 0,
      ruleId: r.id,
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
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final data = snap.docs.first.data();
    final authCode = AuthCode.fromJson(data, snap.docs.first.id);

    if (!authCode.isValid) return null;

    return data['role'] as String?;
  }

  Future<void> markCodeUsed(String code, String userId) async {
    final snap = await _firestore
        .collection('auth_codes')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data();
      final currentCount = (data['useCount'] as num?)?.toInt() ?? 0;
      final maxUses = data['maxUses'] as int?;
      final newCount = currentCount + 1;
      final isNowExhausted = maxUses != null && newCount >= maxUses;
      await snap.docs.first.reference.update({
        'isUsed': isNowExhausted,
        'usedBy': userId,
        'useCount': newCount,
      });
    }
  }

  String _generateRandomCode() {
    return List.generate(8, (_) => _chars[_random.nextInt(_chars.length)]).join();
  }
}
