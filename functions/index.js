const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send a push notification to a specific user by their userId.
 * Restricted to admins/teachers to prevent any authenticated user from
 * spamming arbitrary users.
 */
exports.sendNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const { userId, title, body, data: payloadData } = data || {};
  if (!userId || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'userId, title, and body are required.');
  }

  // Only admins/officials/teachers may push to an arbitrary user.
  if (!(await isAdmin(context.auth.uid))) {
    throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions.');
  }

  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const tokens = userDoc.exists ? (userDoc.data().fcmTokens ?? []) : [];

  if (tokens.length === 0) return { success: true, sent: 0 };

  const message = {
    notification: { title, body },
    data: payloadData ?? {},
    tokens,
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  return { success: true, sent: response.successCount, failed: response.failureCount };
});

/**
 * Send a notification to an entire class (or a single student).
 * Triggered when a new notification doc is created in `notifications`.
 * The app writes `message`; this function normalizes to `body`.
 */
exports.sendClassNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const classId = data.classId;
    const title = data.title;
    // Tolerate either the legacy `message` field or the canonical `body`.
    const body = data.body ?? data.message;
    const type = data.type || 'general';
    const targetStudentId = data.studentId || '';

    if (!classId || !title || !body) return;

    let usersSnapshot;
    try {
      if (targetStudentId) {
        usersSnapshot = await admin.firestore()
          .collection('users')
          .where(admin.firestore.FieldPath.documentId(), '==', targetStudentId)
          .get();
      } else {
        usersSnapshot = await admin.firestore()
          .collection('users')
          .where('enrolledClasses', 'array-contains', classId)
          .get();
      }
    } catch (err) {
      functions.logger.error('Error querying users for notification', err);
      return;
    }

    const tokens = [];
    usersSnapshot.forEach((doc) => {
      const userTokens = doc.data().fcmTokens ?? [];
      if (Array.isArray(userTokens)) tokens.push(...userTokens);
    });

    if (tokens.length === 0) return;

    const message = {
      notification: { title, body },
      data: { type, classId, notificationId: snap.id },
      tokens,
    };

    try {
      await admin.messaging().sendEachForMulticast(message);
    } catch (err) {
      functions.logger.error('Failed to send class notification', err);
    }
  });

async function isAdmin(uid) {
  const doc = await admin.firestore().collection('users').doc(uid).get();
  if (!doc.exists) return false;
  const role = doc.data().role;
  return ['Admin', 'Official', 'Teacher'].includes(role);
}

// ---------------------------------------------------------------------------
// VOTING
//
// Voting is enforced SERVER-SIDE so that:
//  - the anonymity salt is never shipped in the client APK (real secrecy)
//  - one-vote-per-student-per-position is atomic (deterministic ballot doc id)
//  - the voting window is checked against server time (not device clock)
//
// The ballot document ID is `sha256(studentId:electionId:positionId:salt)`.
// This guarantees the SAME student revoting produces the SAME id -> the
// document already exists -> transaction.get() sees it -> rejected. No
// studentId is ever stored on the ballot, and the salt lives only here.
// ---------------------------------------------------------------------------
const crypto = require('crypto');
const { defineString } = require('firebase-functions/params');

// Replaces the deprecated functions.config().voting.salt path (Runtime Config
// shuts down March 2026). Value is injected from `functions/.env` (deploy) or
// process.env (emulator tests).
const votingSaltParam = defineString('VOTING_SALT', {
  default: 'dev-voting-salt-do-not-use-in-prod', // MUST set VOTING_SALT in production.
});

function votingSalt() {
  return votingSaltParam.value();
}

function ballotId(studentId, electionId, positionId) {
  const input = `${studentId}:${electionId}:${positionId}:${votingSalt()}`;
  return crypto.createHash('sha256').update(input).digest('hex');
}

/** Returns true if the student has already voted for a position (callable). */
exports.hasVoted = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }
  const { electionId, positionId } = data || {};
  if (!electionId || !positionId) {
    throw new functions.https.HttpsError('invalid-argument', 'electionId and positionId are required.');
  }
  const studentId = context.auth.uid;
  const ballotRef = admin.firestore()
    .collection('elections').doc(electionId)
    .collection('ballots').doc(ballotId(studentId, electionId, positionId));
  const snap = await ballotRef.get();
  return { hasVoted: snap.exists };
});

/** Casts a vote server-side and atomically (callable). */
exports.castVote = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }
  const { electionId, positionId, candidateId } = data || {};
  if (!electionId || !positionId || !candidateId) {
    throw new functions.https.HttpsError('invalid-argument', 'electionId, positionId and candidateId are required.');
  }

  const studentId = context.auth.uid;
  const electionRef = admin.firestore().collection('elections').doc(electionId);

  const result = await admin.firestore().runTransaction(async (tx) => {
    // Election active + window (server time).
    const electionSnap = await tx.get(electionRef);
    if (!electionSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Election not found.');
    }
    const election = electionSnap.data();
    const now = Date.now();
    const start = election.startDate ? election.startDate.toMillis() : 0;
    const end = election.endDate ? election.endDate.toMillis() : Infinity;
    const active = election.status === 'active' &&
      now >= start && now <= end &&
      election.resultsPublic !== true;
    if (!active) {
      throw new functions.https.HttpsError('failed-precondition', 'This election is not currently active.');
    }

    // Ballot is stored with positionId + candidateId but NO studentId.
    const ballotRef = electionRef.collection('ballots')
      .doc(ballotId(studentId, electionId, positionId));
    const ballotSnap = await tx.get(ballotRef);
    if (ballotSnap.exists) {
      throw new functions.https.HttpsError('already-exists', 'You have already voted for this position.');
    }

    const candidateRef = electionRef
      .collection('positions').doc(positionId)
      .collection('candidates').doc(candidateId);
    const candidateSnap = await tx.get(candidateRef);
    if (!candidateSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Candidate not found.');
    }

    tx.set(ballotRef, {
      positionId,
      candidateId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(candidateRef, {
      voteCount: admin.firestore.FieldValue.increment(1),
    });

    return { ok: true };
  });

  return result;
});

// ---------------------------------------------------------------------------
// PAYMENTS CONFIRMATION
// ---------------------------------------------------------------------------

/**
 * Confirms a payment (admin-only). Validates that the submitted transaction
 * reference and amount match the pending payment document, then atomically:
 *   - marks `payments/{paymentId}` -> completed (with transactionRef/completedAt)
 *   - marks the linked `cube_bookings/{bookingId}` -> paymentStatus 'paid'
 *
 * This is the SERVER-SIDE confirmation contract. Until a real Daraja STK-push
 * integration exists, this is called by the admin tool's "Mark Completed"
 * action instead of a blindly-trusted client write. A mismatched amount or an
 * already-finalized payment is rejected.
 */
exports.confirmPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }
  if (!(await isAdmin(context.auth.uid))) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can confirm payments.');
  }

  const { paymentId, transactionRef, amount } = data || {};
  if (!paymentId || !transactionRef || amount == null) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'paymentId, transactionRef and amount are required.'
    );
  }

  const submittedAmount = Number(amount);

  const paymentRef = admin.firestore()
    .collection('payments').doc(paymentId);

  await admin.firestore().runTransaction(async (tx) => {
    const paymentSnap = await tx.get(paymentRef);
    if (!paymentSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payment not found.');
    }
    const payment = paymentSnap.data();
    const currentStatus = payment.status;
    if (currentStatus === 'completed' || currentStatus === 'refunded') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Payment has already been finalized.'
      );
    }

    // Reject a mismatched submitted amount (prevents wrong-amount confirm).
    if (Math.abs(payment.amount - submittedAmount) > 0.01) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Amount ${submittedAmount} does not match payment amount ${payment.amount}.`
      );
    }

    // Firestore requires all transaction reads BEFORE any writes.
    // Flip the associated cube booking to paid (if linked).
    const bookingId = payment.bookingId;
    let bookingRef = null;
    if (bookingId) {
      bookingRef = admin.firestore().collection('cube_bookings').doc(bookingId);
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        bookingRef = null; // no booking doc -> nothing to flip
      }
    }

    tx.update(paymentRef, {
      status: 'completed',
      transactionRef,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (bookingRef) {
      tx.update(bookingRef, { paymentStatus: 'paid' });
    }
  });

  return { success: true };
});

