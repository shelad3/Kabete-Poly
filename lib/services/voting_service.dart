// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/election.dart';

class VotingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Gets all elections.
  Stream<List<Election>> getElectionsStream() {
    return _db
        .collection('elections')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(Election.fromFirestore).toList(),
        );
  }

  /// Gets a single election.
  Future<Election?> getElection(String electionId) async {
    final doc = await _db.collection('elections').doc(electionId).get();
    return doc.exists ? Election.fromFirestore(doc) : null;
  }

  /// Gets candidates for a position in an election.
  Stream<List<Candidate>> getCandidatesStream(
    String electionId,
    String positionId,
  ) {
    return _db
        .collection('elections')
        .doc(electionId)
        .collection('positions')
        .doc(positionId)
        .collection('candidates')
        .orderBy('candidateNumber')
        .snapshots()
        .map(
          (snap) => snap.docs.map(Candidate.fromFirestore).toList(),
        );
  }

  /// Gets positions for an election.
  Stream<List<Position>> getPositionsStream(String electionId) {
    return _db
        .collection('elections')
        .doc(electionId)
        .collection('positions')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Position.fromJson(d.data(), d.id)).toList(),
        );
  }

  /// Checks if a student has already voted for a position in an election.
  Future<bool> hasVoted(
    String electionId,
    String positionId,
    String studentId,
  ) async {
    final ballotHash = _generateBallotHash(electionId, positionId, studentId);
    final snap = await _db
        .collection('elections')
        .doc(electionId)
        .collection('ballots')
        .where('ballotHash', isEqualTo: ballotHash)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Casts a vote. In production, this should be done via a Cloud Function
  /// for security. This client-side implementation is for prototyping.
  ///
  /// The ballot is stored with a SHA-256 hash instead of the student ID,
  /// ensuring vote secrecy while maintaining auditability.
  Future<String> castVote({
    required String electionId,
    required String positionId,
    required String candidateId,
    required String studentId,
  }) async {
    // Check eligibility
    final election = await getElection(electionId);
    if (election == null || !election.isActiveNow) {
      throw Exception('This election is not currently active.');
    }

    // Check if already voted
    final alreadyVoted = await hasVoted(electionId, positionId, studentId);
    if (alreadyVoted) {
      throw Exception('You have already voted for this position.');
    }

    // Generate anonymous ballot hash
    final ballotHash = _generateBallotHash(electionId, positionId, studentId);

    // Cast vote atomically
    await _db.runTransaction((transaction) async {
      // Write anonymous ballot
      final ballotRef = _db
          .collection('elections')
          .doc(electionId)
          .collection('ballots')
          .doc();
      transaction.set(ballotRef, {
        'ballotHash': ballotHash,
        'positionId': positionId,
        'candidateId': candidateId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Increment candidate vote count
      final candidateRef = _db
          .collection('elections')
          .doc(electionId)
          .collection('positions')
          .doc(positionId)
          .collection('candidates')
          .doc(candidateId);
      transaction.update(candidateRef, {'voteCount': FieldValue.increment(1)});
    });

    return ballotHash;
  }

  /// Gets election results (only if results are public).
  Future<Map<String, List<Candidate>>> getResults(String electionId) async {
    final election = await getElection(electionId);
    if (election == null || !election.resultsPublic) {
      return {};
    }

    final positionsSnap = await _db
        .collection('elections')
        .doc(electionId)
        .collection('positions')
        .get();

    final results = <String, List<Candidate>>{};
    for (final posDoc in positionsSnap.docs) {
      final candidatesSnap = await _db
          .collection('elections')
          .doc(electionId)
          .collection('positions')
          .doc(posDoc.id)
          .collection('candidates')
          .orderBy('voteCount', descending: true)
          .get();
      results[posDoc.id] = candidatesSnap.docs
          .map(Candidate.fromFirestore)
          .toList();
    }
    return results;
  }

  /// Gets total voter turnout for an election.
  Future<int> getTurnout(String electionId) async {
    final snap = await _db
        .collection('elections')
        .doc(electionId)
        .collection('ballots')
        .get();
    return snap.docs.length;
  }

  /// Generates a SHA-256 hash of student+election+position+secret.
  String _generateBallotHash(
    String electionId,
    String positionId,
    String studentId,
  ) {
    // In production, the secret salt should be in Cloud Function env vars
    const secretSalt = 'kabete_poly_voting_salt_2026';
    final input = '$studentId:$electionId:$positionId:$secretSalt';
    return sha256.convert(utf8.encode(input)).toString();
  }

  // ---- Admin methods ----

  /// Admin: creates a new election.
  Future<String> createElection({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final ref = _db.collection('elections').doc();
    await ref.set({
      'title': title,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': 'setup',
      'resultsPublic': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Admin: adds a position to an election.
  Future<String> addPosition({
    required String electionId,
    required String title,
    int maxWinners = 1,
  }) async {
    final ref = _db
        .collection('elections')
        .doc(electionId)
        .collection('positions')
        .doc();
    await ref.set(
      Position(id: ref.id, title: title, maxWinners: maxWinners).toJson(),
    );
    return ref.id;
  }

  /// Admin: adds a candidate to a position.
  Future<void> addCandidate({
    required String electionId,
    required String positionId,
    required String studentId,
    required String name,
    String photoUrl = '',
    String manifesto = '',
    required int candidateNumber,
  }) async {
    await _db
        .collection('elections')
        .doc(electionId)
        .collection('positions')
        .doc(positionId)
        .collection('candidates')
        .doc()
        .set(
          Candidate(
            id: '',
            studentId: studentId,
            name: name,
            photoUrl: photoUrl,
            manifesto: manifesto,
            candidateNumber: candidateNumber,
          ).toJson(),
        );
  }

  /// Admin: activates an election.
  Future<void> activateElection(String electionId) async {
    await _db.collection('elections').doc(electionId).update({
      'status': 'active',
    });
  }

  /// Admin: closes an election.
  Future<void> closeElection(String electionId) async {
    await _db.collection('elections').doc(electionId).update({
      'status': 'closed',
    });
  }

  /// Admin: publishes results.
  Future<void> publishResults(String electionId) async {
    await _db.collection('elections').doc(electionId).update({
      'status': 'results_published',
      'resultsPublic': true,
    });
  }
}
