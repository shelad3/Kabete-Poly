// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';

class Election {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'setup', 'active', 'closed', 'results_published'
  final bool resultsPublic;
  final DateTime? createdAt;

  const Election({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.resultsPublic = false,
    this.createdAt,
  });

  bool get isActiveNow {
    final now = DateTime.now();
    return status == 'active' &&
        now.isAfter(startDate) &&
        now.isBefore(endDate);
  }

  bool get isVotingClosed => DateTime.now().isAfter(endDate);

  factory Election.fromJson(Map<String, dynamic> json, String id) {
    return Election(
      id: id,
      title: json['title'] as String? ?? '',
      startDate: json['startDate'] != null
          ? (json['startDate'] as dynamic).toDate() as DateTime
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? (json['endDate'] as dynamic).toDate() as DateTime
          : DateTime.now(),
      status: json['status'] as String? ?? 'setup',
      resultsPublic: json['resultsPublic'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  factory Election.fromFirestore(DocumentSnapshot doc) {
    return Election.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'resultsPublic': resultsPublic,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get statusLabel {
    switch (status) {
      case 'setup':
        return 'Setup';
      case 'active':
        return 'Voting Active';
      case 'closed':
        return 'Voting Closed';
      case 'results_published':
        return 'Results Published';
      default:
        return status;
    }
  }
}

class Position {
  final String id;
  final String title;
  final int maxWinners;

  const Position({required this.id, required this.title, this.maxWinners = 1});

  factory Position.fromJson(Map<String, dynamic> json, String id) {
    return Position(
      id: id,
      title: json['title'] as String? ?? '',
      maxWinners: json['maxWinners'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'maxWinners': maxWinners};
}

class Candidate {
  final String id;
  final String studentId;
  final String name;
  final String photoUrl;
  final String manifesto;
  final int candidateNumber;
  final int voteCount;

  const Candidate({
    required this.id,
    required this.studentId,
    required this.name,
    this.photoUrl = '',
    this.manifesto = '',
    required this.candidateNumber,
    this.voteCount = 0,
  });

  factory Candidate.fromJson(Map<String, dynamic> json, String id) {
    return Candidate(
      id: id,
      studentId: json['studentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      manifesto: json['manifesto'] as String? ?? '',
      candidateNumber: json['candidateNumber'] as int? ?? 0,
      voteCount: json['voteCount'] as int? ?? 0,
    );
  }

  factory Candidate.fromFirestore(DocumentSnapshot doc) {
    return Candidate.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'name': name,
    'photoUrl': photoUrl,
    'manifesto': manifesto,
    'candidateNumber': candidateNumber,
    'voteCount': voteCount,
  };
}
