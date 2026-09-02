// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import '../models/election.dart';

class VotingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
  ///
  /// Delegates to the `hasVoted` Cloud Function so it works with the
  /// server-side ballot IDs (the client can no longer derive them, since the
  /// anonymity salt lives only in the server environment).
  Future<bool> hasVoted(
    String electionId,
    String positionId,
    String studentId,
  ) async {
    try {
      final result = await _functions
          .httpsCallable('hasVoted')
          .call({'electionId': electionId, 'positionId': positionId});
      return (result.data as Map<String, dynamic>?)?['hasVoted'] == true;
    } on FirebaseFunctionsException {
      return false;
    }
  }

  /// Casts a vote through the authoritative `castVote` Cloud Function.
  ///
  /// The ballot is created server-side under a deterministic SHA-256 doc id
  /// derived from `studentId:electionId:positionId:serverSalt`. The salt never
  /// leaves the server, so the ballot is anonymous (no `studentId` stored) yet
  /// one-vote-per-position is atomic. Returns a token to identify the vote.
  Future<String> castVote({
    required String electionId,
    required String positionId,
    required String candidateId,
    required String studentId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('castVote')
          .call({
            'electionId': electionId,
            'positionId': positionId,
            'candidateId': candidateId,
          });
      // Return a meaningful, non-identifiable confirmation token.
      final input = '$electionId:$positionId:${result.data}';
      return sha256.convert(utf8.encode(input)).toString();
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'already-exists':
          throw Exception('You have already voted for this position.');
        case 'failed-precondition':
          throw Exception('This election is not currently active.');
        case 'not-found':
          throw Exception(e.message ?? 'Election or candidate not found.');
        case 'unauthenticated':
          throw Exception('Please log in to vote.');
        default:
          throw Exception(e.message ?? 'Unable to cast vote. Please try again.');
      }
    }
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
